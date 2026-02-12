import Foundation
import SwiftSoup

public protocol LoadWebPageMainContentStrategy: Sendable {
    /// Load the web content into several documents.
    func load(_ document: SwiftSoup.Document) throws -> String
    /// Validate if the web page is fully loaded.
    func validate(_ document: SwiftSoup.Document) -> Bool
}

public extension LoadWebPageMainContentStrategy {
    func html(inFirstTag tagName: String, from document: SwiftSoup.Document) -> String? {
        if let tag = try? document.getElementsByTag(tagName).first(),
           let html = try? tag.html()
        {
            return html
        }
        return nil
    }

    func html(
        inFirstElementWithClass className: String,
        from document: SwiftSoup.Document
    ) -> String? {
        if let div = try? document.getElementsByClass(className).first(),
           let html = try? div.html()
        {
            return html
        }
        return nil
    }

    func html(inFirstElementWithId id: String, from document: SwiftSoup.Document) -> String? {
        if let element = try? document.getElementById(id),
           let html = try? element.html()
        {
            return html
        }
        return nil
    }
}

extension WebLoader {
    struct DefaultLoadContentStrategy: LoadWebPageMainContentStrategy {
        func load(_ document: SwiftSoup.Document) throws -> String {
            if let mainContent = try? {
                if let article = html(inFirstTag: "article", from: document) { return article }
                if let article = html(inFirstElementWithId: "main-content", from: document) {
                    return article
                }
                if let article = html(inFirstElementWithClass: "page-body", from: document) {
                    return article
                }
                if let main = html(inFirstTag: "main", from: document) { return main }
                let body = try document.body()?.text()
                return body
            }() {
                return mainContent
            }
            return (try? document.html()) ?? ""
        }

        func validate(_: SwiftSoup.Document) -> Bool {
            return true
        }
    }
}

