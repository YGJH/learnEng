import SwiftUI

struct NewsView: View {
    @State private var newsResponse: NewsResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedArticle: NewsArticle?
    
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
                } else if let response = newsResponse {
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
                                        Image(systemName: "newspaper.fill")
                                            .font(.title2)
                                        Text(response.category.capitalized)
                                            .font(.largeTitle)
                                            .fontWeight(.bold)
                                    }
                                    
                                    Text("\(response.count) articles • Updated now")
                                        .font(.subheadline)
                                        .opacity(0.9)
                                }
                                .foregroundStyle(.white)
                                .padding(24)
                            }
                            
                            // Featured Article (First one with larger card)
                            if let firstArticle = response.articles.first {
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
                            if response.articles.count > 1 {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("LATEST NEWS")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 8)
                                    
                                    ForEach(response.articles.dropFirst()) { article in
                                        NewsArticleCard(article: article, onTap: {
                                            selectedArticle = article
                                        })
                                    }
                                }
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
            .navigationTitle("News")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        loadNews()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
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
        
        Task {
            do {
                guard let url = URL(string: "http://192.168.3.191:8000/news") else {
                    throw URLError(.badURL)
                }
                
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
            } catch {
                print("❌ Error loading news: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
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
                
                // Summary
                Text(article.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                
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
                    
                    // Summary
                    Text(article.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
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

#Preview {
    NewsView()
}
