import Foundation
import FoundationModels

enum QuestionType: String, Codable {
    case multipleChoice = "multiple_choice"
    case fillInBlank = "fill_in_blank"
    case reading = "reading"
}

// The raw question data that LLM generates (no UUID)
@Generable
struct GeneratedQuestion: Codable {
    let type: String
    let question: String
    let options: [String]?
    let passage: String?
    let answer: Int?  // For multiple_choice/reading: 1, 2, 3, 4 (option index)
    let answerText: String?  // For fill_in_blank: the actual word
    let explanation: String? // Explanation of the answer
}

// The UI-friendly version with UUID and QuestionType
struct ExamQuestion: Identifiable, Codable {
    var id: UUID = UUID()
    let type: String
    let question: String
    let options: [String]?
    let passage: String?
    let answer: Int?
    let answerText: String?
    let explanation: String?
    
    // Computed property to get the actual QuestionType
    var questionType: QuestionType {
        QuestionType(rawValue: type) ?? .multipleChoice
    }
    
    // Computed property to get the correct answer text
    var correctAnswerText: String {
        if questionType == .multipleChoice || questionType == .reading {
            // 1. Try standard 1-based index
            if let answer = answer, let options = options, answer > 0 && answer <= options.count {
                return options[answer - 1]  // Convert 1-based to 0-based index
            }
            
            // 2. Handle 0-based index (if answer is 0)
            if let answer = answer, let options = options, answer == 0 && options.count > 0 {
                return options[0]
            }
            
            // 3. Fallback: Check if answerText matches one of the options
            if let answerText = answerText, let options = options, options.contains(answerText) {
                return answerText
            }
            
            return "Invalid answer index"
        } else {
            // For fill_in_blank, use answerText
            return answerText ?? ""
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type, question, options, passage, answer, answerText, explanation
    }
    
    // Initialize from GeneratedQuestion
    init(from generated: GeneratedQuestion) {
        self.id = UUID()
        self.type = generated.type
        self.question = generated.question
        self.options = generated.options
        self.passage = generated.passage
        self.answer = generated.answer
        self.answerText = generated.answerText
        self.explanation = generated.explanation
    }  
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        question = try container.decode(String.self, forKey: .question)
        options = try container.decodeIfPresent([String].self, forKey: .options)
        passage = try container.decodeIfPresent(String.self, forKey: .passage)
        answer = try container.decodeIfPresent(Int.self, forKey: .answer)
        answerText = try container.decodeIfPresent(String.self, forKey: .answerText)
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(question, forKey: .question)
        try container.encode(options, forKey: .options)
        try container.encode(passage, forKey: .passage)
        try container.encode(answer, forKey: .answer)
        try container.encode(answerText, forKey: .answerText)
        try container.encode(explanation, forKey: .explanation)
    }
}

@Generable
struct ExamData: Codable {
    let questions: [GeneratedQuestion]
}
