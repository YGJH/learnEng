import SwiftUI
import SwiftData

struct FlashCardView: View {
    @Query private var items: [Item]
    @Environment(\.dismiss) private var dismiss
    
    @State private var cards: [FlashCard] = []
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero
    @State private var completedCount = 0
    @State private var forgottenCards: [FlashCard] = []
    @State private var showCompletion = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if cards.isEmpty {
                        if items.isEmpty {
                            ContentUnavailableView(
                                "No Vocabulary",
                                systemImage: "book.closed",
                                description: Text("Add some words to your vocabulary first.")
                            )
                        } else {
                            VStack(spacing: 20) {
                                Image(systemName: "rectangle.stack.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.blue)
                                
                                Text("Ready to review?")
                                    .font(.title2)
                                    .bold()
                                
                                // 計算有多少張卡片（使用 translation 或 meaning_en）
                                let itemsWithMeaning = items.filter { item in
                                    let hasTranslation = item.translation != nil && !item.translation!.isEmpty
                                    let hasMeaningEn = item.meaning_en != nil && !item.meaning_en!.isEmpty
                                    return hasTranslation || hasMeaningEn
                                }
                                let cardCount = min(itemsWithMeaning.count, 30)
                                
                                if cardCount > 0 {
                                    VStack(spacing: 12) {
                                        Text("We'll show you \(cardCount) flashcards to test your memory.")
                                            .multilineTextAlignment(.center)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal)
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "rectangle.stack.fill")
                                                .foregroundStyle(.blue)
                                            Text("\(cardCount) cards ready")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.blue)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(Color.blue.opacity(0.1))
                                        )
                                    }
                                    
                                    Button("Start Review") {
                                        startFlashCards()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)
                                } else {
                                    VStack(spacing: 12) {
                                        Text("⚠️ No definitions found")
                                            .font(.headline)
                                            .foregroundStyle(.orange)
                                        
                                        Text("Your vocabulary items don't have meanings yet.\nGo to Vocabulary and look up some words!")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.orange.opacity(0.1))
                                    )
                                }
                            }
                        }
                    } else if showCompletion {
                        // Completion view
                        VStack(spacing: 24) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.green)
                            
                            Text("Great Job! 🎉")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            VStack(spacing: 8) {
                                Text("You've reviewed \(completedCount) cards!")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                
                                Text("Total cards in deck: \(cards.count)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            
                            Button("Review Again") {
                                startFlashCards()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        .padding()
                    } else {
                        // Progress bar
                        VStack(spacing: 8) {
                            HStack {
                                Text("\(min(currentIndex + 1, cards.count)) / \(cards.count)")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Text("Completed: \(completedCount)")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                            }
                            .padding(.horizontal)
                            
                            ProgressView(value: Double(min(currentIndex + 1, cards.count)), total: Double(cards.count))
                                .tint(.blue)
                                .padding(.horizontal)
                        }
                        
                        // Card stack
                        ZStack {
                            // Show next 2 cards as background (slightly visible)
                            ForEach(Array(cards.indices.suffix(from: currentIndex).prefix(3)), id: \.self) { index in
                                if index < cards.count {
                                    let offset = index - currentIndex
                                    
                                    if offset == 0 {
                                        // Current card - fully interactive
                                        CardView(
                                            card: cards[index],
                                            isFlipped: isFlipped
                                        )
                                        .offset(dragOffset)
                                        .rotationEffect(.degrees(Double(dragOffset.width / 20)))
                                        .gesture(
                                            DragGesture()
                                                .onChanged { gesture in
                                                    dragOffset = gesture.translation
                                                }
                                                .onEnded { gesture in
                                                    handleSwipe(gesture: gesture)
                                                }
                                        )
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                                isFlipped.toggle()
                                            }
                                        }
                                        .zIndex(2)
                                    } else {
                                        // Background cards - just for visual depth
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(.systemBackground))
                                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                            .frame(height: 500)
                                            .scaleEffect(1 - CGFloat(offset) * 0.05)
                                            .offset(y: CGFloat(offset) * 10)
                                            .opacity(0.6 - CGFloat(offset) * 0.2)
                                            .zIndex(Double(2 - offset))
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                        
                        // Swipe indicators
                        HStack(spacing: 40) {
                            VStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.red)
                                    .opacity(dragOffset.width < -50 ? 1 : 0.3)
                                
                                Text("Forgot")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.red)
                            }
                            
                            Spacer()
                            
                            Text("Tap to flip")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.green)
                                    .opacity(dragOffset.width > 50 ? 1 : 0.3)
                                
                                Text("Remember")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Flash Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    func startFlashCards() {
        // 篩選出有翻譯或英文定義的單字（使用 meaning_en 作為備用）
        let itemsWithMeaning = items.filter { item in
            // 優先使用 translation，如果沒有則使用 meaning_en
            let hasTranslation = item.translation != nil && !item.translation!.isEmpty
            let hasMeaningEn = item.meaning_en != nil && !item.meaning_en!.isEmpty
            return hasTranslation || hasMeaningEn
        }
        
        print("📚 Total items: \(items.count)")
        print("📖 Items with translation: \(items.filter { $0.translation != nil && !$0.translation!.isEmpty }.count)")
        print("📘 Items with meaning_en: \(items.filter { $0.meaning_en != nil && !$0.meaning_en!.isEmpty }.count)")
        print("✅ Items with either: \(itemsWithMeaning.count)")
        
        // 隨機排序並取最多 30 個
        let shuffled = itemsWithMeaning.shuffled()
        let count = min(shuffled.count, 30)
        let selected = Array(shuffled.prefix(count))
        
        cards = selected.map { item in
            // 優先使用 translation，如果沒有則使用 meaning_en
            let meaning = item.translation ?? item.meaning_en ?? ""
            let cardWord = item.word ?? item.query
            
            print("🃏 Card: \(cardWord) -> \(meaning)")
            
            return FlashCard(
                word: cardWord,
                translation: meaning
            )
        }
        
        print("🎴 Created \(cards.count) flash cards")
        
        // 如果沒有卡片
        if cards.isEmpty {
            print("⚠️ No cards with translations or meanings available")
        }
        
        currentIndex = 0
        completedCount = 0
        forgottenCards = []
        showCompletion = false
        isFlipped = false
        dragOffset = .zero
    }
    
    func handleSwipe(gesture: DragGesture.Value) {
        let swipeThreshold: CGFloat = 100
        
        if abs(gesture.translation.width) > swipeThreshold {
            withAnimation(.spring()) {
                // Animate card flying off screen
                dragOffset = CGSize(
                    width: gesture.translation.width > 0 ? 1000 : -1000,
                    height: gesture.translation.height
                )
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if gesture.translation.width < 0 {
                    // Swiped left - forgot
                    handleForgot()
                } else {
                    // Swiped right - remembered
                    handleRemember()
                }
            }
        } else {
            // Return to center
            withAnimation(.spring()) {
                dragOffset = .zero
            }
        }
    }
    
    func handleForgot() {
        let currentCard = cards[currentIndex]
        forgottenCards.append(currentCard)
        
        // 先從當前位置移除這張卡
        cards.remove(at: currentIndex)
        
        // 計算要插入的位置（在當前位置後 5-10 張卡之間）
        // 因為已經移除了當前卡，所以不需要 +1
        let insertPosition = min(currentIndex + Int.random(in: 5...10), cards.count)
        
        // 把忘記的卡片插入到後面
        cards.insert(currentCard, at: insertPosition)
        
        // 不需要 currentIndex += 1，因為移除後下一張卡自動變成當前位置
        
        resetCardState()
        checkCompletion()
    }
    
    func handleRemember() {
        completedCount += 1
        currentIndex += 1
        
        resetCardState()
        checkCompletion()
    }
    
    func resetCardState() {
        withAnimation {
            dragOffset = .zero
            isFlipped = false
        }
    }
    
    func checkCompletion() {
        if currentIndex >= cards.count {
            withAnimation {
                showCompletion = true
            }
        }
    }
}

struct CardView: View {
    let card: FlashCard
    let isFlipped: Bool
    
    var body: some View {
        ZStack {
            // Back side (translation) - 背面
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 20) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.purple)
                    
                    Text(card.translation)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Text("(翻譯)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .rotation3DEffect(
                .degrees(isFlipped ? 0 : 180),
                axis: (x: 0, y: 1, z: 0)
            )
            .opacity(isFlipped ? 1 : 0)
            
            // Front side (word) - 正面
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 20) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    
                    Text(card.word)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Text("(點擊翻面)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .opacity(isFlipped ? 0 : 1)
        }
        .frame(height: 500)
    }
}

struct FlashCard: Identifiable {
    let id = UUID()
    let word: String
    let translation: String
}

#Preview {
    FlashCardView()
}
