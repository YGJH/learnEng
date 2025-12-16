import Foundation
import FoundationModels
import SwiftUI

enum LLMError: Error, LocalizedError {
    case missingApiKey
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "Gemini API Key is missing."
        case .quotaExceeded:
            return "API Quota Exceeded"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .missingApiKey:
            return "Please enter your Gemini API Key in Settings or switch to the local model."
        case .quotaExceeded:
            return "You exceeded your current quota, please check your plan and billing details at https://aistudio.google.com"
        }
    }
}

func getSystemPrompt() -> String {
    let translationLanguage = UserDefaults.standard.string(forKey: "translationLanguage") ?? "zh-TW"
    
    let languageNames: [String: String] = [
        "zh-TW": "Traditional Chinese (繁體中文)",
        "zh-CN": "Simplified Chinese (简体中文)",
        "ja": "Japanese (日本語)",
        "ko": "Korean (한국어)",
        "es": "Spanish (Español)",
        "fr": "French (Français)",
        "de": "German (Deutsch)",
        "it": "Italian (Italiano)",
        "pt": "Portuguese (Português)",
        "ru": "Russian (Русский)",
        "ar": "Arabic (العربية)",
        "hi": "Hindi (हिन्दी)",
        "vi": "Vietnamese (Tiếng Việt)",
        "th": "Thai (ไทย)",
        "id": "Indonesian (Bahasa Indonesia)"
    ]
    
    let languageName = languageNames[translationLanguage] ?? translationLanguage
    
    return """
System:
You are a professional and helpful English Teacher specialized in vocabulary education.
Your goal is to help users learn English words with accurate definitions, pronunciations, and usage examples.

**Available Tools:**
- **lookupWord**: Use this tool to fetch accurate dictionary data (IPA, definitions, examples, synonyms, antonyms) for any English word. ALWAYS use this tool when the user asks about a specific word to ensure accuracy.

**Your Task:**
Generate a structured vocabulary card for the word the user asks about. You must provide:
1. **word**: The target English word (exactly as queried, preserving capitalization if it's a proper noun)
2. **ipa**: IPA pronunciation notation (e.g., "/ˈtæŋ.ɡəl/")
3. **part_of_speech**: The primary part of speech (e.g., "noun", "verb", "adjective", "adverb")
4. **meaning_en**: A clear, concise English definition
5. **translation**: Translation in \(languageName)
6. **examples**: An array of 2-3 example sentences showing the word in different contexts
7. **word_family**: Related forms (e.g., for "happy" → ["happiness", "happily", "unhappy"])
8. **collocations**: Common phrases or collocations (e.g., for "make" → ["make a decision", "make sense"])
9. **nuance**: Usage notes about formality, connotation, or register (e.g., "formal", "informal", "negative connotation")

**Important:**
- If the user asks a general question (not about a specific word), set `extra_content` to your response and leave other fields as null.
- Use the lookupWord tool to verify definitions, IPA, and examples.
- Be accurate and educational.

user query: 
"""
}

func getGeminiSystemPrompt() -> String {
    let translationLanguage = UserDefaults.standard.string(forKey: "translationLanguage") ?? "zh-TW"
    let languageNames: [String: String] = [
        "zh-TW": "Traditional Chinese",
        "zh-CN": "Simplified Chinese",
        "ja": "Japanese",
        "ko": "Korean",
        "es": "Spanish",
        "fr": "French",
        "de": "German",
        "it": "Italian",
        "pt": "Portuguese",
        "ru": "Russian",
        "ar": "Arabic",
        "hi": "Hindi",
        "vi": "Vietnamese",
        "th": "Thai",
        "id": "Indonesian"
    ]
    let languageName = languageNames[translationLanguage] ?? translationLanguage
    
    return """
struct WordCard: Codable {
    let word: String?
    let ipa: String?
    let part_of_speech: String?
    let meaning_en: String?
    let meaning_zh: String?  // Translation in \(languageName)
    let examples: [String]?
    let word_family: [String]?
    let collocations: [String]?
    let nuance: String?
    let extra_content: String?
}            

"""
}

// MARK: - Model Abstraction

