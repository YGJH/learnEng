# Apple AI Safety Guardrails 處理指南

## 🛡️ 什麼是 Safety Guardrails？

Apple 的 FoundationModels 框架內建安全機制，會在以下情況觸發：

1. **敏感內容檢測**
   - 考試/測驗內容（可能被視為作弊工具）
   - 某些特定詞彙組合
  ### 🎓 Answer Evaluation 的處理

評分功能也實現了類似的智能處理：

#### 三層降級策略

1. **第一次嘗試**：使用完整的評分 prompt
   ```swift
   try await session.respond(to: detailedPrompt, generating: AnswerEvaluation.self)
   ```

2. **第二次嘗試**（如果失敗）：使用簡化的 prompt
   ```swift
   // 移除詳細的 rubric 說明，只保留核心要求
   try await session.respond(to: simplifiedPrompt, generating: AnswerEvaluation.self)
   ```

3. **第三次嘗試**（仍失敗）：使用本地字串比對
   ```swift
   // 完全不依賴 LLM，用簡單邏輯判斷
   if userAnswer == correctAnswer { return "Perfect" }
   else if userAnswer.contains(correctAnswer) { return "Close" }
   else { return "Wrong" }
   ```

#### 優勢

- ✅ **總是有結果**：即使 LLM 完全無法評分，也能返回基本判斷
- ✅ **無錯誤提示**：用戶不會看到評分失敗的錯誤訊息
- ✅ **漸進降級**：從最精確到最簡單，確保功能可用

### 📊 測試建議

系統已經自動處理大部分 safety guardrails 問題，但如果仍遇到困難：

1. **檢查詞彙**
   - 避免敏感、爭議性詞彙
   - 使用常見、教育性詞彙

2. **查看 Console 日誌**
   - 確認具體錯誤訊息
   - 觀察自動重試過程

3. **最後手段：切換到 Gemini**
   - 在 Settings 設定 API Key
   - 選擇 Gemini 模型*複雜結構請求**
   - 深度嵌套的 JSON 結構
   - 過長的 prompt（>1000 tokens）
   - 多層次的條件邏輯

3. **模糊的生成要求**
   - 不明確的輸出格式
   - 矛盾的指令

## ⚠️ 常見錯誤訊息

```
Safety guardrails were triggered. If this is unexpected, please use
`LanguageModelSession.logFeedbackAttachment(sentiment:issues:desiredOutput:)`
to export the feedback attachment and file a feedback report.
```

## ✅ 解決方案

### 1. **簡化 System Prompt**

**❌ 太複雜（容易觸發）：**
```swift
let prompt = """
You are an expert English Teacher creating a vocabulary exam.
The user will provide a list of vocabulary words.
You must generate an exam based on these words to test understanding.

**Your Task:**
Generate an ExamData structure containing multiple exam questions...
[50+ lines of detailed instructions]
"""
```

**✅ 簡潔明瞭（不易觸發）：**
```swift
let prompt = """
You are an English Teacher creating vocabulary practice questions.

Generate questions for these word types:
1. multiple_choice: Test word meaning with 4 options
2. fill_in_blank: Test usage with a sentence containing _____
3. reading: Short passage with comprehension question and 4 options

Requirements:
- Use real English content (no placeholders)
- Make options distinct and educational
- Vary question difficulty
"""
```

### 2. **減少詞彙數量**

如果一次請求生成 5-10 個詞的測驗，可能會因為內容過多而觸發。

**建議：**
- 一次最多 3-5 個詞
- 避免使用過於敏感或爭議性的詞彙

### 3. **使用錯誤處理**

```swift
do {
    let examData = try await session.respond(to: prompt, generating: ExamData.self).content
    return examData.questions.map { ExamQuestion(from: $0) }
} catch {
    print("⚠️ Safety guardrails triggered: \(error)")
    
    // 提供 fallback 或引導用戶切換到 Gemini
    throw NSError(
        domain: "ExamGenerationError",
        code: -1,
        userInfo: [
            NSLocalizedDescriptionKey: "Content blocked by safety filters. Try Gemini model."
        ]
    )
}
```

### 4. **切換到 Gemini API**

Apple 本地模型限制較嚴格，Google Gemini 的限制較寬鬆：

**在 App 中實現：**
```swift
if selectedModel == "local" {
    // 可能觸發 safety guardrails
} else {
    // Gemini API - 較少限制
}
```

### 5. **使用反饋工具（進階）**

如果你認為內容合理但仍被攔截，可以使用 Apple 提供的反饋工具：

```swift
// 在 catch block 中
session.logFeedbackAttachment(
    sentiment: .negative,
    issues: ["Legitimate educational content blocked"],
    desiredOutput: "Vocabulary exam questions"
)
```

然後到 https://feedbackassistant.apple.com 提交報告。

## 🎯 本專案的實現

我們已經在 `LLMService.swift` 和 `ExamView.swift` 中實現了智能錯誤處理：

### 自動重試機制

當遇到 safety guardrails 時，系統會：

1. **簡化 Prompt** - 減少觸發機率
2. **分批生成** - 一次處理 3 個詞彙而非全部
3. **自動跳過** - 跳過觸發安全機制的詞彙，繼續生成其他題目
4. **智能補全** - 用剩餘詞彙補充題目直到達到 5 題
5. **友善提示** - 如果完全無法生成才顯示錯誤訊息

### 實現邏輯

```swift
// 策略：分批處理詞彙，遇到錯誤自動跳過繼續
var allQuestions: [ExamQuestion] = []
var remainingWords = words

while !remainingWords.isEmpty {
    let currentBatch = Array(remainingWords.prefix(3)) // 每次最多 3 個詞
    
    do {
        let examData = try await session.respond(...)
        allQuestions.append(contentsOf: examData.questions)
        remainingWords.removeFirst(batchSize)
    } catch {
        // 跳過問題詞彙，繼續處理下一批
        print("⚠️ Skipping problematic words, trying next batch...")
        remainingWords.removeFirst(1)
        continue
    }
}

// 返回成功生成的題目
return Array(allQuestions.prefix(5))
```

### 用戶體驗

- ✅ **無感處理**：大多數情況下，用戶不會察覺到 safety guardrails
- ✅ **自動恢復**：系統會自動跳過問題詞彙繼續生成
- ✅ **漸進降級**：只有在完全無法生成時才顯示錯誤
- ✅ **保留選擇**：用戶仍可選擇切換到 Gemini

## 📊 測試建議

如果遇到 safety guardrails：

1. **先嘗試不同詞彙**
   - 避免敏感、爭議性詞彙
   - 使用常見、教育性詞彙

2. **減少生成數量**
   - 從 5 題改為 3 題
   - 分批生成

3. **切換到 Gemini**
   - 在 Settings 設定 API Key
   - 選擇 Gemini 模型

4. **查看 Console 日誌**
   - 確認具體錯誤訊息
   - 根據提示調整

## 🔗 相關資源

- [Apple FoundationModels 文件](https://developer.apple.com/documentation/foundationmodels)
- [Feedback Assistant](https://feedbackassistant.apple.com)
- [Gemini API 文件](https://ai.google.dev/docs)
