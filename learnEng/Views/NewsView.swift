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
    
    @Namespace private var animation
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    LoadingView()
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
                        LazyVStack(spacing: 24) {
                            // Header Space
                            Color.clear.frame(height: 10)
                            
                            // Featured Article (First one)
                            if let firstArticle = articlesWithAI.first {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "star.fill")
                                            .foregroundStyle(.yellow)
                                        Text("FEATURED STORY")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.secondary)
                                            .tracking(1)
                                    }
                                    .padding(.horizontal, 20)
                                    
                                    FeaturedNewsCard(article: firstArticle) {
                                        selectedArticle = firstArticle
                                    }
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            
                            // Other Articles
                            if articlesWithAI.count > 1 {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Image(systemName: "clock.fill")
                                            .foregroundStyle(.blue)
                                        Text("LATEST UPDATES")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.secondary)
                                            .tracking(1)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                                    
                                    ForEach(Array(articlesWithAI.dropFirst().enumerated()), id: \.element.id) { index, article in
                                        NewsArticleCard(article: article, index: index) {
                                            selectedArticle = article
                                        }
                                    }
                                }
                            }
                            
                            // Loading Indicator at bottom
                            if isGeneratingSummaries {
                                HStack(spacing: 12) {
                                    ProgressView()
                                        .tint(.purple)
                                    Text("AI analyzing more articles...")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 20)
                                .frame(maxWidth: .infinity)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .refreshable {
                        loadNews()
                    }
                } else {
                    // Empty State / Initial State
                    VStack(spacing: 32) {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 160, height: 160)
                                .blur(radius: 20)
                            
                            Image(systemName: "newspaper")
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .scaleEffect(isLoading ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isLoading)
                        
                        VStack(spacing: 16) {
                            Text("Discover the World")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("AI-curated news summaries tailored for you.\nSelect a category to get started.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        Button {
                            loadNews()
                        } label: {
                            HStack(spacing: 12) {
                                Text("Start Reading")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                            }
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.0) { category in
                                CategoryChip(
                                    title: category.1,
                                    icon: category.2,
                                    isSelected: selectedCategory == category.0,
                                    namespace: animation,
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
                        .padding(.vertical, 4)
                    }
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

// MARK: - Subviews

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 60, height: 60)
                        .scaleEffect(isAnimating ? 1.5 : 0.5)
                        .opacity(isAnimating ? 0 : 1)
                        .animation(
                            .easeOut(duration: 2)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.4),
                            value: isAnimating
                        )
                }
                
                Image(systemName: "globe")
                    .font(.system(size: 30))
                    .foregroundStyle(.blue)
            }
            .onAppear { isAnimating = true }
            
            VStack(spacing: 8) {
                Text("Curating Your News")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text("AI is analyzing the latest stories...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeaturedNewsCard: View {
    let article: NewsArticle
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                // Badge & Date
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
                    
                    Text(article.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Title
                Text(article.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                
                // AI Summary
                if let aiSummary = article.aiSummary {
                    Text(aiSummary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Color.purple.opacity(0.5))
                                .frame(width: 3)
                        }
                }
                
                Divider()
                
                // Footer
                HStack {
                    Label(article.source, systemImage: "newspaper")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("Read Story")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
            .padding(.horizontal, 20)
        }
        .buttonStyle(NewsScaleButtonStyle())
    }
}

struct NewsArticleCard: View {
    let article: NewsArticle
    let index: Int
    let onTap: () -> Void
    @State private var isVisible = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Left Accent
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 4)
                    .frame(height: 60)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(article.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    if let aiSummary = article.aiSummary {
                        Text(aiSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Text(article.source)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(article.formattedDate)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 20)
            .offset(y: isVisible ? 0 : 50)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index % 10) * 0.1)) {
                    isVisible = true
                }
            }
        }
        .buttonStyle(NewsScaleButtonStyle())
    }
}

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var namespace: Namespace.ID
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
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .matchedGeometryEffect(id: "bg", in: namespace)
                    } else {
                        Capsule()
                            .fill(Color(.secondarySystemBackground))
                    }
                }
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .animation(.spring(), value: isSelected)
        }
        .buttonStyle(NewsScaleButtonStyle())
    }
}

struct NewsScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    NewsView()
}