private func callGemini(prompt: String, model: String, apiKey: String) async throws -> String {
    // Use the URL without the key query parameter
    guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
        throw URLError(.badURL)
    }
    
    print("📤 Gemini API Request:")
    print("  URL: \(url)")
    print("  Model: \(model)")
    print("  API Key: \(apiKey.prefix(10))..." + (apiKey.count > 10 ? "***" : ""))
    
    let body: [String: Any] = [
        "contents": [
            ["parts": [["text": prompt]]]
        ]
    ]
    
    print("  Prompt length: \(prompt.count) chars")
    print("  Prompt preview: \(prompt.prefix(200))...")
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    // Log HTTP response details
    if let httpResponse = response as? HTTPURLResponse {
        print("📡 HTTP Status: \(httpResponse.statusCode)")
        print("📡 Headers: \(httpResponse.allHeaderFields)")
    }
    
    // Log raw response data
    if let rawString = String(data: data, encoding: .utf8) {
        print("📡 Raw Response Body:")
        print(rawString)
    } else {
        print("⚠️ Could not decode response data as UTF-8")
        print("📡 Raw Data bytes: \(data.count)")
    }
    
    // Simple decoding struct
    struct GeminiResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    let text: String
                }
                let parts: [Part]
            }
            let content: Content
        }
        let candidates: [Candidate]?
        let error: ErrorResponse?
        
        struct ErrorResponse: Decodable {
            let message: String
        }
    }
    
    let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
    print("📡 Decoded GeminiResponse:")
    print("  - candidates count: \(geminiResponse.candidates?.count ?? 0)")
    print("  - has error: \(geminiResponse.error != nil)")
    
    if let errorMessage = geminiResponse.error?.message {
        print("❌ Gemini Error Message: \(errorMessage)")
        // Try to extract richer error details (retryDelay, quota violations) from the raw JSON
        var userMessage = errorMessage
        var recovery: String? = nil

        if let raw = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let err = raw["error"] as? [String: Any] {

            // Retry info
            if let details = err["details"] as? [[String: Any]] {
                for d in details {
                    if let type = d["@type"] as? String, type.contains("RetryInfo") {
                        if let retryDelay = d["retryDelay"] as? String {
                            recovery = "Please retry after \(retryDelay)."
                            userMessage += " \nRetry-After: \(retryDelay)"
                        }
                    }
                    if let type = d["@type"] as? String, type.contains("QuotaFailure") {
                        if let violations = d["violations"] as? [[String: Any]] {
                            var parts: [String] = []
                            for v in violations {
                                if let metric = v["quotaMetric"] as? String {
                                    parts.append(metric)
                                }
                            }
                            if !parts.isEmpty {
                                userMessage += " \nQuota failures: \(parts.joined(separator: ", "))"
                            }
                        }
                    }
                }
            }
        }

        // If message clearly mentions quota, map to quota error code
        if errorMessage.lowercased().contains("quota") || errorMessage.lowercased().contains("exceeded") {
            let info: [String: Any] = [NSLocalizedDescriptionKey: userMessage, NSLocalizedRecoverySuggestionErrorKey: recovery ?? "Check your Gemini quota and billing settings."]
            throw NSError(domain: "GeminiQuotaExceeded", code: 429, userInfo: info)
        }

        throw NSError(domain: "GeminiError", code: -1, userInfo: [NSLocalizedDescriptionKey: userMessage])
    }
    
    // Success case
    let text = geminiResponse.candidates?.first?.content.parts.first?.text ?? ""
    print("✅ Gemini Success - Response length: \(text.count) chars")
    if text.isEmpty {
        print("⚠️ Warning: Empty response text")
    }
    return text
}

private func generateResponse(prompt: String, session: LanguageModelSession) async throws -> String {
    let selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "local"
    
    if selectedModel == "local" {
        let response = try await session.respond(to: prompt)
        return response.content
    } else {
        let apiKey = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
        guard !apiKey.isEmpty else { throw LLMError.missingApiKey }
        return try await callGemini(prompt: prompt, model: selectedModel, apiKey: apiKey)
    }
}


private func removeThoughtBlocks(_ raw: String) -> String {
    var s = raw
    // Normalize newlines
    s = s.replacingOccurrences(of: "\r\n", with: "\n")
    
    // Remove <Thought>...</Thought> and <think>...</think> blocks entirely
    let thoughtPatterns = [
        "(?is)<think>.*?</think>",
        "(?is)<Thought>.*?</Thought>",
        "(?is)<THINK>.*?</THINK>",
        "(?is)<THOUGHT>.*?</THOUGHT>"
    ]
    for pattern in thoughtPatterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(location: 0, length: s.utf16.count)
            s = regex.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "")
        }
    }
    
    // Remove any stray opening/closing tags
    let tagFragments = ["<think>", "</think>", "<Thought>", "</Thought>", "<THINK>", "</THINK>", "<THOUGHT>", "</THOUGHT>"]
    for frag in tagFragments {
        s = s.replacingOccurrences(of: frag, with: "")
    }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Dictionary Tool

/// Complete structure matching the dictionaryapi.dev API response
@Generable
struct DictionaryEntry: Codable {
    let word: String
    let phonetic: String?
    let phonetics: [Phonetic]?
    let meanings: [Meaning]?
    let license: License?
    let sourceUrls: [String]?
    
