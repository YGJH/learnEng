import Foundation
import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    var query: String
    var reply: String
    var card: WordCard?
    
    var formattedReply: AttributedString {
        do {
            return try AttributedString(markdown: reply)
        } catch {
            return AttributedString(reply)
        }
    }
}
