import Foundation
import FoundationModels

@Generable
struct WordCard: Codable {
    let word: String?
    let ipa: String?
    let part_of_speech: String?
    let meaning_en: String?
    let translation: String?
    let examples: [String]?
    let word_family: [String]?
    let collocations: [String]?
    let nuance: String?
    let extra_content: String?
    
    enum CodingKeys: String, CodingKey {
        case word
        case ipa
        case part_of_speech
        case meaning_en
        case translation = "meaning_zh"  // Keep JSON key for backward compatibility
        case examples
        case word_family
        case collocations
        case nuance
        case extra_content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        word = try? container.decodeIfPresent(String.self, forKey: .word)
        ipa = try? container.decodeIfPresent(String.self, forKey: .ipa)
        part_of_speech = try? container.decodeIfPresent(String.self, forKey: .part_of_speech)
        meaning_en = try? container.decodeIfPresent(String.self, forKey: .meaning_en)
        translation = try? container.decodeIfPresent(String.self, forKey: .translation)
        examples = try? container.decodeIfPresent([String].self, forKey: .examples)
        word_family = try? container.decodeIfPresent([String].self, forKey: .word_family)
        collocations = try? container.decodeIfPresent([String].self, forKey: .collocations)
        nuance = try? container.decodeIfPresent(String.self, forKey: .nuance)
        extra_content = try? container.decodeIfPresent(String.self, forKey: .extra_content)
    }
    
    init(word: String? = nil, ipa: String? = nil, part_of_speech: String? = nil, meaning_en: String? = nil, translation: String? = nil, examples: [String]? = nil, word_family: [String]? = nil, collocations: [String]? = nil, nuance: String? = nil, extra_content: String? = nil) {
        self.word = word
        self.ipa = ipa
        self.part_of_speech = part_of_speech
        self.meaning_en = meaning_en
        self.translation = translation
        self.examples = examples
        self.word_family = word_family
        self.collocations = collocations
        self.nuance = nuance
        self.extra_content = extra_content
    }
}