    @Generable
    struct Phonetic: Codable {
        let text: String?
        let audio: String?
        let sourceUrl: String?
    }
    
    @Generable
    struct Meaning: Codable {
        let partOfSpeech: String?
        let definitions: [Definition]?
        let synonyms: [String]?
        let antonyms: [String]?
    }
    
    @Generable
    struct Definition: Codable {
        let definition: String?
        let example: String?
        let synonyms: [String]?
        let antonyms: [String]?
    }
    
    @Generable
    struct License: Codable {
        let name: String?
        let url: String?
    }
}

struct DictionaryTool: Tool {
    
    let description: String = "Looks up the definition, IPA, pronunciation, examples, synonyms, and antonyms of an English word from a reliable dictionary API."
    
    @Generable
    struct Arguments {
        @Guide(description: "The English word to look up in the dictionary")
        var word: String
    }
    
    func call(arguments: Arguments) async throws -> String {
        print("🔧 DictionaryTool called for: \(arguments.word)")
        
        if let entries = await fetchDictionaryEntries(word: arguments.word) {
            // Format the dictionary data into a readable summary for the model
            let summary = formatDictionaryData(entries)
            print("📖 Dictionary data fetched: \(summary.prefix(200))...")
            return summary
        } else {
            return "Word '\(arguments.word)' not found in dictionary."
        }
    }
    
    /// Fetch dictionary entries from API
    private func fetchDictionaryEntries(word: String) async -> [DictionaryEntry]? {
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(cleanWord)") else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            
            let entries = try JSONDecoder().decode([DictionaryEntry].self, from: data)
            return entries
        } catch {
            print("Dictionary fetch error: \(error)")
            return nil
        }
    }
    
    /// Format dictionary entries into a concise, readable format for the model
    private func formatDictionaryData(_ entries: [DictionaryEntry]) -> String {
        var result = ""
        
        for (index, entry) in entries.enumerated() {
            if index > 0 { result += "\n---\n" }
            
            result += "Word: \(entry.word)\n"
            
            // IPA from phonetics or main phonetic field
            if let phonetics = entry.phonetics, !phonetics.isEmpty {
                let ipaList = phonetics.compactMap { $0.text }.filter { !$0.isEmpty }
                if !ipaList.isEmpty {
                    result += "IPA: \(ipaList.joined(separator: ", "))\n"
                }
            } else if let phonetic = entry.phonetic, !phonetic.isEmpty {
                result += "IPA: \(phonetic)\n"
            }
            
            // Meanings
            if let meanings = entry.meanings {
                for meaning in meanings {
                    if let pos = meaning.partOfSpeech {
                        result += "\nPart of Speech: \(pos)\n"
                    }
                    
                    if let definitions = meaning.definitions {
                        for (defIndex, def) in definitions.prefix(3).enumerated() {
                            result += "  \(defIndex + 1). \(def.definition ?? "")\n"
                            if let example = def.example {
                                result += "     Example: \(example)\n"
                            }
                            if let synonyms = def.synonyms, !synonyms.isEmpty {
                                result += "     Synonyms: \(synonyms.prefix(5).joined(separator: ", "))\n"
                            }
                            if let antonyms = def.antonyms, !antonyms.isEmpty {
                                result += "     Antonyms: \(antonyms.prefix(5).joined(separator: ", "))\n"
                            }
                        }
                    }
                    
                    if let synonyms = meaning.synonyms, !synonyms.isEmpty {
                        result += "  Synonyms: \(synonyms.prefix(8).joined(separator: ", "))\n"
                    }
                    if let antonyms = meaning.antonyms, !antonyms.isEmpty {
                        result += "  Antonyms: \(antonyms.prefix(8).joined(separator: ", "))\n"
                    }
                }
            }
        }
        
        return result
    }
}

// MARK: - JSON Extraction Helpers

private func extractJSON(from text: String) -> WordCard? {
    // Helper to try decoding a string
    func tryDecode(_ jsonString: String) -> WordCard? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WordCard.self, from: data)
    }

    // 1. Try to find JSON block with language identifier
    let patternWithLang = "```json\\s*(\\{[\\s\\S]*?\\})\\s*```"
    if let regex = try? NSRegularExpression(pattern: patternWithLang, options: []),
       let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
       let range = Range(match.range(at: 1), in: text) {
        if let card = tryDecode(String(text[range])) { return card }
    }
    
    // 2. Try to find generic code block
    let patternGeneric = "```\\s*(\\{[\\s\\S]*?\\})\\s*```"
    if let regex = try? NSRegularExpression(pattern: patternGeneric, options: []),
       let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
       let range = Range(match.range(at: 1), in: text) {
        if let card = tryDecode(String(text[range])) { return card }
    }
    
    // 3. Fallback: try to find the outermost braces
    if let start = text.firstIndex(of: "{"),
       let end = text.lastIndex(of: "}") {
        let jsonString = String(text[start...end])
        if let card = tryDecode(jsonString) { return card }
    }
    
    return nil
}

