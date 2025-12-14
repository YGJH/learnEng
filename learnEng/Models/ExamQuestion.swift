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
    
    // Computed property to get the actual QuestionType
    var questionType: QuestionType {
        QuestionType(rawValue: type) ?? .multipleChoice
    }
    
    // Computed property to get the correct answer text
    var correctAnswerText: String {
        if questionType == .multipleChoice || questionType == .reading {
            // For multiple choice, answer is the index (1-based)
            if let answer = answer, let options = options, answer > 0 && answer <= options.count {
                return options[answer - 1]  // Convert 1-based to 0-based index
            }
            return "Invalid answer index"
        } else {
            // For fill_in_blank, use answerText
            return answerText ?? ""
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type, question, options, passage, answer, answerText
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
    }  
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        question = try container.decode(String.self, forKey: .question)
        options = try container.decodeIfPresent([String].self, forKey: .options)
        passage = try container.decodeIfPresent(String.self, forKey: .passage)
        answer = try container.decodeIfPresent(Int.self, forKey: .answer)
        answerText = try container.decodeIfPresent(String.self, forKey: .answerText)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(question, forKey: .question)
        try container.encode(options, forKey: .options)
        try container.encode(passage, forKey: .passage)
        try container.encode(answer, forKey: .answer)
        try container.encode(answerText, forKey: .answerText)
    }
}

@Generable
struct ExamData: Codable {
    let questions: [GeneratedQuestion]
}
