import Foundation
import SwiftSoup
import WebKit

public struct WebLoader: Sendable {
    public struct Result: Codable, Sendable {
        public var title: String
        public var url: URL
        public var content: String
    }

    typealias Downloader = @Sendable (
        _ url: URL,
        _ strategy: LoadWebPageMainContentStrategy,
        _ timeout: TimeInterval
    ) async throws
        -> (url: URL, html: String, strategy: LoadWebPageMainContentStrategy)

    let downloadHTML: Downloader?

    public var urls: [URL]
    public var timeout: TimeInterval

    public init(urls: [URL], timeout: TimeInterval = 20) {
        self.urls = urls
        self.timeout = timeout
        downloadHTML = nil
    }

    public init(url: URL, timeout: TimeInterval = 20) {
        urls = [url]
        self.timeout = timeout
        downloadHTML = nil
    }

    init(urls: [URL], timeout: TimeInterval = 20, downloader: Downloader? = nil) {
        self.urls = urls
        self.timeout = timeout
        downloadHTML = downloader
    }

    public func load() async throws -> [Result] {
        enum Event: Sendable {
            case result((url: URL, html: String, strategy: LoadWebPageMainContentStrategy))
            case timeout
        }
        return try await withThrowingTaskGroup(of: Event.self) { group in
            for url in urls {
                let strategy: LoadWebPageMainContentStrategy = {
                    switch url {
                    default: return DefaultLoadContentStrategy()
                    }
                }()

                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(1_000_000_000 * timeout))
                    return .timeout
                }

                _ = group.addTaskUnlessCancelled {
                    let result = try await downloadHTML(url, strategy, timeout)
                    return .result(result)
                }
            }
            var documents: [Result] = []
            loop: for try await result in group {
                do {
                    switch result {
                    case let .result(result):
                        let (title, document) = try parseHTML(result.html, result.url)
                        let parsedDocument = try result.strategy.load(document)
                        documents.append(.init(
                            title: title,
                            url: result.url,
                            content: parsedDocument
                        ))
                        if documents.count == urls.count {
                            group.cancelAll()
                            break loop
                        }
                    case .timeout:
                        group.cancelAll()
                        break loop
                    }
                } catch let Exception.Error(_, message) {
                    print("SwiftSoup error: \(message)")
                } catch {
                    print("Unexpected error: \(error)")
                }
            }
            return documents
        }
    }

    func downloadHTML(
        _ url: URL,
        _ strategy: LoadWebPageMainContentStrategy,
        _ timeout: TimeInterval
    ) async throws
        -> (url: URL, html: String, strategy: LoadWebPageMainContentStrategy)
    {
        if let downloadHTML {
            return try await downloadHTML(url, strategy, timeout)
        }
        let html = try await WebCrawler().fetch(
            url: url,
            validate: strategy.validate(_:),
            timeout: timeout
        )
        return (url, html, strategy)
    }

    func parseHTML(
        _ html: String,
        _ url: URL
    ) throws -> (title: String, document: SwiftSoup.Document) {
        let parsed = try SwiftSoup.parse(html, url.path)
        let title = (try? parsed.title()) ?? "Untitled"
        let removeTags = [
            "script", "style", "noscript", "iframe", "frame",
            "meta", "link", "object", "embed", "canvas", "ins",
            "svg",
        ]
        for tag in removeTags {
            _ = try? parsed.getElementsByTag(tag).remove()
        }

        let classNameRemovingTags = [
            "header", "footer", "nav", "aside", "div",
            "h1", "h2", "h3", "h4", "h5", "h6", "p",
            "span", "section", "article", "main", "figure", "a",
            "button", "input", "textarea", "select", "label", "img", "video", "audio",
            "form", "table", "tr", "td", "th", "ul", "ol", "li", "pre", "code",
        ]

        for tag in classNameRemovingTags {
            guard let elements = try? parsed.getElementsByTag(tag) else { continue }
            for element in elements {
                _ = try? element.removeAttr("class")
                _ = try? element.removeAttr("style")
                _ = try? element.removeAttr("jsname")
                _ = try? element.removeAttr("jsaction")
                _ = try? element.removeAttr("jscontroller")
                _ = try? element.removeAttr("jsmodel")
            }
        }

        return (title, parsed)
    }
}

extension Task where Failure == Error {
    // Start a new Task with a timeout. If the timeout expires before the operation is
    // completed then the task is cancelled and an error is thrown.
    init(
        priority: TaskPriority? = nil,
        timeout: TimeInterval,
        operation: @escaping @Sendable () async throws -> Success
    ) {
        self = Task(priority: priority) {
            try await withThrowingTaskGroup(of: Success.self) { group -> Success in
                group.addTask(operation: operation)
                group.addTask {
                    try await _Concurrency.Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw TimeoutError()
                }
                guard let success = try await group.next() else {
                    throw _Concurrency.CancellationError()
                }
                group.cancelAll()
                return success
            }
        }
    }
}

private struct TimeoutError: LocalizedError {
    var errorDescription: String? = "Task timed out before completion"
}