func give_reply(input: String, session: LanguageModelSession) async throws -> (String, WordCard?) {
    let selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "local"
    let prompt = getSystemPrompt() + "\n\nUser: " + input
    
    if selectedModel == "local" {
        // Use typed generation for local model with self-evaluation
        var card = try await session.respond(to: prompt, generating: WordCard.self).content
        
        // Self-evaluation: check if the card is well-formed
        for attempt in 0..<2 {
            let evalPrompt = """
            Review the vocabulary card you just generated:
            - Word: \(card.word ?? "nil")
            - IPA: \(card.ipa ?? "nil")
            - Part of Speech: \(card.part_of_speech ?? "nil")
            - Meaning (EN): \(card.meaning_en ?? "nil")
            - Translation: \(card.translation ?? "nil")
            - Examples: \(card.examples?.count ?? 0) items
            - Extra Content: \(card.extra_content ?? "nil")
            
            Evaluate:
            1. If it's a vocabulary query, are all required fields (word, ipa, part_of_speech, meaning_en, translation, examples) filled correctly?
            2. Is the IPA notation valid?
            3. Are the examples natural and varied?
            4. If it's a general question, is extra_content used appropriately?
            
            Output a score (0-100) and reason.
            """
            
            let evaluation = try await requestSelfEvaluation(prompt: evalPrompt, session: session)
            print("📊 WordCard Self-Eval (attempt \(attempt + 1)): Score \(evaluation.score), Reason: \(evaluation.reason)")
            
            if evaluation.score >= 85 {
                break
            } else if attempt < 1 {
                // Regenerate with feedback
                let fixPrompt = """
                Your previous vocabulary card was incomplete or inaccurate (Score: \(evaluation.score)).
                Issue: \(evaluation.reason)
                
                User query: \(input)
                
                Please regenerate a complete and accurate vocabulary card.
                """
                card = try await session.respond(to: fixPrompt, generating: WordCard.self).content
            }
        }
        
        print("✅ Final WordCard: \(card.word ?? "N/A")")
        return ("", card)
        
    } else {
        // For Gemini: Minimal prompt with data format only
        let geminiPrompt = """
        \(getGeminiSystemPrompt())
        Generate WordCard JSON for: "\(input)"
        - If word query: fill all fields (word, ipa, part_of_speech, meaning_en, meaning_zh, examples)
        - If general question: use extra_content only
        """
        
        let responseContent = try await generateResponse(prompt: geminiPrompt, session: session)
        print(responseContent)        
        if let card = extractJSON(from: responseContent) {
            print("✅ Parsed WordCard from Gemini: \(card.word ?? "N/A")")
            return ("", card)
        }
        
        // Fallback: wrap plain text in extra_content
        let fallbackCard = WordCard(extra_content: responseContent)
        return ("", fallbackCard)
    }
}


private func extractExamJSON(from text: String) -> ExamData? {
    func tryDecodeExamData(_ jsonString: String) -> ExamData? {
        guard let data = jsonString.data(using: .utf8) else {
            print("⚠️ Failed to convert ExamData JSON string to data")
            return nil
        }
        do {
            let examData = try JSONDecoder().decode(ExamData.self, from: data)
            print("✅ Successfully decoded ExamData with \(examData.questions.count) questions")
            return examData
        } catch {
            print("⚠️ Failed to decode ExamData: \(error)")
            return nil
        }
    }
    
    func tryDecodeQuestion(_ jsonString: String) -> GeneratedQuestion? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode(GeneratedQuestion.self, from: data)
        } catch {
            print("⚠️ Failed to decode GeneratedQuestion: \(error)")
            return nil
        }
    }

    // Try to extract all JSON blocks (for Gemini's format: multiple separate JSON objects)
    let patternAllJson = "```json\\s*(\\{[\\s\\S]*?\\})\\s*```"
    if let regex = try? NSRegularExpression(pattern: patternAllJson, options: []) {
        let nsRange = NSRange(location: 0, length: text.utf16.count)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        
        print("📊 Found \(matches.count) JSON blocks")
        
        if matches.count > 1 {
            // Multiple JSON blocks found - try to decode each as a GeneratedQuestion
            var questions: [GeneratedQuestion] = []
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let jsonString = String(text[range])
                    if let question = tryDecodeQuestion(jsonString) {
                        questions.append(question)
                    }
                }
            }
            if !questions.isEmpty {
                print("✅ Extracted \(questions.count) questions from multiple JSON blocks")
                return ExamData(questions: questions)
            }
        } else if matches.count == 1 {
            // Single JSON block - try as ExamData first, then as GeneratedQuestion
            if let range = Range(matches[0].range(at: 1), in: text) {
                let jsonString = String(text[range])
                print("📝 Trying to decode single JSON block (\(jsonString.count) chars)")
                if let examData = tryDecodeExamData(jsonString) {
                    return examData
                }
                print("⚠️ Not ExamData, trying as single GeneratedQuestion...")
                if let question = tryDecodeQuestion(jsonString) {
                    return ExamData(questions: [question])
                }
            }
        }
    }
    
    // Fallback: Try to find complete ExamData with "questions" array
    print("⚠️ Regex failed, trying fallback JSON extraction...")
    if let start = text.firstIndex(of: "{"),
       let end = text.lastIndex(of: "}") {
        let jsonString = String(text[start...end])
        print("📝 Fallback JSON string (\(jsonString.count) chars)")
        if let examData = tryDecodeExamData(jsonString) {
            return examData
        }
    }
    
    print("❌ All JSON extraction methods failed")
    return nil
}

