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

let SystemPrompt = """
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
5. **meaning_zh**: Traditional Chinese translation (繁體中文翻譯)
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

// MARK: - Model Abstraction

private func callGemini(prompt: String, model: String, apiKey: String) async throws -> String {
    // Use the URL without the key query parameter
    guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
        throw URLError(.badURL)
    }
    
    let body: [String: Any] = [
        "contents": [
            ["parts": [["text": prompt]]]
        ]
    ]
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    // Add the API key to the header as per official documentation
    request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, _) = try await URLSession.shared.data(for: request)
    print("data: \(data)")
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
    
    let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
    print("response: \(response)")
    if let errorMessage = response.error?.message {
        // Check for quota exceeded error
        if errorMessage.contains("exceeded your current quota") || 
           errorMessage.contains("quota") && errorMessage.contains("exceeded") {
            throw LLMError.quotaExceeded
        }
        throw NSError(domain: "GeminiError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
    }
    return response.candidates?.first?.content.parts.first?.text ?? ""
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
    let prompt = SystemPrompt + "\n\nUser: " + input
    
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
            - Meaning (ZH): \(card.meaning_zh ?? "nil")
            - Examples: \(card.examples?.count ?? 0) items
            - Extra Content: \(card.extra_content ?? "nil")
            
            Evaluate:
            1. If it's a vocabulary query, are all required fields (word, ipa, part_of_speech, meaning_en, meaning_zh, examples) filled correctly?
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
        // For Gemini: Direct generation without self-eval
        let responseContent = try await generateResponse(prompt: prompt, session: session)
        let cleanedContent = removeThoughtBlocks(responseContent)
        
        if let card = extractJSON(from: cleanedContent) {
            print("✅ Parsed WordCard from Gemini: \(card.word ?? "N/A")")
            return ("", card)
        }
        
        // Fallback: wrap plain text in extra_content
        let fallbackCard = WordCard(extra_content: cleanedContent)
        return ("", fallbackCard)
    }
}

let ExamSystemPrompt = """
You are an English Teacher creating vocabulary practice questions.

Generate questions for these types:

1. multiple_choice: Test word meaning with 4 options
   - type: "multiple_choice"
   - question: The question text (e.g., "What does 'happy' mean?")
   - options: Array of 4 strings (REQUIRED)
   - answer: The index of correct option as INTEGER (1, 2, 3, or 4)
   - DO NOT include answerText
   - DO NOT include passage

2. fill_in_blank: Test usage with a sentence containing _____
   - type: "fill_in_blank"
   - question: Sentence with _____ (e.g., "She felt _____ when she won the prize.")
   - answerText: The target word (string)
   - DO NOT include options
   - DO NOT include passage
   - DO NOT include answer

3. reading: Comprehension question with a passage and 4 options
   - type: "reading"
   - passage: A complete story WITHOUT any blanks (2-3 sentences, NO _____)
   - question: Comprehension question about the passage (e.g., "What is the main idea?")
   - options: Array of 4 strings (REQUIRED)
   - answer: The index of correct option as INTEGER (1, 2, 3, or 4)
   - DO NOT include answerText
   - Passage must be COMPLETE text, not a fill-in-blank

CRITICAL RULES:
- For multiple_choice: MUST have "options" array (4 strings) and "answer" (integer 1-4)
- For reading: MUST have "passage" (complete text), "options" array (4 strings), and "answer" (integer 1-4)
- For fill_in_blank: MUST have "question" (with _____) and "answerText" (string)
- Reading passages MUST be complete stories WITHOUT any _____ blanks
- NEVER mix question types - if it has _____, use fill_in_blank type, not reading
- NEVER omit the options field for multiple_choice or reading questions

WRONG reading example (DO NOT DO THIS):
{
  "type": "reading",
  "passage": "Despite his _____ nature, he managed to complete the project.",
  "question": "...",
  "options": null
}

CORRECT reading example:
{
  "type": "reading",
  "passage": "John loved to read books. Every weekend, he would visit the library and borrow at least three novels. His favorite genre was mystery.",
  "question": "What did John like to do on weekends?",
  "options": ["Play sports", "Visit the library", "Watch movies", "Go shopping"],
  "answer": 2
}

