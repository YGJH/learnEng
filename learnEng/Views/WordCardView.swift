import SwiftUI
import SwiftData
import TipKit

struct WordCardView: View {
    let card: WordCard
    let query: String
    @Environment(\.modelContext) private var modelContext
    @State private var isSaved = false
    
    // Tip
    let vocabTip = VocabularyTip()
    
    func saveCard() {
        let newItem = Item(
            query: query,
            word: card.word,
            ipa: card.ipa,
            part_of_speech: card.part_of_speech,
            meaning_en: card.meaning_en,
            translation: card.translation,
            examples: card.examples,
            word_family: card.word_family,
            collocations: card.collocations,
            nuance: card.nuance,
            extra_content: card.extra_content
        )
        modelContext.insert(newItem)
        withAnimation {
            isSaved = true
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Tip View
            TipView(vocabTip, arrowEdge: .bottom)
            
            // Typo Correction Notice
            if let word = card.word,
               word.lowercased().trimmingCharacters(in: .whitespaces) != query.lowercased().trimmingCharacters(in: .whitespaces) {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)
                    
                    Text("Corrected from \"\(query)\"")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Header: Word, IPA, POS, Save Button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(card.word ?? query)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Button {
                            SpeechSynthesizer.shared.speak(card.word ?? query)
                        } label: {
                            Image(systemName: "speaker.wave.2.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                                .shadow(color: .blue.opacity(0.3), radius: 4)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        if let ipa = card.ipa {
                            Text(ipa)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospaced()
                        }
                        if let pos = card.part_of_speech {
                            Text(pos)
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
                
                Button(action: saveCard) {
                    HStack(spacing: 6) {
                        Image(systemName: isSaved ? "checkmark.circle.fill" : "bookmark.fill")
                            .font(.headline)
                        if isSaved {
                            Text("Saved")
                                .font(.caption)
                                .fontWeight(.bold)
                        } else {
                            Text("Save")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundStyle(isSaved ? .green : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            if isSaved {
                                Color.green.opacity(0.15)
                            } else {
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        }
                    )
                    .clipShape(Capsule())
                    .shadow(color: isSaved ? .clear : .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .disabled(isSaved)
            }
            
            Divider()
                .background(Color.gray.opacity(0.2))
            
            // Definitions
            if let meaningEn = card.meaning_en {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Definition (EN)", systemImage: "text.book.closed")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                    Text(meaningEn)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                }
            }
            
            if let translation = card.translation {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Translation", systemImage: "globe")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                    Text(translation)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
            
            // Nuance
            if let nuance = card.nuance {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.max.fill")
                        .foregroundStyle(.yellow)
                        .font(.title3)
                    Text(nuance)
                        .font(.callout)
                        .italic()
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
                )
            }
            
            // Examples
            if let examples = card.examples, !examples.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Examples", systemImage: "quote.opening")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    
                    ForEach(examples, id: \.self) { example in
                        HStack(alignment: .top, spacing: 12) {
                            Capsule()
                                .fill(Color.green.opacity(0.5))
                                .frame(width: 3)
                                .padding(.vertical, 2)
                            Text(example)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                    }
                }
            }
            
            // Footer: Word Family & Collocations
            if (card.word_family?.isEmpty == false) || (card.collocations?.isEmpty == false) {
                Divider()
                    .background(Color.gray.opacity(0.2))
                
                HStack(alignment: .top, spacing: 20) {
                    if let family = card.word_family, !family.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Word Family")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                            ForEach(family, id: \.self) { word in
                                Text("• \(word)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if let colls = card.collocations, !colls.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Collocations")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.purple)
                            ForEach(colls, id: \.self) { coll in
                                Text("• \(coll)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            
            if let extra = card.extra_content {
                Divider()
                Text(extra)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
    }
}
