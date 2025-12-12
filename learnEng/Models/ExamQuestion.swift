import Foundation

enum QuestionType: String, Codable {
    case multipleChoice = "multiple_choice"
    case fillInBlank = "fill_in_blank"
    case reading = "reading"
}

struct ExamQuestion: Identifiable, Codable {
    var id: UUID = UUID()
    let type: QuestionType
    let question: String
    let options: [String]?
    let passage: String?
    let answer: String
    
    enum CodingKeys: String, CodingKey {
        case type, question, options, passage, answer
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(QuestionType.self, forKey: .type)
        question = try container.decode(String.self, forKey: .question)
        options = try container.decodeIfPresent([String].self, forKey: .options)
        passage = try container.decodeIfPresent(String.self, forKey: .passage)
        answer = try container.decode(String.self, forKey: .answer)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(question, forKey: .question)
        try container.encode(options, forKey: .options)
        try container.encode(passage, forKey: .passage)
        try container.encode(answer, forKey: .answer)
    }
}

struct ExamData: Codable {
    let questions: [ExamQuestion]
}
