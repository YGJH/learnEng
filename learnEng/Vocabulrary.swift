import SwiftUI
import SwiftData

struct VocabulraryView: View {
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedItem: Item?
    @State private var searchText = ""
    
    var filteredItems: [Item] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { item in
                (item.word ?? item.query).localizedCaseInsensitiveContains(searchText) ||
                (item.translation ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Vocabulary Yet",
                        systemImage: "book.closed",
                        description: Text("Words you save from chat will appear here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Search Bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Search words...", text: $searchText)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.horizontal)
                            .padding(.top)
                            
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    selectedItem = item
                                } label: {
                                    VocabularyCard(item: item, index: index)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Vocabulary")
            .fullScreenCover(item: $selectedItem) { item in
                VocabularyDetailView(item: item)
            }
        }
    }

    private func deleteItem(_ item: Item) {
        withAnimation {
            modelContext.delete(item)
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct VocabularyCard: View {
    let item: Item
    let index: Int
    @State private var isVisible = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.word ?? item.query)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Image(systemName: "speaker.wave.2.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
                    .highPriorityGesture(
                        TapGesture()
                            .onEnded { _ in
                                SpeechSynthesizer.shared.speak(item.word ?? item.query)
                            }
                    )
                
                if let pos = item.part_of_speech {
                    Text(pos)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            if let meaningEn = item.meaning_en {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "book.closed")
                        .foregroundStyle(.blue)
                        .font(.caption)
                        .padding(.top, 2)
                    
                    Text(meaningEn)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            
            if let translation = item.translation {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "globe")
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(.top, 2)
                    
                    Text(translation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            
            if let examples = item.examples, let firstExample = examples.first {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "quote.opening")
                        .foregroundStyle(.green)
                        .font(.caption)
                        .padding(.top, 2)
                    
                    Text(firstExample)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .lineLimit(1)
                }
            }
            
            HStack(spacing: 8) {
                if let family = item.word_family, !family.isEmpty {
                    BadgeView(text: "Family", color: .orange)
                }
                if let colls = item.collocations, !colls.isEmpty {
                    BadgeView(text: "Collocations", color: .purple)
                }
                Spacer()
                Text(item.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
        .offset(y: isVisible ? 0 : 50)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index % 10) * 0.05)) {
                isVisible = true
            }
        }
    }
}

struct BadgeView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}


struct VocabularyDetailView: View {
    let item: Item
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.word ?? item.query)
                                .font(.largeTitle)
                                .fontWeight(.heavy)
                                .foregroundStyle(.primary)
                            
                            Button {
                                SpeechSynthesizer.shared.speak(item.word ?? item.query)
                            } label: {
                                Image(systemName: "speaker.wave.2.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.blue)
                            }
                            
                            if let ipa = item.ipa {
                                Text(ipa)
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .monospaced()
                            }
                        }
                        
                        if let pos = item.part_of_speech {
                            Text(pos)
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                        
                        Text(item.timestamp, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom)
                    
                    if let meaningEn = item.meaning_en {
                        DetailSection(icon: "book.closed.fill", title: "DEFINITION (EN)", color: .blue) {
                            Text(meaningEn)
                                .font(.body)
                                .lineSpacing(6)
                        }
                    }
                    
                    if let translation = item.translation {
                        DetailSection(icon: "globe", title: "TRANSLATION", color: .red) {
                            Text(translation)
                                .font(.body)
                                .lineSpacing(6)
                        }
                    }
                    
                    if let nuance = item.nuance {
                        DetailSection(icon: "lightbulb.max.fill", title: "NUANCE", color: .yellow) {
                            Text(nuance)
                                .font(.body)
                                .italic()
                        }
                    }
                    
                    if let examples = item.examples, !examples.isEmpty {
                        DetailSection(icon: "quote.opening", title: "EXAMPLES", color: .green) {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(examples, id: \.self) { example in
                                    HStack(alignment: .top, spacing: 12) {
                                        Capsule()
                                            .fill(Color.green.opacity(0.5))
                                            .frame(width: 3)
                                            .padding(.vertical, 2)
                                        Text(example)
                                            .italic()
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    if let family = item.word_family, !family.isEmpty {
                        DetailSection(icon: "person.3.sequence.fill", title: "WORD FAMILY", color: .orange) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(family, id: \.self) { word in
                                    HStack {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 6))
                                            .foregroundStyle(.orange.opacity(0.5))
                                        Text(word)
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                        }
                    }
                    
                    if let colls = item.collocations, !colls.isEmpty {
                        DetailSection(icon: "link", title: "COLLOCATIONS", color: .purple) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(colls, id: \.self) { coll in
                                    HStack {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 6))
                                            .foregroundStyle(.purple.opacity(0.5))
                                        Text(coll)
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                        }
                    }
                    
                    if let extra = item.extra_content {
                         DetailSection(icon: "doc.text", title: "NOTES", color: .gray) {
                            Text(extra)
                        }
                    }
                    
                    // Delete button at bottom
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete Word")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 20)
                }
                .padding(24)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Word", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    modelContext.delete(item)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete '\(item.word ?? item.query)'?")
            }
        }
    }
}

struct DetailSection<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .padding(8)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
            
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    VocabulraryView()
        .modelContainer(for: Item.self, inMemory: true)
}
