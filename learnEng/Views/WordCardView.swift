import SwiftUI
import SwiftData

struct WordCardView: View {
    let card: WordCard
    let query: String
    @Environment(\.modelContext) private var modelContext
    @State private var isSaved = false
    
    func saveCard() {
        let newItem = Item(
            query: query,
            word: card.word,
            ipa: card.ipa,
            part_of_speech: card.part_of_speech,
            meaning_en: card.meaning_en,
            meaning_zh: card.meaning_zh,
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
            // Header: Word, IPA, POS, Save Button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.word ?? query)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
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
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isSaved ? .green : .blue)
                        .background(Color.white.clipShape(Circle()))
                }
                .disabled(isSaved)
            }
            
            Divider()
            
            // Definitions
            if let meaningEn = card.meaning_en {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Definition (EN)", systemImage: "text.book.closed")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    Text(meaningEn)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
            
            if let meaningZh = card.meaning_zh {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Definition (ZH)", systemImage: "character.book.closed.zh")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    Text(meaningZh)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
            
            // Nuance
            if let nuance = card.nuance {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.max.fill")
                        .foregroundStyle(.yellow)
                    Text(nuance)
                        .font(.callout)
                        .italic()
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
                        }
                    }
                }
            }
            
            // Footer: Word Family & Collocations
            if (card.word_family?.isEmpty == false) || (card.collocations?.isEmpty == false) {
                Divider()
                
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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}
