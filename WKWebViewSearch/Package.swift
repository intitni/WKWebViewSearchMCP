// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WKWebViewSearch",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "WKWebViewSearch",
            targets: ["WKWebViewSearch"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
    ],
    targets: [
        .target(
            name: "WKWebViewSearch",
            dependencies: [
                .product(name: "SwiftSoup", package: "SwiftSoup"),
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
        .testTarget(
            name: "WKWebViewSearchTests",
            dependencies: ["WKWebViewSearch"]
        ),
    ]
)

