//
//  Item.swift
//  learnEng
//
//  Created by user20 on 2025/12/12.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var query: String
    var word: String?
    var ipa: String?
    var part_of_speech: String?
    var meaning_en: String?
    var meaning_zh: String?
    var examples: [String]?
    var word_family: [String]?
    var collocations: [String]?
    var nuance: String?
    var extra_content: String?
    
    init(timestamp: Date = Date(), query: String = "", word: String? = nil, ipa: String? = nil, part_of_speech: String? = nil, meaning_en: String? = nil, meaning_zh: String? = nil, examples: [String]? = nil, word_family: [String]? = nil, collocations: [String]? = nil, nuance: String? = nil, extra_content: String? = nil) {
        self.timestamp = timestamp
        self.query = query
        self.word = word
        self.ipa = ipa
        self.part_of_speech = part_of_speech
        self.meaning_en = meaning_en
        self.meaning_zh = meaning_zh
        self.examples = examples
        self.word_family = word_family
        self.collocations = collocations
        self.nuance = nuance
        self.extra_content = extra_content
    }
}
