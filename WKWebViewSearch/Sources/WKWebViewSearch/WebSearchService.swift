import Foundation

public enum WebSearchEngine: String, Sendable {
    case google
    case baidu
    case bing
    case duckDuckGo = "duckduckgo"
}

public struct WebSearchResult: Codable, Equatable, Sendable {
    public struct WebPage: Codable, Equatable, Sendable {
        public var urlString: String
        public var title: String
        public var snippet: String
    }

    public var webPages: [WebPage]
}

public protocol SearchService: Sendable {
    func search(query: String) async throws -> WebSearchResult
}

public struct WebSearchService: Sendable {
    let service: SearchService

    init(service: SearchService) {
        self.service = service
    }

    public init(engine: WebSearchEngine) {
        service = HeadlessBrowserSearchService(engine: engine)
    }

    public func search(query: String) async throws -> WebSearchResult {
        return try await service.search(query: query)
    }
}

