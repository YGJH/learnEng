import SwiftUI
import SwiftData
import Foundation

struct VocabulraryView: View {
    @Query private var items: [Item]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedItem: Item?
    @State private var searchText = ""
    
    /// NOTE:
    /// SwiftData's `Query(sort:)` can sometimes resolve to a Foundation `SortDescriptor` overload
    /// that requires `NSObject`. To keep this robust, we fetch without sort here and do a stable
    /// in-memory sort (favorites first, then newest).
    
    var filteredItems: [Item] {
        let base = items
            .sorted {
                if $0.isFavorite != $1.isFavorite {
                    return $0.isFavorite && !$1.isFavorite
                }
                return $0.timestamp > $1.timestamp
            }

        if searchText.isEmpty {
            return base
        }

        return base.filter { item in
            (item.word ?? item.query).localizedCaseInsensitiveContains(searchText) ||
            (item.translation ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Vocabulary Yet",
                        systemImage: "book.closed",
                        description: Text("Words you save from chat will appear here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Search Bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Search words...", text: $searchText)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.horizontal)
                            .padding(.top)
                            
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                VocabularyCard(item: item, index: index, onDelete: {
                                    deleteItem(item)
                                }, onToggleFavorite: {
                                    toggleFavorite(item)
                                })
                                .onTapGesture {
                                    selectedItem = item
                                }
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
    
    private func toggleFavorite(_ item: Item) {
        withAnimation {
            item.isFavorite.toggle()
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
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void
    @State private var isVisible = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(item.word ?? item.query)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(item.isFavorite ? .orange : .primary)
                        
                        Button(action: onToggleFavorite) {
                            Image(systemName: item.isFavorite ? "star.fill" : "star")
                                .font(.system(size: 16))
                                .foregroundStyle(item.isFavorite ? .orange : .secondary)
                                .padding(8)
                                .background(item.isFavorite ? Color.orange.opacity(0.1) : Color.secondary.opacity(0.1))
                                .clipShape(Circle())
                        }
                        Button(action: {
                            SpeechSynthesizer.shared.speak(item.word ?? item.query)
                        }) {
                            Image(systemName: "speaker.wave.2.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue.opacity(0.8))
                        }
                    

                    }
                    
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

                }
                
                Spacer()
                
                HStack(spacing: 8) {

                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundStyle(.red.opacity(0.8))
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.2))
            
            VStack(alignment: .leading, spacing: 12) {
                if let meaningEn = item.meaning_en {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "book.closed")
                            .foregroundStyle(.blue)
                            .font(.caption)
                            .padding(.top, 2)
                            .frame(width: 20)
                        
                        Text(meaningEn)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                if let translation = item.translation {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "globe")
                            .foregroundStyle(.red)
                            .font(.caption)
                            .padding(.top, 2)
                            .frame(width: 20)
                        
                        Text(translation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                if let examples = item.examples, let firstExample = examples.first {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "quote.opening")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .padding(.top, 2)
                            .frame(width: 20)
                        
                        Text(firstExample)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .lineLimit(2)
                    }
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
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: item.isFavorite ? Color.orange.opacity(0.15) : Color.black.opacity(0.05), radius: 15, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(item.isFavorite ? Color.orange.opacity(0.3) : Color.white.opacity(0.5), lineWidth: 1)
                )
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
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
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
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(item.word ?? item.query)
                                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                Button {
                                    SpeechSynthesizer.shared.speak(item.word ?? item.query)
                                } label: {
                                    Image(systemName: "speaker.wave.2.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.blue)
                                        .shadow(color: .blue.opacity(0.3), radius: 8)
                                }
                            }
                            
                            HStack {
                                if let pos = item.part_of_speech {
                                    Text(pos)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue)
                                        .clipShape(Capsule())
                                }
                                
                                if let ipa = item.ipa {
                                    Text(ipa)
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                        .monospaced()
                                }
                            }
                            
                            Text("Added on \(item.timestamp.formatted(date: .long, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        
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
                                VStack(alignment: .leading, spacing: 16) {
                                    ForEach(examples, id: \.self) { example in
                                        HStack(alignment: .top, spacing: 12) {
                                            Capsule()
                                                .fill(Color.green.opacity(0.5))
                                                .frame(width: 4)
                                                .padding(.vertical, 2)
                                            Text(example)
                                                .italic()
                                                .foregroundStyle(.secondary)
                                                .lineSpacing(4)
                                        }
                                    }
                                }
                            }
                        }
                        
                        if let family = item.word_family, !family.isEmpty {
                            DetailSection(icon: "person.3.sequence.fill", title: "WORD FAMILY", color: .orange) {
                                FlowLayout(spacing: 8) {
                                    ForEach(family, id: \.self) { word in
                                        Text(word)
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.orange.opacity(0.1))
                                            .foregroundStyle(.orange)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        
                        if let colls = item.collocations, !colls.isEmpty {
                            DetailSection(icon: "link", title: "COLLOCATIONS", color: .purple) {
                                FlowLayout(spacing: 8) {
                                    ForEach(colls, id: \.self) { coll in
                                        Text(coll)
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.purple.opacity(0.1))
                                            .foregroundStyle(.purple)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        
                        if let extra = item.extra_content {
                             DetailSection(icon: "doc.text", title: "NOTES", color: .gray) {
                                Text(extra)
                                    .lineSpacing(4)
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
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
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
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(color)
                    .clipShape(Circle())
                    .shadow(color: color.opacity(0.3), radius: 4)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
            
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

// FlowLayout 
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.last?.maxY ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        for row in rows {
            for element in row.elements {
                element.subview.place(at: CGPoint(x: bounds.minX + element.x, y: bounds.minY + element.y), proposal: proposal)
            }
        }
    }
    
    struct Row {
        var elements: [Element] = []
        var maxY: CGFloat = 0
    }
    
    struct Element {
        var subview: LayoutSubview
        var x: CGFloat
        var y: CGFloat
    }
    
    func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var currentRowElements: [Element] = []
        
        let maxWidth = proposal.width ?? 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth {
                // New row
                rows.append(Row(elements: currentRowElements, maxY: currentY + currentRowHeight))
                currentY += currentRowHeight + spacing
                currentX = 0
                currentRowHeight = 0
                currentRowElements = []
            }
            
            currentRowElements.append(Element(subview: subview, x: currentX, y: currentY))
            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
        
        if !currentRowElements.isEmpty {
            rows.append(Row(elements: currentRowElements, maxY: currentY + currentRowHeight))
        }
        
        return rows
    }
}

#Preview {
    VocabulraryView()
        .modelContainer(for: Item.self, inMemory: true)
}
