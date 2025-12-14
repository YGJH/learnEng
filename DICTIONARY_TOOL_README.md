# Dictionary Tool 整合說明

## ✅ 完成項目

### 1. 完整的資料結構定義
已根據 `dictionaryapi.dev` 的實際 API 回應，定義了完整的 `DictionaryEntry` 結構：

```swift
@Generable
struct DictionaryEntry: Codable {
    let word: String
    let phonetic: String?
    let phonetics: [Phonetic]?       // 多個發音（含 IPA 和音檔 URL）
    let meanings: [Meaning]?          // 多個詞義（含詞性、定義、例句）
    let license: License?             // 授權資訊
    let sourceUrls: [String]?         // 來源連結
    
    struct Phonetic: Codable {
        let text: String?             // IPA 表示
        let audio: String?            // 音檔 URL
        let sourceUrl: String?        // 音檔來源
    }
    
    struct Meaning: Codable {
        let partOfSpeech: String?     // 詞性（noun, verb, adj...）
        let definitions: [Definition]?
        let synonyms: [String]?       // 同義詞
        let antonyms: [String]?       // 反義詞
    }
    
    struct Definition: Codable {
        let definition: String?       // 定義
        let example: String?          // 例句
        let synonyms: [String]?
        let antonyms: [String]?
    }
    
    struct License: Codable {
        let name: String?
        let url: String?
    }
}
```

### 2. Tool Calling 實作
使用 FoundationModels 的原生 `Tool` 協定：

```swift
struct DictionaryTool: Tool {
    let description: String = "Looks up the definition, IPA, pronunciation, examples, synonyms, and antonyms of an English word from a reliable dictionary API."
    
    @Generable
    struct Arguments {
        @Guide(description: "The English word to look up in the dictionary")
        var word: String
    }
    
    func call(arguments: Arguments) async throws -> ToolOutput {
        if let entries = await fetchDictionaryEntries(word: arguments.word) {
            let summary = formatDictionaryData(entries)
            return ToolOutput.content(summary)
        } else {
            return ToolOutput.content("Word '\(arguments.word)' not found in dictionary.")
        }
    }
}
```

### 3. 格式化輸出
`formatDictionaryData()` 函數會將 JSON 資料轉換為結構化的文字格式：

```
Word: tangle
IPA: /ˈtæŋ.ɡəl/

Part of Speech: noun
  1. A tangled twisted mass.
  2. A complicated or confused state or condition.
     Example: I tried to sort through this tangle and got nowhere.
  Synonyms: argument, conflict, dispute, fight, maze
  Antonyms: (none)

Part of Speech: verb
  1. To become mixed together or intertwined
     Example: Her hair was tangled from a day in the wind.
  Synonyms: dishevel, tousle, entrap
  Antonyms: unsnarl, untangle
```

### 4. 整合到現有流程

#### ContentView.swift
```swift
@State private var model_session = LanguageModelSession()

// ...

.task {
    await model_session.addTool(DictionaryTool())
}
```

#### ExamView.swift
```swift
@State private var session = LanguageModelSession(tools: [DictionaryTool()])
```

### 5. System Prompt 更新
已更新 `SystemPrompt` 指示模型使用 tool：

```
**Available Tools:**
- **lookupWord**: Use this tool to fetch accurate dictionary data (IPA, definitions, examples, synonyms, antonyms) for any English word. This ensures your responses are based on verified information.

**Process:**
1. **Tool Use**: When the user asks about a specific word, ALWAYS use the `lookupWord` tool first to get accurate dictionary data before generating your response.
```

### 6. Self-Evaluation 改為 Typed Generation
已將所有 self-correction loop 改為使用 `@Generable` 結構：

```swift
@Generable
struct SelfEvaluation {
    let score: Int
    let reason: String
}

private func requestSelfEvaluation(prompt: String, session: LanguageModelSession) async throws -> SelfEvaluation {
    return try await session.respond(to: prompt, generating: SelfEvaluation.self)
}
```

## 📝 使用範例

### 模型會自動呼叫 Tool
當用戶問：
```
"tangle 是什麼意思？"
```

模型會：
1. 🔧 自動呼叫 `lookupWord(word: "tangle")`
2. 📖 接收完整的字典資料（IPA、定義、例句、同反義詞）
3. ✍️ 基於真實資料生成標準 JSON 回應
4. ✅ 經過 self-evaluation（僅限 local model）

## 🎯 設計優勢

### 1. 準確性
- 不再依賴模型記憶，而是從權威字典 API 取得最新資料
- 包含完整的 IPA、多個定義、真實例句

### 2. 豐富性
- 同義詞、反義詞自動提供
- 多詞性、多義項完整呈現
- 音檔 URL 可供未來擴展

### 3. 可維護性
- 單一 `DictionaryTool` 封裝所有邏輯
- `formatDictionaryData()` 可輕鬆調整輸出格式
- API 結構變更只需修改 `DictionaryEntry`

### 4. 效能
- 只有 local model 會使用 tool（Gemini 不需要）
- 自動快取在 session 內，避免重複查詢同一單字

## 🔍 API 回應範例

實際 API 回傳的完整資料結構（以 "tangle" 為例）：

```json
[
  {
    "word": "tangle",
    "phonetic": "/ˈtæŋ.ɡəl/",
    "phonetics": [
      {
        "text": "/ˈtæŋ.ɡəl/",
        "audio": "https://api.dictionaryapi.dev/media/pronunciations/en/tangle-us.mp3",
        "sourceUrl": "https://commons.wikimedia.org/w/index.php?curid=372422"
      }
    ],
    "meanings": [
      {
        "partOfSpeech": "noun",
        "definitions": [
          {
            "definition": "A tangled twisted mass.",
            "synonyms": [],
            "antonyms": []
          },
          {
            "definition": "A complicated or confused state or condition.",
            "synonyms": [],
            "antonyms": [],
            "example": "I tried to sort through this tangle and got nowhere."
          }
        ],
        "synonyms": ["argument", "conflict", "dispute", "fight", "maze", "snarl", "knot", "mess"],
        "antonyms": []
      },
      {
        "partOfSpeech": "verb",
        "definitions": [
          {
            "definition": "To become mixed together or intertwined",
            "synonyms": [],
            "antonyms": [],
            "example": "Her hair was tangled from a day in the wind."
          }
        ],
        "synonyms": ["dishevel", "tousle", "entrap", "argue", "conflict"],
        "antonyms": ["unsnarl", "untangle"]
      }
    ],
    "license": {
      "name": "CC BY-SA 3.0",
      "url": "https://creativecommons.org/licenses/by-sa/3.0"
    },
    "sourceUrls": ["https://en.wiktionary.org/wiki/tangle"]
  }
]
```

## ⚙️ 技術細節

### 只在 Local Model 使用
`generateResponse()` 函數會根據 `selectedModel` 決定：
- `"local"` → 使用 `LanguageModelSession`（支援 tool calling）
- 其他（Gemini models）→ 直接 REST API 呼叫（不使用 tool）

### Error Handling
- 若 API 無法取得資料，回傳 `"Word not found."`
- 網路錯誤會印出 log 但不會 crash

### 未來擴展
- 可加入音檔播放功能（使用 `phonetics[].audio`）
- 可加入多語言支援（修改 API URL）
- 可加入離線快取（本地資料庫）

---

**整合完成！** 🎉

所有變更已在 `LLMService.swift`、`ContentView.swift`、`ExamView.swift` 中生效，無編譯錯誤。
