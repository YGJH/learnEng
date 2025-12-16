import SwiftUI
import FoundationModels

struct NewsView: View {
    @State private var newsResponse: NewsResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedArticle: NewsArticle?
    @State private var session = LanguageModelSession()
    @State private var articlesWithAI: [NewsArticle] = []
    @State private var isGeneratingSummaries = false
    @State private var selectedCategory: String = "all"
    
    let categories = [
        ("all", "All News", "newspaper.fill"),
        ("general", "General", "globe"),
        ("technology", "Technology", "laptopcomputer"),
        ("business", "Business", "briefcase.fill"),
        ("world", "World", "globe.americas.fill")
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                                .frame(width: 60, height: 60)
                            
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.blue)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Loading Latest News")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("Fetching articles from sources...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Failed to Load News",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    .overlay(alignment: .bottom) {
                        Button("Retry") {
                            loadNews()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 40)
                    }
                } else if !articlesWithAI.isEmpty || isGeneratingSummaries {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Hero Header with Gradient
                            ZStack(alignment: .bottomLeading) {
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .frame(height: 180)
                                .clipShape(
                                    .rect(
                                        topLeadingRadius: 0,
                                        bottomLeadingRadius: 30,
                                        bottomTrailingRadius: 30,
                                        topTrailingRadius: 0
                                    )
                                )
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: isGeneratingSummaries ? "sparkles" : "checkmark.circle.fill")
                                            .font(.title2)
                                        Text(selectedCategory.capitalized)
                                            .font(.largeTitle)
                                            .fontWeight(.bold)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        if isGeneratingSummaries {
                                            Text("\(articlesWithAI.count) articles loading...")
                                                .font(.subheadline)
                                                .opacity(0.9)
                                        } else {
                                            Text("\(articlesWithAI.count) articles • AI Filtered")
                                                .font(.subheadline)
                                                .opacity(0.9)
                                        }
                                    }
                                }
                                .foregroundStyle(.white)
                                .padding(24)
                            }
                            
                            // Initial Loading State (when no articles yet)
                            if articlesWithAI.isEmpty && isGeneratingSummaries {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                        .padding(.top, 40)
                                    
                                    Text("Analyzing articles with AI...")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    if let response = newsResponse {
                                        Text("Processing \(response.count) articles")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            }
                            
                            // Featured Article (First one with larger card)
                            if let firstArticle = articlesWithAI.first {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("FEATURED")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 20)
                                    
                                    FeaturedNewsCard(article: firstArticle, onTap: {
                                        selectedArticle = firstArticle
                                    })
                                }
                            }
                            
                            // Other Articles
                            if articlesWithAI.count > 1 {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("LATEST NEWS")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 8)
                                    
                                    ForEach(articlesWithAI.dropFirst()) { article in
                                        NewsArticleCard(article: article, onTap: {
                                            selectedArticle = article
                                        }) 
                                    }
                                }
                            }
                            
                            // Processing Indicator (顯示在底部)
                            if isGeneratingSummaries, let response = newsResponse {
                                VStack(spacing: 16) {
                                    Divider()
                                        .padding(.horizontal, 20)
                                    
                                    HStack(spacing: 12) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "sparkles")
                                                    .font(.caption)
                                                    .foregroundStyle(.purple)
                                                Text("AI Processing News...")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                            }
                                            
                                            Text("\(articlesWithAI.count) / \(response.count) articles ready")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.purple.opacity(0.05))
                                    )
                                    .padding(.horizontal, 20)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                } else {
                    VStack(spacing: 32) {
                        Spacer()
                        
                        // Icon with gradient background
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "newspaper.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        VStack(spacing: 12) {
                            Text("Stay Informed")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Get the latest news from top sources")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        Button {
                            loadNews()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Load News")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // 頂部類別選擇條（放在導航欄中央）
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.0) { category in
                                CategoryChip(
                                    title: category.1,
                                    icon: category.2,
                                    isSelected: selectedCategory == category.0,
                                    action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedCategory = category.0
                                            loadNews()
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .fullScreenCover(item: $selectedArticle) { article in
                ArticleWebView(article: article)
            }
        }
    }
    
    func loadNews() {
        isLoading = true
        errorMessage = nil
        articlesWithAI = []
        
        Task {
            do {
                // 構建 URL，包含類別和數量參數
                var urlComponents = URLComponents(string: "https://raw.githubusercontent.com/YGJH/learnEng/refs/heads/main/exp/news.json")!
                urlComponents.queryItems = [
                    URLQueryItem(name: "category", value: selectedCategory),
                    URLQueryItem(name: "limit", value: "50")
                ]
                
                guard let url = urlComponents.url else {
                    throw URLError(.badURL)
                }
                
                print("📡 Fetching news from: \(url.absoluteString)")
                
                let (data, response) = try await URLSession.shared.data(from: url)
                
                // Check HTTP status
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 HTTP Status: \(httpResponse.statusCode)")
                    guard httpResponse.statusCode == 200 else {
                        throw URLError(.badServerResponse)
                    }
                }
                
                let decoder = JSONDecoder()
                let newsResponse = try decoder.decode(NewsResponse.self, from: data)
                
                await MainActor.run {
                    self.newsResponse = newsResponse
                    self.isLoading = false
                }
                
                // 自動生成 AI 摘要
                await generateAISummariesForArticles(newsResponse.articles)
                
            } catch {
                print("❌ Error loading news: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func generateAISummariesForArticles(_ articles: [NewsArticle]) async {
        await MainActor.run {
            isGeneratingSummaries = true
            articlesWithAI = [] // 開始時清空
        }
        
        print("🤖 Starting AI analysis and summary generation for \(articles.count) articles...")
        print("🔍 Filtering advertisements and generating summaries...")
        
        var processedCount = 0
        var validCount = 0
        var skippedCount = 0
        
        for (index, article) in articles.enumerated() {
            processedCount = index + 1
            
            // 更新進度（但不顯示文章）
            await MainActor.run {
                // 這裡可以更新進度條，但不更新 articlesWithAI
                print("� Progress: \(processedCount)/\(articles.count)")
            }
            
            do {
                print("📝 Analyzing article \(processedCount)/\(articles.count): \(article.title.prefix(50))...")
                
                // 為每篇文章創建新的 session 以避免 context 累積
                let freshSession = LanguageModelSession()
                
                // 使用新的分析函數（會過濾廣告）
                if let analysis = try await analyzeAndSummarizeNews(
                    title: article.title,
                    summary: article.summary,
                    session: freshSession
                ) {
                    // 不是廣告，立即顯示
                    var updatedArticle = article
                    updatedArticle.aiSummary = analysis.summary
                    
                    // 立即更新 UI
                    await MainActor.run {
                        self.articlesWithAI.append(updatedArticle)
                    }
                    
                    validCount += 1
                    print("✅ Valid article #\(validCount) displayed: \(article.title.prefix(50))...")
                } else {
                    skippedCount += 1
                    print("🚫 Advertisement filtered out: \(article.title.prefix(50))...")
                }
                
            } catch let error as NSError {
                let errorString = error.localizedDescription
                if errorString.contains("exceededContextWindowSize") || errorString.contains("4096") {
                    skippedCount += 1
                    print("⚠️ Article too long (>4096 tokens), skipping: \(article.title.prefix(50))...")
                } else if errorString.contains("context") || errorString.contains("Context") {
                    skippedCount += 1
                    print("⚠️ Context error, skipping: \(article.title.prefix(50))...")
                } else {
                    skippedCount += 1
                    print("❌ Error analyzing article \(processedCount): \(errorString)")
                }
                continue
            } catch {
                skippedCount += 1
                print("❌ Error analyzing article \(processedCount): \(error)")
                continue
            }
            
            // 每處理 5 篇打印進度
            if processedCount % 5 == 0 {
                print("📊 Progress: \(processedCount)/\(articles.count) processed | \(validCount) valid | \(skippedCount) skipped")
            }
        }
        
        // 處理完成
        await MainActor.run {
            self.isGeneratingSummaries = false
        }
        
        print("✅ AI analysis completed!")
        print("📊 Final Results:")
        print("   - Processed: \(articles.count) articles")
        print("   - Valid news: \(validCount) articles")
        print("   - Filtered/Skipped: \(skippedCount) articles")
    }
}

// Featured Article Card with Large Format
struct FeaturedNewsCard: View {
    let article: NewsArticle
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                // Category Badge
                HStack {
                    Text(article.category.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    
                    Spacer()
                    
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
                
                // Title
                Text(article.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                
                // AI Summary (所有顯示的文章都應該有 AI 摘要)
                if let aiSummary = article.aiSummary {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                            Text("AI Summary")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.purple)
                        }
                        
                        Text(aiSummary)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Divider()
                
                // Footer with more detail
                HStack(spacing: 12) {
                    // Source with icon
                    HStack(spacing: 6) {
                        Image(systemName: "building.2.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        Text(article.source)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    // Date with icon
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text(article.formattedDate)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                }
                
                // Read More Button
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Read Full Article")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}

// Regular Article Card with Compact Format
struct NewsArticleCard: View {
    let article: NewsArticle
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(alignment: .top, spacing: 16) {
                // Left color accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4)
                
                VStack(alignment: .leading, spacing: 10) {
                    // Title
                    Text(article.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    // AI Summary (所有顯示的文章都應該有 AI 摘要)
                    if let aiSummary = article.aiSummary {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                            Text(aiSummary)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    
                    // Footer
                    HStack(spacing: 8) {
                        // Source
                        Text(article.source)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                        
                        Text("•")
                            .foregroundStyle(.tertiary)
                        
                        // Date
                        Text(article.formattedDate)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        
                        Spacer()
                        
                        // Arrow indicator
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.trailing, 16)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}

// Category Chip Component
struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color(.secondarySystemBackground)
                    }
                }
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color(.separator), lineWidth: 1)
            )
            .shadow(color: isSelected ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NewsView()
}
