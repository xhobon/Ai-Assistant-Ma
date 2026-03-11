import Foundation
import Combine

struct WebSearchResult: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let snippet: String
    let url: String
}

final class WebSearchModeStore: ObservableObject {
    static let shared = WebSearchModeStore()
    private let key = "web_search_enabled"

    @Published var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            UserDefaults.standard.set(isEnabled, forKey: key)
        }
    }

    private init() {
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(true, forKey: key)
        }
        isEnabled = UserDefaults.standard.bool(forKey: key)
    }
}

final class WebSearchService {
    static let shared = WebSearchService()
    private init() {}

    private let triggerKeywords: [String] = [
        "today", "latest", "current", "news", "weather", "price", "recent", "update",
        "hari ini", "terbaru", "sekarang", "berita", "cuaca", "harga",
        "今天", "最新", "当前", "新闻", "天气", "价格", "最近", "更新"
    ]

    func shouldSearch(for query: String) -> Bool {
        guard WebSearchModeStore.shared.isEnabled else { return false }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lower = trimmed.lowercased()
        if hasExplicitSearchIntent(lower) { return true }
        return triggerKeywords.contains(where: { lower.contains($0) })
    }

    func search(query: String) async throws -> [WebSearchResult] {
        let escaped = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://api.duckduckgo.com/?q=\(escaped)&format=json&no_redirect=1&no_html=1") else {
            return []
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(DuckDuckGoResponse.self, from: data)
        return parseResults(from: response)
    }

    func buildContext(from results: [WebSearchResult]) -> String {
        guard !results.isEmpty else { return "" }
        let lines = results.prefix(5).map { item in
            "- \(item.title): \(item.snippet) (\(item.url))"
        }
        return "Search context (web):\n" + lines.joined(separator: "\n")
    }

    private func parseResults(from response: DuckDuckGoResponse) -> [WebSearchResult] {
        var results: [WebSearchResult] = []
        if let abstract = response.AbstractText, !abstract.isEmpty {
            results.append(
                WebSearchResult(
                    id: UUID().uuidString,
                    title: response.Heading ?? "Summary",
                    snippet: abstract,
                    url: response.AbstractURL ?? ""
                )
            )
        }
        if let related = response.RelatedTopics {
            for topic in related {
                if let text = topic.Text, let url = topic.FirstURL {
                    let title = text.split(separator: "-").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? text
                    results.append(WebSearchResult(id: UUID().uuidString, title: title, snippet: text, url: url))
                } else if let nested = topic.Topics {
                    for inner in nested {
                        if let text = inner.Text, let url = inner.FirstURL {
                            let title = text.split(separator: "-").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? text
                            results.append(WebSearchResult(id: UUID().uuidString, title: title, snippet: text, url: url))
                        }
                    }
                }
            }
        }
        return results
    }

    private func hasExplicitSearchIntent(_ lower: String) -> Bool {
        let prefixes = ["search:", "web:", "/search", "搜索:", "搜索：", "联网:", "联网："]
        if prefixes.contains(where: { lower.hasPrefix($0) }) { return true }
        if lower.hasPrefix("搜索") || lower.hasPrefix("查") || lower.hasPrefix("联网") { return true }
        let phrases = ["帮我搜索", "请搜索", "搜索一下", "帮我查", "查一下", "查下", "联网搜索", "上网搜索"]
        if phrases.contains(where: { lower.contains($0) }) { return true }
        return false
    }
}

private struct DuckDuckGoResponse: Decodable {
    let Heading: String?
    let AbstractText: String?
    let AbstractURL: String?
    let RelatedTopics: [DuckDuckGoTopic]?
}

private struct DuckDuckGoTopic: Decodable {
    let Text: String?
    let FirstURL: String?
    let Topics: [DuckDuckGoTopic]?
}
