import ArgumentParser
import Foundation
import Logging
import MCP
import ServiceLifecycle
import WKWebViewSearch

@main
struct WKWebSearch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "CLI for WKWebViewSearch operations",
        subcommands: [Search.self, Scrap.self, MCPServer.self],
        defaultSubcommand: Search.self
    )

    struct Search: AsyncParsableCommand {
        static let configuration =
            CommandConfiguration(abstract: "Search a query using a headless web engine")

        @Option(
            name: [.customLong("engine")],
            help: "Search engine to use (google, baidu, bing, duckduckgo). Can also be set via SEARCH_ENGINE env var."
        )
        var engine: WebSearchEngine?

        @Argument(help: "Query to search for")
        var query: String

        func run() async throws {
            let webEngine = engine ?? ProcessInfo.processInfo
                .environment["SEARCH_ENGINE"].flatMap { WebSearchEngine(rawValue: $0) } ?? .google

            let service = WebSearchService(engine: webEngine)

            let result = try await service.search(query: query)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            if let data = try? encoder.encode(result.webPages), let s = String(
                data: data,
                encoding: .utf8
            ) {
                print(s)
                return
            }

            // Fallback to simple printing
            for p in result.webPages {
                print("- \(p.title)\n  \(p.urlString)\n  \(p.snippet)\n")
            }
        }
    }

    struct Scrap: AsyncParsableCommand {
        static let configuration =
            CommandConfiguration(abstract: "Scrap the HTML content of a web page")
        @Argument(help: "URL to crawl")
        var urlString: String

        func run() async throws {
            guard let url = URL(string: urlString) else {
                throw ValidationError("Invalid URL: \(urlString)")
            }
            let html = try await WebLoader(url: url).load()
            print(html)
        }
    }

    struct MCPServer: AsyncParsableCommand {
        static let configuration =
            CommandConfiguration(
                abstract: "Start an MCP server over stdio exposing search and crawl tools"
            )

        @Option(
            name: [.customLong("engine")],
            help: "Default search engine for the server (can be overridden per-call). Also configurable via SEARCH_ENGINE env var."
        )
        var engine: WebSearchEngine?

        func run() async throws {
            let defaultEngine = engine ?? ProcessInfo.processInfo
                .environment["SEARCH_ENGINE"].flatMap { WebSearchEngine(rawValue: $0) } ?? .google
            let logger = Logger(label: "com.intii.wkwebviewsearch.mcp")

            let server = Server(
                name: "WKWebViewSearchMCP",
                version: "1.0.0",
                capabilities: .init(
                    tools: .init(listChanged: true)
                )
            )

            await server.withMethodHandler(Ping.self) { _ in
                Empty()
            }

            // Register handlers on the server before starting
            await server.withMethodHandler(ListTools.self) { _ in
                let tools = [
                    Tool(
                        name: "web_search",
                        description: "Search a query and return structured results (title, URL, snippet)",
                        inputSchema: .object([
                            "type": .string("object"),
                            "properties": .object([
                                "query": .object([
                                    "type": .string("string"),
                                    "description": "The search query",
                                ]),
                            ]),
                            "required": ["query"],
                        ])
                    ),
                    Tool(
                        name: "read_web_page",
                        description: "Fetch HTML content for a given URL",
                        inputSchema: .object([
                            "type": .string("object"),
                            "properties": .object([
                                "url": .object([
                                    "type": .string("string"),
                                    "description": "URL to read",
                                ]),
                            ]),
                            "required": ["url"],
                        ])
                    ),
                ]
                return .init(tools: tools)
            }

            await server.withMethodHandler(CallTool.self) { params in
                switch params.name {
                case "web_search":
                    let query = params.arguments?["query"]?.stringValue ?? ""
                    let service = WebSearchService(engine: defaultEngine)
                    do {
                        let result = try await service.search(query: query)
                        struct Result: Codable {
                            var description: String
                            var query: String
                            var webPages: [WebSearchResult.WebPage]
                        }
                        let wrapper = Result(
                            description: "Found \(result.webPages.count) results for query '\(query)'",
                            query: query,
                            webPages: result.webPages
                        )
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                        let data = try encoder.encode(wrapper)
                        let s = String(data: data, encoding: .utf8) ?? ""
                        return .init(content: [.text(s)], isError: false)
                    } catch {
                        return .init(content: [.text("Search error: \(error)")], isError: true)
                    }

                case "read_web_page":
                    let urlString = params.arguments?["url"]?.stringValue ?? ""
                    guard let url = URL(string: urlString) else {
                        return .init(content: [.text("Invalid URL: \(urlString)")], isError: true)
                    }
                    do {
                        let content = try await WebLoader(url: url).load()
                        struct Result: Codable {
                            var description: String
                            var webPages: [WebLoader.Result]
                        }

                        let result = Result(
                            description: "Scraped web page of \(urlString)",
                            webPages: content
                        )
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                        let data = try encoder.encode(result)
                        let s = String(data: data, encoding: .utf8) ?? ""
                        return .init(content: [.text(s)], isError: false)
                    } catch {
                        return .init(content: [.text("Scrap error: \(error)")], isError: true)
                    }

                default:
                    return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
                }
            }

            let transport = StdioTransport(logger: logger)
            let mcpService = MCPService(server: server, transport: transport, logger: logger)

            let serviceGroup = ServiceGroup(
                services: [mcpService],
                gracefulShutdownSignals: [.sigterm, .sigint],
                cancellationSignals: [],
                logger: logger
            )

            try await serviceGroup.run()
        }
    }
}

extension WebSearchEngine: @retroactive _SendableMetatype {}
extension WebSearchEngine: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        self.init(rawValue: argument.lowercased())
    }
}

// MARK: - MCP Service

struct MCPService: Service {
    let server: Server
    let transport: Transport
    let logger: Logger

    init(server: Server, transport: Transport, logger: Logger) {
        self.server = server
        self.transport = transport
        self.logger = logger
    }

    func run() async throws {
        logger.info("Starting MCP server")
        try await server.start(transport: transport)
        // Run effectively forever until cancelled by ServiceGroup
        try await Task.sleep(nanoseconds: 365 * 24 * 60 * 60 * 1_000_000_000)
    }

    func shutdown() async throws {
        logger.info("Stopping MCP server")
        await server.stop()
    }
}

