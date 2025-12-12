import Foundation
import FoundationModels
import SwiftUI

enum LLMError: Error, LocalizedError {
    case missingApiKey
    
    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "Gemini API Key is missing."
        }
    }
}

let SystemPrompt = """
System:
You are a professional and helpful English Teacher.
Your goal is to assist the user with vocabulary, grammar, and nuance in English.

**Process:**
1. **Analyze**: Start by thinking step-by-step inside <Thought> tags.
   - Identify the user's core intent (Is it a vocabulary query? Or a grammar/general question?).
   - If it's a vocabulary query, determine the word's part of speech, definition, and relevant examples.
   - If it's a general question, plan a clear and educational explanation.
2. **Response**: 
   - **Case A (Vocabulary Definition)**: If the user is querying the meaning of a word or idiom, output the response STRICTLY in the following JSON format inside a code block:
     ```json
     {
         "word": "Target Word",
         "ipa": "/IPA pronunciation/",
         "part_of_speech": "v./n./adj...",
         "meaning_en": "Clear English definition",
         "meaning_zh": "Traditional Chinese translation",
         "examples": ["Example sentence 1", "Example sentence 2 (varied context)"],
         "word_family": ["Derivatives or related forms"],
         "collocations": ["Common phrase 1", "Common phrase 2"],
         "nuance": "Any specific tone (formal/informal/negative) or usage note"
     }
     ```
   - **Case B (General/Other)**: For grammar questions, translation requests, or free chat, reply normally in plain text. Use the user's language (Traditional Chinese) for explanations unless requested otherwise.

user query: 
"""

// MARK: - Model Abstraction

private func callGemini(prompt: String, model: String, apiKey: String) async throws -> String {
    guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
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
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, _) = try await URLSession.shared.data(for: request)
    
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
    
    if let errorMessage = response.error?.message {
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

func give_reply(input: String, session: LanguageModelSession) async throws -> (String, WordCard?) {
    let input_prompt = SystemPrompt + input
    
    // 1. Initial Generation
    var responseContent = try await generateResponse(prompt: input_prompt, session: session)
    
    // 2. Self-Correction Loop (Max 2 retries)
    let selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "local"
    if selectedModel == "local" {
        for _ in 0..<2 {
            let cleanedPreview = removeThoughtBlocks(responseContent)
            
            let evalPrompt = """
            System: [Self-Correction Mode]
            Review your response above.
            1. Does it directly answer the user's intent?
            2. If it's a vocabulary definition, is it in valid JSON?
            3. Are there hallucinations or weird phrasing?
            
            Output JSON ONLY:
            { "score": <0-100>, "reason": "Short explanation" }
            """
            
            // We ask the model to evaluate its own previous output
            let evalResponseContent = try await generateResponse(prompt: evalPrompt, session: session)
            let evalCleaned = removeThoughtBlocks(evalResponseContent)
            
            if let evaluation = extractSelfEvaluation(from: evalCleaned) {
                print("Self-Eval Score: \(evaluation.score), Reason: \(evaluation.reason)")
                
                if evaluation.score >= 85 {
                    break // Good enough
                } else {
                    // Request improvement
                    let fixPrompt = "System: Your previous response was poor (Score: \(evaluation.score)). Reason: \(evaluation.reason). Please regenerate the response correctly."
                    responseContent = try await generateResponse(prompt: fixPrompt, session: session)
                    continue
                }
            } else {
                // If evaluation fails to parse, break to avoid infinite loops
                print("Failed to parse self-evaluation. Assuming response is okay.")
                break
            }
        }
    }

    print("Final Response: \(responseContent)")

    // 3. Clean up <Thought> blocks
    let cleanedContent = removeThoughtBlocks(responseContent)
    
    // 4. Try to extract JSON card from the cleaned content
    if let card = extractJSON(from: cleanedContent) {
        return ("", card)
    }
    
    // 5. If no card, return card with extra content
    let fallbackCard = WordCard(extra_content: cleanedContent)
    return ("", fallbackCard)
}

let ExamSystemPrompt = """
System:
You are an expert English Teacher creating a vocabulary exam.
The user will provide a list of vocabulary words.
You must generate an exam based on these words to test the user's understanding.

**Requirements:**
1. **Real Content**: Do NOT use placeholders like "Option A", "Option B", or "Question text...". You must generate actual English questions and meaningful options.
2. **Question Types**:
   - `multiple_choice`: A question testing the definition or usage of a target word. Provide 4 distinct options (1 correct, 3 distractors).
   - `fill_in_blank`: A sentence with the target word missing (represented by _____).
   - `reading`: A short, coherent story (2-3 sentences) containing one or more target words, followed by a comprehension question.

**Output Format:**
Return ONLY the JSON object inside a code block.

```json
{
    "questions": [
        {
            "type": "multiple_choice",
            "question": "What does the word 'abundant' mean?",
            "options": ["Scarce and rare", "Plentiful and large in quantity", "Dark and gloomy", "Fast and efficient"],
            "answer": "Plentiful and large in quantity"
        },
        {
            "type": "fill_in_blank",
            "question": "The scientist conducted an _____ to test her hypothesis.",
            "answer": "experiment"
        },
        {
            "type": "reading",
            "passage": "Tom was nervous about the exam. He studied all night to ensure he would pass.",
            "question": "Why did Tom study all night?",
            "options": ["He was bored", "He wanted to pass the exam", "He couldn't sleep", "He was playing games"],
            "answer": "He wanted to pass the exam"
        }
    ]
}
```
"""

private func extractExamJSON(from text: String) -> ExamData? {
    func tryDecode(_ jsonString: String) -> ExamData? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ExamData.self, from: data)
    }

    let patternWithLang = "```json\\s*(\\{[\\s\\S]*?\\})\\s*```"
    if let regex = try? NSRegularExpression(pattern: patternWithLang, options: []),
       let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
       let range = Range(match.range(at: 1), in: text) {
        if let data = tryDecode(String(text[range])) { return data }
    }
    
    let patternGeneric = "```\\s*(\\{[\\s\\S]*?\\})\\s*```"
    if let regex = try? NSRegularExpression(pattern: patternGeneric, options: []),
       let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
       let range = Range(match.range(at: 1), in: text) {
        if let data = tryDecode(String(text[range])) { return data }
    }
    
    if let start = text.firstIndex(of: "{"),
       let end = text.lastIndex(of: "}") {
        let jsonString = String(text[start...end])
        if let data = tryDecode(jsonString) { return data }
    }
    
    return nil
}

