# Safety Guardrails 處理總結

## 🎯 改進目標

讓 App 在遇到 Apple AI 安全機制時：
1. **自動重試** - 不立即失敗
2. **智能降級** - 簡化 prompt 繼續嘗試
3. **保證可用** - 即使 AI 完全被阻擋，也能提供基本功能
4. **用戶無感** - 不顯示技術性錯誤訊息

---

## ✅ Exam Generation (generateExam)

### 策略：分批處理 + 自動跳過

```swift
// 原本：一次生成所有詞彙的題目
❌ generateExam(words: ["word1", "word2", "word3", "word4", "word5"])
   → 任一詞彙觸發 safety filter = 整個失敗

// 現在：分批處理，跳過問題詞彙
✅ Batch 1: ["word1", "word2", "word3"] → 3 題 ✓
   Batch 2: ["word4"] → 觸發 filter ✗ → 跳過
   Batch 3: ["word5"] → 2 題 ✓
   結果：成功生成 5 題
```

### 實現細節

- **每批最多 3 個詞** - 降低複雜度
- **自動跳過失敗** - 繼續處理剩餘詞彙
- **累積結果** - 收集所有成功生成的題目
- **只在完全失敗時報錯** - 連續 3 次重試且沒有任何題目

### 用戶體驗

```
👤 用戶：點擊 "Start Exam"
🤖 系統：
   [內部] 嘗試生成 word1-3... 成功 ✓
   [內部] 嘗試生成 word4... 失敗，跳過 ✗
   [內部] 嘗試生成 word5... 成功 ✓
👤 用戶：看到 5 題考試（完全不知道中間有問題）
```

---

## ✅ Answer Evaluation (evaluateAnswer)

### 策略：三層降級

```swift
Layer 1: 完整 AI 評分（詳細 rubric + 反饋）
   ↓ 觸發 safety filter
Layer 2: 簡化 AI 評分（基本 prompt）
   ↓ 仍然失敗
Layer 3: 字串比對（完全不依賴 AI）
   → 總是成功 ✓
```

### 實現細節

#### Level 1: 詳細評分
```swift
try await session.respond(to: """
Evaluate this English answer:
Question: "..."
Expected: "..."
Student: "..."

Rate with:
- category: "Perfect", "Acceptable", "Close", or "Wrong"
- score: 100/80/50/0
- feedback: Brief explanation
- corrected_answer: Fixed version or null
""", generating: AnswerEvaluation.self)
```

#### Level 2: 簡化評分（retry）
```swift
// 移除詳細說明，只保留核心
try await session.respond(to: """
Compare answers:
Correct: "\(correctAnswer)"
Student: "\(userAnswer)"
Judge: Perfect/Acceptable/Close/Wrong
""", generating: AnswerEvaluation.self)
```

#### Level 3: 本地比對（final fallback）
```swift
if userAnswer.lowercased() == correctAnswer.lowercased() {
    return AnswerEvaluation(category: "Perfect", score: 100, ...)
} else if userAnswer.contains(correctAnswer) {
    return AnswerEvaluation(category: "Close", score: 50, ...)
} else {
    return AnswerEvaluation(category: "Wrong", score: 0, ...)
}
```

### 用戶體驗

```
👤 用戶：提交答案 "experiment"
🤖 系統：
   [嘗試 1] 詳細 AI 評分... 觸發 safety filter ✗
   [嘗試 2] 簡化 AI 評分... 觸發 safety filter ✗
   [嘗試 3] 字串比對... "experiment" == "experiment" ✓
👤 用戶：看到 "Perfect! Score: 100" （不知道 AI 失敗了）
```

---

## 📊 對比：改進前 vs 改進後

### Exam Generation

| 情況 | 改進前 | 改進後 |
|------|--------|--------|
| 1 個詞觸發 filter | ❌ 整個失敗，顯示錯誤 | ✅ 跳過該詞，其他 4 個詞生成題目 |
| 2 個詞觸發 filter | ❌ 整個失敗 | ✅ 跳過這 2 個，其他 3 個生成題目 |
| 全部詞都觸發 | ❌ 顯示錯誤 | ❌ 顯示錯誤（但已盡力重試） |

### Answer Evaluation

| 情況 | 改進前 | 改進後 |
|------|--------|--------|
| 評分時觸發 filter | ❌ 評分失敗，顯示錯誤 | ✅ 自動降級到字串比對 |
| 答案敏感詞彙 | ❌ 可能完全無法評分 | ✅ 字串比對總是有結果 |
| AI 服務異常 | ❌ 功能不可用 | ✅ 降級到本地邏輯 |

---

## 🎓 關鍵改進點

### 1. **從 "失敗即停" 到 "盡力而為"**

**改進前：**
```swift
let result = try await generateExam(words: allWords)
// 任何錯誤 = 拋出異常 = 用戶看到錯誤訊息
```

**改進後：**
```swift
var results = []
for word in words {
    do {
        let result = try await generate(word)
        results.append(result)
    } catch {
        print("Skip problematic word, continue...")
        continue
    }
}
return results // 返回所有成功的結果
```

### 2. **從 "全有或全無" 到 "部分成功"**

- 5 個詞中 4 個成功 = 返回 4 題（而非 0 題）
- 10 次評分中 7 次 AI 成功 = 7 次精確評分 + 3 次基本判斷（而非全失敗）

### 3. **從 "依賴 AI" 到 "AI 優先，本地兜底"**

```
AI 生成（最佳） 
   ↓ 失敗
AI 簡化生成（次佳）
   ↓ 失敗
本地邏輯（保底）
   → 總是有結果
```

---

## 🧪 測試場景

### 場景 1: 正常詞彙
- 輸入：`["apple", "book", "computer", "dog", "elephant"]`
- 結果：✅ 生成 5 題，所有評分都精確

### 場景 2: 包含敏感詞
- 輸入：`["apple", "sensitive_word", "computer", "another_bad", "elephant"]`
- 過程：
  - apple → 成功
  - sensitive_word → 跳過
  - computer → 成功
  - another_bad → 跳過
  - elephant → 成功
- 結果：✅ 生成 3 題（不顯示錯誤）

### 場景 3: 全部敏感詞
- 輸入：`["bad1", "bad2", "bad3", "bad4", "bad5"]`
- 結果：❌ 顯示錯誤："No questions could be generated. Please try different vocabulary words."

### 場景 4: 評分時觸發
- 用戶答案："experiment"
- 過程：
  1. 嘗試詳細評分 → 失敗
  2. 嘗試簡化評分 → 失敗
  3. 字串比對 → 成功
- 結果：✅ 顯示 "Perfect! Score: 100"

---

## 💡 核心理念

> **"Make it work, even when AI fails"**

1. **Never show technical errors to users** - 內部處理所有 AI 限制
2. **Degrade gracefully** - 從最佳到可用，逐步降級
3. **Always provide value** - 即使部分功能受限，也要提供基本服務
4. **Transparent retry** - 自動重試，用戶無感

這種設計讓 App 更加 **健壯 (Robust)** 和 **用戶友善 (User-Friendly)**！
