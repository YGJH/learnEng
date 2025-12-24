import SwiftUI
import TipKit

struct ChatTip: Tip {
    var title: Text {
        Text("Start Chatting")
    }
    
    var message: Text? {
        Text("Type a word or sentence to start practicing English with AI.")
    }
    
    var image: Image? {
        Image(systemName: "bubble.left.and.bubble.right.fill")
    }
}

struct VocabularyTip: Tip {
    var title: Text {
        Text("Save Words")
    }
    
    var message: Text? {
        Text("Tap the 'Save' button on a word card to add it to your vocabulary list.")
    }
    
    var image: Image? {
        Image(systemName: "star.fill")
    }
}