func generateExam(words: [String], session: LanguageModelSession) async throws -> [ExamQuestion] {
    guard !words.isEmpty else { return [] }
    
    let wordList = words.joined(separator: ", ")
    let prompt = ExamSystemPrompt + "\n\nTarget words: \(wordList)\n\nPlease generate 5 questions."
    
    // 1. Initial Generation
    var responseContent = try await generateResponse(prompt: prompt, session: session)
    
    // 2. Self-Correction Loop
    let selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "local"
    if selectedModel == "local" {
        for _ in 0..<2 {
            let cleanedPreview = removeThoughtBlocks(responseContent)
            
            let evalPrompt = """
            System: [Self-Correction Mode]
            Review your exam generation above.
            1. Is it valid JSON?
            2. Does it include all 3 required question types (multiple_choice, fill_in_blank, reading)?
            3. Are the options REAL words/phrases (NOT "Option A", "Option B")?
            4. Are the questions logical and related to the target words?
            
            Output JSON ONLY:
            { "score": <0-100>, "reason": "Short explanation" }
            """
            
            let evalResponseContent = try await generateResponse(prompt: evalPrompt, session: session)
            let evalCleaned = removeThoughtBlocks(evalResponseContent)
            
            if let evaluation = extractSelfEvaluation(from: evalCleaned) {
                print("Exam Self-Eval Score: \(evaluation.score), Reason: \(evaluation.reason)")
                
                if evaluation.score >= 85 {
                    break
                } else {
                    let fixPrompt = "System: Your previous exam generation was poor (Score: \(evaluation.score)). Reason: \(evaluation.reason). Please regenerate the exam correctly."
                    responseContent = try await generateResponse(prompt: fixPrompt, session: session)
                    continue
                }
            } else {
                break
            }
        }
    }
    
    print("Final Exam Response: \(responseContent)")
    
    let cleanedContent = removeThoughtBlocks(responseContent)
    if let examData = extractExamJSON(from: cleanedContent) {
        return examData.questions
    }
    
    return []
}

struct AnswerEvaluation: Decodable {
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
    