CORRECT fill_in_blank example:
{
  "type": "fill_in_blank",
  "question": "She felt _____ when she won the prize.",
  "answerText": "happy"
}

OUTPUT FORMAT:
You can output either:
1. A single JSON object with "questions" array: {"questions": [question1, question2, ...]}
2. OR multiple JSON code blocks, one question per block (both formats are supported)
"""

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
        // Strategy: Try with all words first, if safety guardrails trigger, retry with fewer words
        var allQuestions: [ExamQuestion] = []
        var remainingWords = words
        var retryCount = 0
        let maxRetries = 3
        
        while !remainingWords.isEmpty && retryCount < maxRetries {
            // Take up to 3 words at a time to avoid triggering safety filters
            let batchSize = min(3, remainingWords.count)
            let currentBatch = Array(remainingWords.prefix(batchSize))
            let wordList = currentBatch.joined(separator: ", ")
            
            let questionsNeeded = min(5 - allQuestions.count, batchSize * 2) // 2 questions per word
            let prompt = ExamSystemPrompt + "\n\nCreate \(questionsNeeded) practice questions for: \(wordList)"
            
            do {
                print("🔄 Attempting to generate \(questionsNeeded) questions for: \(wordList)")
                var examData = try await session.respond(to: prompt, generating: ExamData.self).content
                
                // Validation: Check if questions are properly formatted
                var hasInvalidQuestions = false
                var invalidReason = ""
                for question in examData.questions {
                    if (question.type == "reading" || question.type == "multiple_choice") {
                        // Check options
                        if question.options == nil || question.options?.count != 4 {
                            hasInvalidQuestions = true
                            invalidReason = "type=\(question.type) missing options"
                            print("⚠️ Invalid: \(invalidReason)")
                            break
                        }
                        // Check reading passage doesn't have blanks
                        if question.type == "reading" {
                            if let passage = question.passage, passage.contains("_____") {
                                hasInvalidQuestions = true
                                invalidReason = "reading passage contains blanks (should be fill_in_blank type)"
                                print("⚠️ Invalid: \(invalidReason)")
                                break
                            }
                            if question.passage == nil {
                                hasInvalidQuestions = true
                                invalidReason = "reading question missing passage"
                                print("⚠️ Invalid: \(invalidReason)")
                                break
                            }
                        }
                    } else if question.type == "fill_in_blank" {
                        // Check fill_in_blank has answerText
                        if question.answerText == nil || question.answerText?.isEmpty == true {
                            hasInvalidQuestions = true
                            invalidReason = "fill_in_blank missing answerText"
                            print("⚠️ Invalid: \(invalidReason)")
                            break
                        }
                    }
                }
                
                // Self-evaluation: check if exam is well-formed
                for attempt in 0..<10 {
                    let evalPrompt = """
                    Review the exam you just generated:
                    - Total questions: \(examData.questions.count)
                    - Question types: \(examData.questions.map { $0.type }.joined(separator: ", "))
                    
                    Evaluate:
                    1. Are there at least \(questionsNeeded) questions?
                    2. Are all options REAL text (not placeholders)?
                    3. For multiple_choice and reading questions: Do they ALL have exactly 4 options?
                    4. For reading questions: Are passages complete stories WITHOUT _____ blanks?
                    5. For fill_in_blank questions: Do they have answerText field?
                    6. Are questions related to: \(wordList)?
                    
                    Output a score (0-100) and reason.
                    """
                    
                    let evaluation = try await requestSelfEvaluation(prompt: evalPrompt, session: session)
                    //print("📊 Exam Self-Eval (attempt \(attempt + 1)): Score \(evaluation.score), Reason: \(evaluation.reason)")
                    
                    if evaluation.score >= 85 && !hasInvalidQuestions {
                        break
                    } else if attempt < 1 {
                        let fixPrompt = """
                        Improve your exam (Score: \(evaluation.score)).
                        Issue: \(evaluation.reason)
                        \(hasInvalidQuestions ? "CRITICAL ERROR: \(invalidReason)" : "")
                        
                        Target words: \(wordList)
                        Generate \(questionsNeeded) quality questions.
                        
                        REMEMBER:
                        - multiple_choice and reading: MUST have "options" array with 4 strings
                        - reading: passage must be COMPLETE text (NO _____ blanks)
                        - fill_in_blank: MUST have "answerText" field
                        - If passage has _____, use fill_in_blank type, NOT reading type
                        """
                        examData = try await session.respond(to: fixPrompt, generating: ExamData.self).content
                        
                        // Re-validate after regeneration
                        hasInvalidQuestions = false
                        invalidReason = ""
                        for question in examData.questions {
                            if (question.type == "reading" || question.type == "multiple_choice") {
                                if question.options == nil || question.options?.count != 4 {
                                    hasInvalidQuestions = true
                                    invalidReason = "missing options"
                                    break
                                }
                                if question.type == "reading" {
                                    if let passage = question.passage, passage.contains("_____") {
                                        hasInvalidQuestions = true
                                        invalidReason = "reading passage has blanks"
                                        break
                                    }
                                }
                            } else if question.type == "fill_in_blank" {
                                if question.answerText == nil || question.answerText?.isEmpty == true {
                                    hasInvalidQuestions = true
                                    invalidReason = "fill_in_blank missing answerText"
                                    break
                                }
                            }
                        }
                    }
                }
                
                // Successfully generated, add to results
                let newQuestions = examData.questions.map { ExamQuestion(from: $0) }
                print(newQuestions)
                allQuestions.append(contentsOf: newQuestions)
                print("✅ Generated \(newQuestions.count) questions, total: \(allQuestions.count)")
                
                // Remove processed words
                remainingWords.removeFirst(batchSize)
                retryCount = 0 // Reset retry count on success
                
                // Stop if we have enough questions
                if allQuestions.count >= 5 {
                    break
                }
                
            } catch {
                print("⚠️ Safety guardrails triggered for batch: \(wordList)")
                print("🔄 Trying with next words...")
                
                // Skip problematic words and try next batch
                remainingWords.removeFirst(min(1, remainingWords.count))
                retryCount += 1
                
                // If we have some questions already, continue
                if !allQuestions.isEmpty {
                    continue
                } else if retryCount >= maxRetries {
                    // Only throw error if we couldn't generate ANY questions after multiple retries
                    throw NSError(
                        domain: "ExamGenerationError",
                        code: -1,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Unable to generate questions with current vocabulary. Some words may trigger safety filters.",
                            NSLocalizedRecoverySuggestionErrorKey: "Try using different vocabulary words or switch to Gemini model in Settings."
                        ]
                    )
                }
            }
        }
        
        // Return whatever questions we managed to generate
        if allQuestions.isEmpty {
            throw NSError(
                domain: "ExamGenerationError",
                code: -2,
                userInfo: [
                    NSLocalizedDescriptionKey: "No questions could be generated. Please try different vocabulary words."
                ]
            )
        }
        
        print("✅ Final exam: \(allQuestions.count) questions generated")
        return Array(allQuestions.prefix(5)) // Return at most 5 questions
        
    } else {
        // For Gemini: Direct generation without self-eval (avoid confusion)
        let wordList = words.joined(separator: ", ")
        let prompt = ExamSystemPrompt + "\n\nCreate 5 practice questions for: \(wordList)"
        let responseContent = try await generateResponse(prompt: prompt, session: session)
        
        print("📝 Gemini Exam Response: \(responseContent)")
        
        let cleanedContent = removeThoughtBlocks(responseContent)
        if let examData = extractExamJSON(from: cleanedContent) {
            print("✅ Parsed \(examData.questions.count) questions from Gemini")
            return examData.questions.map { ExamQuestion(from: $0) }
        }
        
        print("⚠️ Failed to parse exam JSON from Gemini response")
        return []
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
        // For Gemini: Direct evaluation without self-eval, with simple fallback
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
        
        Output in JSON format.
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


