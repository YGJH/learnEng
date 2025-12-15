import Foundation

struct NewsResponse: Codable {
    let count: Int
    let category: String
    let articles: [NewsArticle]
}

struct NewsArticle: Codable, Identifiable {
    let title: String
    let link: String
    let summary: String
    let source: String
    let published_at: String
    let category: String
    
    var id: String { link }
    
    var publishedDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: published_at)
    }
    
    var formattedDate: String {
        guard let date = publishedDate else { return published_at }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