    // Fallback initializer
    init(isCorrect: Bool, feedback: String) {
        self.category = isCorrect ? "Perfect" : "Wrong"
        self.score = isCorrect ? 100 : 0
        self.feedback = feedback
        self.corrected_answer = nil
    }
}

func evaluateAnswer(question: String, correctAnswer: String, userAnswer: String, session: LanguageModelSession) async throws -> AnswerEvaluation {
let prompt = """
    System:
    You are an expert English Teacher evaluating a student's response.
    Do not just judge "Correct" or "Incorrect". You must assign a quality level to the answer.

    **Grading Rubric:**
    1. **Perfect**: The answer is grammatically perfect and semantically identical to the correct answer (or a perfect synonym).
    2. **Acceptable**: The answer conveys the correct meaning but has minor issues (e.g., punctuation, capitalization, contraction usage, or slightly awkward phrasing).
    3. **Close**: The core meaning is understood, but there are grammatical errors (wrong tense, wrong preposition) or spelling mistakes.
    4. **Wrong**: The answer conveys a different meaning, is irrelevant, or is unintelligible.

    **Process:**
    1. Analyze the student's answer inside <Thought> tags. Compare it with the correct reference.
    2. Determine the specific error (if any) and assign a category.
    3. Output STRICTLY in JSON format.

    **Input:**
    - Question: "\(question)"
    - Correct Reference: "\(correctAnswer)"
    - Student Answer: "\(userAnswer)"

    **Output JSON Structure:**
    ```json
    {
      "category": "Perfect" | "Acceptable" | "Close" | "Wrong",
      "score": 0 to 100, // Integrity score (100=Perfect, 80=Acceptable, 50=Close, 0=Wrong)
      "feedback": "Short, specific feedback explaining the error or praising the answer.",
      "corrected_answer": "Provide the fixed version if there were errors, otherwise null"
    }
    ```
    """    
    // 1. Initial Generation
    var responseContent = try await generateResponse(prompt: prompt, session: session)
    
    // 2. Self-Correction Loop
    let selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "local"
    if selectedModel == "local" {
        for _ in 0..<2 {
            let cleanedPreview = removeThoughtBlocks(responseContent)
            
            let evalPrompt = """
            System: [Self-Correction Mode]
            Review your evaluation above.
            1. Is it valid JSON?
            2. Does the score and category match the rubric?
            3. Is the feedback helpful?
            
            Output JSON ONLY:
            { "score": <0-100>, "reason": "Short explanation" }
            """
            
            let evalResponseContent = try await generateResponse(prompt: evalPrompt, session: session)
            let evalCleaned = removeThoughtBlocks(evalResponseContent)
            
            if let evaluation = extractSelfEvaluation(from: evalCleaned) {
                print("Grading Self-Eval Score: \(evaluation.score), Reason: \(evaluation.reason)")
                
                if evaluation.score >= 85 {
                    break
                } else {
                    let fixPrompt = "System: Your previous evaluation was poor (Score: \(evaluation.score)). Reason: \(evaluation.reason). Please regenerate the evaluation correctly."
                    responseContent = try await generateResponse(prompt: fixPrompt, session: session)
                    continue
                }
            } else {
                break
            }
        }
    }
    
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
    
    // Default fallback if LLM fails
    let isMatch = userAnswer.lowercased().trimmingCharacters(in: .whitespaces) == correctAnswer.lowercased().trimmingCharacters(in: .whitespaces)
    return AnswerEvaluation(isCorrect: isMatch, feedback: isMatch ? "Correct!" : "Incorrect. The expected answer was \(correctAnswer).")
}

// MARK: - Self Correction

struct SelfEvaluation: Decodable {
    let score: Int
    let reason: String
}

private func extractSelfEvaluation(from text: String) -> SelfEvaluation? {
    func tryDecode(_ jsonString: String) -> SelfEvaluation? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SelfEvaluation.self, from: data)
    }
    
    let pattern = "```json\\s*(\\{[\\s\\S]*?\\})\\s*```"
    if let regex = try? NSRegularExpression(pattern: pattern, options: []),
       let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
       let range = Range(match.range(at: 1), in: text) {
        if let result = tryDecode(String(text[range])) { return result }
    }
    
    if let start = text.firstIndex(of: "{"),
       let end = text.lastIndex(of: "}") {
        let jsonString = String(text[start...end])
        if let result = tryDecode(jsonString) { return result }
    }
    return nil
}


