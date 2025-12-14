 # Chat 頁面重構：直接生成 WordCard

## ✅ 完成的改進

### 1. **WordCard 支援 Typed Generation**
將 `WordCard` 標記為 `@Generable`，讓 FoundationModels 可以直接生成結構化物件：

```swift
@Generable
struct WordCard: Codable {
    let word: String?
    let ipa: String?
    let part_of_speech: String?
    let meaning_en: String?
    let meaning_zh: String?
    let examples: [String]?
    let word_family: [String]?
    let collocations: [String]?
    let nuance: String?
    let extra_content: String?
}
```

### 2. **簡化 SystemPrompt**
移除 `<Thought>` 標籤和 JSON 格式說明，直接要求模型生成結構化的 WordCard：

**之前：**
- 要求模型在 `<Thought>` 標籤內思考
- 要求輸出 JSON 在 markdown code block 內
- 需要手動 parsing JSON

**現在：**
- 直接描述 WordCard 的每個欄位用途
- 模型自動生成結構化物件
- 不需要 JSON parsing

### 3. **重構 `give_reply` 函數**

#### Local Model（使用 Typed Generation）
```swift
// 直接生成 WordCard
var card = try await session.respond(to: prompt, generating: WordCard.self).content

// 簡化的 Self-Evaluation：只評估 card 的完整性
let evaluation = try await requestSelfEvaluation(prompt: evalPrompt, session: session)
if evaluation.score >= 85 {
    break
} else {
    // 重新生成
    card = try await session.respond(to: fixPrompt, generating: WordCard.self).content
}
```

#### External Model（Gemini）
```swift
// 使用文字生成 + JSON parsing（保持向後兼容）
let responseContent = try await generateResponse(prompt: prompt, session: session)
if let card = extractJSON(from: cleanedContent) {
    return ("", card)
}
```

### 4. **移除不必要的程式碼**
- ❌ 移除 `<Thought>` 標籤處理邏輯（Chat 頁面不再需要）
- ❌ 移除複雜的 JSON extraction 循環（local model）
- ✅ 保留 `removeThoughtBlocks` 和 `extractJSON`（Exam/Grading 仍需要）

## 📊 效能與品質提升

### 之前的流程：
1. 模型生成文字（包含 `<Thought>` 和 JSON）
2. Regex 移除 `<Thought>` 標籤
3. Regex 提取 JSON 字串
4. 手動 decode JSON → WordCard
5. Self-evaluation 評估整段文字品質
6. 如果不好，重新生成整段文字

### 現在的流程：
1. 模型直接生成 WordCard 結構
2. Self-evaluation 只評估 WordCard 欄位完整性
3. 如果不好，直接重新生成 WordCard

### 優勢：
- ✅ **更快**：減少文字處理開銷
- ✅ **更準確**：不會因為 JSON 格式錯誤而失敗
- ✅ **更專注**：Self-evaluation 只針對 card 內容評分
- ✅ **更簡潔**：程式碼減少 ~40 行

## 🔧 使用範例

### 使用者輸入
```
"tangle 是什麼意思？"
```

### Local Model 處理流程
1. DictionaryTool 自動查詢 `tangle` 的字典資料
2. 模型基於字典資料生成 WordCard：
   ```swift
   WordCard(
       word: "tangle",
       ipa: "/ˈtæŋ.ɡəl/",
       part_of_speech: "noun, verb",
       meaning_en: "A twisted mass; to become mixed together",
       meaning_zh: "糾纏；纏結",
       examples: [
           "Her hair was tangled from a day in the wind.",
           "I tried to sort through this tangle and got nowhere."
       ],
       word_family: ["tangled", "tangling", "untangle"],
       collocations: ["tangle with someone", "in a tangle"],
       nuance: "Can have negative connotation when describing confusion"
   )
   ```
3. Self-evaluation 檢查欄位完整性：
   - ✅ word, ipa, part_of_speech 都有填
   - ✅ meaning_en, meaning_zh 都有填
   - ✅ examples 有 2 個
   - ✅ Score: 95/100

### Gemini 處理流程
1. 生成文字回應（JSON 格式）
2. `extractJSON` 解析成 WordCard
3. 回傳給 UI

## 🎯 後續可優化項目

### 1. ExamData 和 AnswerEvaluation 也改用 Typed Generation
目前只有 Chat 用 typed generation，Exam 和 Grading 還在用文字 + parsing。

### 2. 統一 Local 和 Gemini 的處理方式
考慮讓 Gemini 也支援結構化輸出（如果 API 支援的話）。

### 3. 快取 Dictionary 查詢結果
避免對同一個字重複呼叫 API。

## 📝 測試建議

在 Xcode 中測試以下情境：

1. **單字查詢**：`"abundant"`
   - 檢查所有欄位是否完整
   - 檢查 IPA 是否正確
   - 檢查例句是否自然

2. **一般問題**：`"What is the difference between 'affect' and 'effect'?"`
   - 檢查是否使用 `extra_content` 欄位
   - 檢查其他欄位是否為 nil

3. **Self-correction 觸發**：故意問一個模型可能不熟悉的生僻字
   - 觀察 console log 的 self-eval 分數
   - 確認重試機制是否正常

4. **Tool calling**：確認 DictionaryTool 有被呼叫
   - 在 console 看到 `🔧 DictionaryTool called for: xxx`
   - 在 console 看到 `📖 Dictionary data fetched: ...`

---

**整合完成！** 🎉

現在 Chat 頁面使用最新的 FoundationModels typed generation API，模型直接生成結構化的 `WordCard`，不再需要複雜的 JSON parsing 和 `<Thought>` 標籤處理。
