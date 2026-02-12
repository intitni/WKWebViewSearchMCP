import Foundation
import Testing

@testable import WKWebViewSearch

@Suite("Headless Browser Search Service Tests")
struct HeadlessBrowserSearchServiceTests {
    @Test
    func search_on_google() async throws {
        let search = HeadlessBrowserSearchService(engine: .google)
        let result = try await search.search(query: "Snoopy")
        #expect(result.webPages.isEmpty == false)
    }

    @Test
    func search_on_baidu() async throws {
        let search = HeadlessBrowserSearchService(engine: .baidu)
        let result = try await search.search(query: "Snoopy")
        #expect(result.webPages.isEmpty == false)
    }

    @Test
    func search_on_duckDuckGo() async throws {
        let search = HeadlessBrowserSearchService(engine: .duckDuckGo)
        let result = try await search.search(query: "Snoopy")
        #expect(result.webPages.isEmpty == false)
    }

    @Test
    func search_on_bing() async throws {
        let search = HeadlessBrowserSearchService(engine: .bing)
        let result = try await search.search(query: "Snoopy")
        #expect(result.webPages.isEmpty == false)
    }
}