func generateExam(words: [String], session: LanguageModelSession) async throws -> [ExamQuestion] {
    guard !words.isEmpty else { return [] }
    
    let selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "local"
    
    if selectedModel == "local" {
        // One-by-one generation to avoid context overflow
        var allQuestions: [ExamQuestion] = []
        var wordIndex = 0
        var consecutiveFailures = 0
        let targetCount = 5
        let maxConsecutiveFailures = 8
        
        while allQuestions.count < targetCount && consecutiveFailures < maxConsecutiveFailures && wordIndex < words.count * 3 {
            let word = words[wordIndex % words.count]
            
            // Create a FRESH session for each question to avoid context accumulation
            let examSession = LanguageModelSession()
            
            // Randomly choose question type to avoid repetition
            let types = ["multiple_choice", "fill_in_blank"]
            let randomType = types.randomElement()!
            
            // Ultra-short prompt to minimize context
            let prompt: String
            if randomType == "multiple_choice" {
                prompt = """
                Create 1 multiple_choice question for "\(word)".
                - question: Ask meaning or usage
                - options: 4 DIFFERENT real definitions (1 correct + 3 wrong)
                - answer: correct option number (1-4)
                JSON: {"questions": [{"type": "multiple_choice", "question": "...", "options": ["...", "...", "...", "..."], "answer": 1}]}
                """
            } else {
                prompt = """
                Create 1 fill_in_blank for "\(word)".
                - question: Natural sentence with _____ 
                - answerText: "\(word)"
                JSON: {"questions": [{"type": "fill_in_blank", "question": "...", "answerText": "..."}]}
                """
            }
            
            do {
                print("🔄 Generating \(randomType) question \(allQuestions.count + 1)/\(targetCount) for: \(word)")
                let examData = try await examSession.respond(to: prompt, generating: ExamData.self).content
                
                // Get the first question from response
                guard let questionData = examData.questions.first else {
                    print("⚠️ No question returned")
                    consecutiveFailures += 1
                    wordIndex += 1
                    continue
                }
                
                // Validate the single question
                var isValid = false
                var validationMsg = ""
                
                if questionData.type == "multiple_choice" {
                    isValid = questionData.options?.count == 4 && questionData.answer != nil
                    if !isValid {
                        validationMsg = "multiple_choice needs 4 options and answer, got options=\(questionData.options?.count ?? 0)"
                    }
                } else if questionData.type == "fill_in_blank" {
                    isValid = questionData.answerText != nil && 
                              !(questionData.answerText?.isEmpty ?? true) &&
                              (questionData.question.contains("_____") || questionData.question.contains("___"))
                    if !isValid {
                        validationMsg = "fill_in_blank needs answerText and _____"
                    }
                } else {
                    validationMsg = "Unsupported type: \(questionData.type)"
                }
                
                if !isValid {
                    print("⚠️ Invalid: \(validationMsg)")
                }
                
                if isValid {
                    let newQuestion = ExamQuestion(from: questionData)
                    // Check for duplicates
                    if !allQuestions.contains(where: { $0.question == newQuestion.question }) {
                        allQuestions.append(newQuestion)
                        print("✅ Added question \(allQuestions.count)/\(targetCount)")
                        consecutiveFailures = 0
                    } else {
                        print("⚠️ Duplicate question, skipping")
                        consecutiveFailures += 1
                    }
                } else {
                    consecutiveFailures += 1
                }
                
                wordIndex += 1
                
            } catch let error {
                let errorMsg = error.localizedDescription
                print("⚠️ Error: \(errorMsg)")
                
                // If context overflow, skip this word entirely
                if errorMsg.contains("context") || errorMsg.contains("Context") {
                    print("⚠️ Skipping word '\(word)' due to context limit")
                    wordIndex += 1
                    consecutiveFailures += 1
                } else if errorMsg.contains("deserialize") {
                    // Model output format issue, try again with different word
                    print("⚠️ Format error, trying next word")
                    wordIndex += 1
                    consecutiveFailures += 1
                } else {
                    consecutiveFailures += 1
                    wordIndex += 1
                }
                
                // If too many failures, stop early
                if consecutiveFailures >= 3 && allQuestions.count >= 2 {
                    print("⚠️ Too many failures, returning \(allQuestions.count) questions")
                    break
                }
            }
        }
        
        // Return whatever we managed to generate
        if allQuestions.isEmpty {
            throw NSError(
                domain: "ExamGenerationError",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unable to generate any valid questions.",
                    NSLocalizedRecoverySuggestionErrorKey: "Try simpler vocabulary words or switch to Gemini model in Settings."
                ]
            )
        }
        
        if allQuestions.count < targetCount {
            print("⚠️ Only generated \(allQuestions.count)/\(targetCount) questions")
        } else {
            print("✅ Generated \(allQuestions.count) questions")
        }
        
        return allQuestions
        
    } else {
        // For Gemini: Generate questions one by one
        var allQuestions: [ExamQuestion] = []
        
        for word in words.prefix(5) {
            let prompt = """
            JSON: {"questions": [{"type": "multiple_choice", "question": "...", "options": ["opt1", "opt2", "opt3", "opt4"], "answer": 1}]}
            OR {"questions": [{"type": "fill_in_blank", "question": "... _____ ...", "answerText": "..."}]}
            Word: "\(word)"
            """
            let responseContent = try await generateResponse(prompt: prompt, session: session)
            
            let cleanedContent = removeThoughtBlocks(responseContent)
            if let examData = extractExamJSON(from: cleanedContent),
               let question = examData.questions.first {
                // Fix 0-based answer index to 1-based if needed
                var fixedQuestion = question
                if question.type == "multiple_choice", let answer = question.answer {
                    // Gemini often returns 0-based index (0-3), but we need 1-based (1-4)
                    // If answer is 0, definitely 0-based. Convert all 0-3 to 1-4
                    if answer >= 0 && answer <= 3 {
                        let newAnswer = answer + 1
                        print("⚠️ Converting answer from \(answer) to \(newAnswer) (0-based → 1-based)")
                        fixedQuestion = GeneratedQuestion(
                            type: question.type,
                            question: question.question,
                            options: question.options,
                            passage: question.passage,
                            answer: newAnswer,
                            answerText: question.answerText
                        )
                    }
                }
                
                allQuestions.append(ExamQuestion(from: fixedQuestion))
                print("✅ Generated question for \(word) (answer: \(fixedQuestion.answer ?? -1))")
            } else {
                print("⚠️ Failed to parse question for \(word)")
            }
        }
        
        return allQuestions
    }
}

