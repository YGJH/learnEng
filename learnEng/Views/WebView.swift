import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        print("WebView makeUIView called for: \(url.absoluteString)")
        
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // 確保在主線程上載入
        DispatchQueue.main.async {
            print("Starting to load URL: \(url.absoluteString)")
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            webView.load(request)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // 不要在 updateUIView 重複載入
        print("WebView updateUIView called (no action)")
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        var hasLoaded = false
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("⏳ WebView started loading")
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            hasLoaded = true
            print("✅ WebView finished loading: \(webView.url?.absoluteString ?? "unknown")")
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            print("📝 WebView committed navigation")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.code != NSURLErrorCancelled {
                print("❌ WebView navigation failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.code != NSURLErrorCancelled {
                print("❌ WebView provisional navigation failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}

struct ArticleWebView: View {
    let article: NewsArticle
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    
    init(article: NewsArticle) {
        self.article = article
        print("🎬 ArticleWebView init for: \(article.title)")
    }
    
    var body: some View {
        if let url = URL(string: article.link) {
            NavigationStack {
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    
                    WebView(url: url, isLoading: $isLoading)
                        .id(article.link) // 強制重建 WebView
                    
                    // Loading overlay
                    if isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.blue)
                            
                            Text("載入中...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.95))
                    }
                }
                .onAppear {
                    print("👁️ ArticleWebView appeared for: \(article.link)")
                }
                .navigationTitle(article.source)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Text("完成")
                                .fontWeight(.semibold)
                        }
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                UIApplication.shared.open(url)
                            } label: {
                                Label("在 Safari 開啟", systemImage: "safari")
                            }
                            
                            Button {
                                UIPasteboard.general.string = article.link
                            } label: {
                                Label("複製連結", systemImage: "doc.on.doc")
                            }
                            
                            ShareLink(item: url) {
                                Label("分享文章", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        } else {
            VStack(spacing: 20) {
                ContentUnavailableView(
                    "無法開啟連結",
                    systemImage: "link.badge.plus",
                    description: Text("這篇文章的網址無效")
                )
                
                Button("關閉") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        
    }
}