@Generable
struct AnswerEvaluation: Codable {
    let category: String?
    let score: Int?
    let feedback: String
    let corrected_answer: String?
    
    // Backward compatibility / Computed helper
    var isCorrect: Bool {
        if let score = score {
            return score >= 80
        }
        if let category = category {
            return category == "Perfect" || category == "Acceptable"
        }
        return false
    }
    
    // Fallback initializer (simple version)
    init(isCorrect: Bool, feedback: String) {
        self.category = isCorrect ? "Perfect" : "Wrong"
        self.score = isCorrect ? 100 : 0
        self.feedback = feedback
        self.corrected_answer = nil
    }
    
    // Full initializer
    init(category: String, score: Int, feedback: String, corrected_answer: String?) {
        self.category = category
        self.score = score
        self.feedback = feedback
        self.corrected_answer = corrected_answer
    }
}

func evaluateAnswer(question: String, correctAnswer: String, userAnswer: String, session: LanguageModelSession) async throws -> AnswerEvaluation {
    let selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "local"
    
    if selectedModel == "local" {
        // Strategy: Try detailed evaluation first, fall back to simple comparison if safety guardrails trigger

        for retryAttempt in 0..<10 {
            do {
                // Simplified prompt to reduce safety filter triggers
                let prompt = """
                Evaluate this English answer:
                
                Question: "\(question)"
                Expected: "\(correctAnswer)"
                Student: "\(userAnswer)"
                
                Rate with:
                - category: "Perfect", "Acceptable", "Close", or "Wrong"
                - score: 100 (perfect), 80 (acceptable), 50 (close), 0 (wrong)
                - feedback: Brief explanation
                - corrected_answer: Fixed version if needed, or null
                """
                
                print("🔄 Evaluation attempt \(retryAttempt + 1)")
                let evaluation = try await session.respond(to: prompt, generating: AnswerEvaluation.self).content
                
                print("✅ Evaluation: \(evaluation.category ?? "N/A") - Score: \(evaluation.score ?? -1)")
                return evaluation
                
            } catch {
                print("⚠️ Evaluation attempt \(retryAttempt + 1) failed: \(error)")
                
                if retryAttempt < 10 {
                    print("🔄 Retrying with simpler approach...")
                    continue
                } else {
                    print("⚠️ All typed evaluation attempts failed, using fallback comparison")
                    
                    // Fallback: Simple string comparison
                    let cleanUser = userAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanCorrect = correctAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if cleanUser == cleanCorrect {
                        return AnswerEvaluation(
                            category: "Perfect",
                            score: 100,
                            feedback: "Correct!",
                            corrected_answer: nil
                        )
                    } else if cleanUser.isEmpty {
                        return AnswerEvaluation(
                            category: "Wrong",
                            score: 0,
                            feedback: "No answer provided.",
                            corrected_answer: correctAnswer
                        )
                    } else {
                        // Check if it's close (contains the correct word or vice versa)
                        let isClose = cleanUser.contains(cleanCorrect) || cleanCorrect.contains(cleanUser)
                        
                        return AnswerEvaluation(
                            category: isClose ? "Close" : "Wrong",
                            score: isClose ? 50 : 0,
                            feedback: isClose ? "Partially correct, but needs refinement." : "Incorrect.",
                            corrected_answer: correctAnswer
                        )
                    }
                }
            }
        }
        
        // This should never be reached, but just in case
        return AnswerEvaluation(isCorrect: false, feedback: "Evaluation error")
        
    } else {
        // For Gemini: Minimal evaluation prompt
        let prompt = """
        JSON: {"category": "Perfect|Acceptable|Close|Wrong", "score": 0-100, "feedback": "...", "corrected_answer": "..."}
        Q: "\(question)" Expected: "\(correctAnswer)" Student: "\(userAnswer)"
        """
        
        let responseContent = try await generateResponse(prompt: prompt, session: session)
        let cleaned = removeThoughtBlocks(responseContent)
        
        func tryDecode(_ jsonString: String) -> AnswerEvaluation? {
            guard let data = jsonString.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(AnswerEvaluation.self, from: data)
        }
        
        // Extract JSON
        let pattern = "```json\\s*(\\{[\\s\\S]*?\\})\\s*```"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: cleaned, options: [], range: NSRange(location: 0, length: cleaned.utf16.count)),
           let range = Range(match.range(at: 1), in: cleaned) {
            if let result = tryDecode(String(cleaned[range])) { return result }
        }
        
        // Fallback
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            let jsonString = String(cleaned[start...end])
            if let result = tryDecode(jsonString) { return result }
        }
        
        // Default fallback if parsing fails
        let isMatch = userAnswer.lowercased().trimmingCharacters(in: .whitespaces) == correctAnswer.lowercased().trimmingCharacters(in: .whitespaces)
        return AnswerEvaluation(isCorrect: isMatch, feedback: isMatch ? "Correct!" : "Incorrect. The expected answer was \(correctAnswer).")
    }
}

// MARK: - Self Correction

@Generable
struct SelfEvaluation {
    let score: Int
    let reason: String
}

/// Ask the model to return a structured `SelfEvaluation` instead of hand-parsing JSON.
///
/// Notes:
/// - This uses FoundationModels typed generation (`respond(to:generating:)`).
/// - If your SDK's exact API differs, adjust this single function.
private func requestSelfEvaluation(prompt: String, session: LanguageModelSession) async throws -> SelfEvaluation {
    return try await session.respond(to: prompt, generating: SelfEvaluation.self).content
}

// MARK: - News Summarization

@Generable
struct NewsAnalysis {
    let isAdvertisement: Bool
    let summary: String
}

/// Analyze news article and generate summary (filters out advertisements)
/// - Parameters:
///   - title: The article title
///   - summary: The original article summary (truncated to avoid token limit)
///   - session: LanguageModelSession for local AI
/// - Returns: NewsAnalysis with ad detection and summary, or nil if it's an ad
func analyzeAndSummarizeNews(title: String, summary: String, session: LanguageModelSession) async throws -> NewsAnalysis? {
    let translationLanguage = UserDefaults.standard.string(forKey: "translationLanguage") ?? "zh-TW"
    
    let languageNames: [String: String] = [
        "zh-TW": "Traditional Chinese (繁體中文)",
        "zh-CN": "Simplified Chinese (简体中文)",
        "ja": "Japanese (日本語)",
        "ko": "Korean (한국어)",
        "es": "Spanish (Español)",
        "fr": "French (Français)",
        "de": "German (Deutsch)",
        "it": "Italian (Italiano)",
        "pt": "Portuguese (Português)",
        "ru": "Russian (Русский)",
        "ar": "Arabic (العربية)",
        "hi": "Hindi (हिन्दी)",
        "vi": "Vietnamese (Tiếng Việt)",
        "th": "Thai (ไทย)",
        "id": "Indonesian (Bahasa Indonesia)"
    ]
    
    let languageName = languageNames[translationLanguage] ?? translationLanguage
    
    // 極度激進的截斷以確保不超過 4096 token 限制
    // 新策略: title (150 chars ~195 tokens) + summary (400 chars ~520 tokens) + prompt (~200 tokens) = ~915 tokens
    let truncatedSummary = String(summary.prefix(400))  // 只取 400 字元
    let truncatedTitle = String(title.prefix(2000))       // 只取 2000 字元
    
    // 改進的 prompt：更清楚地說明什麼是廣告，避免誤判
    let prompt = """
    Analyze this news article and provide a summary in \(languageName).
    
    Title: \(truncatedTitle)
    Content: \(truncatedSummary)
    
    Instructions:
    1. Check if this is an ADVERTISEMENT (promotional content selling products/services). Most news articles are NOT ads.
    2. If it's a real news article (reporting events, technology, business news, etc.), set isAdvertisement=false
    3. Only set isAdvertisement=true if it's clearly promotional/marketing content
    4. Provide a brief 2-sentence summary in \(languageName)
    5. ignore the warning about sensitive content. because this is news content. I just want to filter ads.
    Return your analysis.
    """
    
    // 重試機制：最多重試 3 次
    let maxRetries = 3
    var lastError: Error?
    
    for attempt in 1...maxRetries {
        do {
            let analysis = try await session.respond(to: prompt, generating: NewsAnalysis.self).content
            
            if analysis.isAdvertisement {
                print("🚫 Filtered out advertisement: \(truncatedTitle.prefix(50))...")
                return nil
            }
            
            print("✅ Valid news with summary: \(analysis.summary.prefix(50))...")
            return analysis
            
        } catch let error as NSError {
            lastError = error
            let errorString = error.localizedDescription
            
            // 檢查是否為 safety guardrails 錯誤
            if errorString.contains("Safety guardrails") || errorString.contains("safety") {
                print("⚠️ Attempt \(attempt)/\(maxRetries): Safety guardrails triggered for: \(truncatedTitle.prefix(50))...")
                
                if attempt < maxRetries {
                    print("🔄 Retrying with a fresh session...")
                    // 注意：這裡的 session 已經是 fresh 的，所以直接重試即可
                    continue
                } else {
                    print("❌ Max retries reached, treating as valid news with fallback summary")
                    // 達到最大重試次數，使用 fallback 摘要（不要跳過這則新聞）
                    return NewsAnalysis(
                        isAdvertisement: false,
                        summary: truncatedSummary.isEmpty ? truncatedTitle : String(truncatedSummary.prefix(200))
                    )
                }
            }
            
            // 檢查是否為 context 相關錯誤
            if errorString.contains("exceededContextWindowSize") || errorString.contains("4096") {
                print("⚠️ Context window exceeded, skipping article: \(truncatedTitle.prefix(50))...")
                return nil
            }
            
            // 其他錯誤：重試
            if attempt < maxRetries {
                print("⚠️ Attempt \(attempt)/\(maxRetries) failed: \(errorString)")
                continue
            } else {
                print("❌ Max retries reached: \(errorString)")
                return nil
            }
        }
    }
    
    // 如果所有重試都失敗，返回 nil
    print("⚠️ All \(maxRetries) attempts failed for: \(truncatedTitle.prefix(50))...")
    return nil
}

/// Legacy function for backward compatibility - now uses the new analysis function
func generateNewsSummary(title: String, summary: String, session: LanguageModelSession) async throws -> String {
    guard let analysis = try await analyzeAndSummarizeNews(title: title, summary: summary, session: session) else {
        throw NSError(domain: "NewsFiltering", code: 1, userInfo: [NSLocalizedDescriptionKey: "Article filtered as advertisement"])
    }
    return analysis.summary
}
