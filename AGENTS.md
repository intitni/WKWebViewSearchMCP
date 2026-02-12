# Repository Guidelines

This document is a short contributor guide for WKWebViewSearchMCP. It explains the repository layout, build/test commands, coding conventions, testing rules, and PR expectations.

## Project Structure & Module Organization

- `CLI/` — Swift package for the command-line tool. Entry point: `CLI/Sources/WKWebSearch/CLI.swift`.
- `WKWebViewSearch/` — Core Swift package with search services and headless WKWebView components (e.g., `HeadlessBrowserSearchService.swift`, `WebLoader.swift`).
- `WKWebViewSearch/Tests/` — Unit tests for the library.
- Root `README.md` — Usage and build notes.

## Build, Test, and Development Commands

- Build library: `swift build -C WKWebViewSearch`
- Build CLI: `swift build -C CLI`
- Run CLI: `swift run -C CLI WKWebSearch <subcommand>`
- Run tests: `swift test -C WKWebViewSearch`

Each `-C` runs the Swift tools from the package directory.

## Coding Style & Naming Conventions

- Language: Swift. Use 4-space indentation.
- Types: `PascalCase`. Properties/methods: `camelCase`.
- Prefer `let` for constants; `@State private var` for SwiftUI state if added.
- Avoid force-unwrapping; prefer optionals and safe unwrapping.
- Async/await is preferred over Combine for asynchronous code.

Examples:
- `HeadlessBrowserSearchService.swift` (type name)
- `loadContentStrategy` (property name)

## Testing Guidelines

- Tests use Swift's `Testing` framework. Tests live in `WKWebViewSearch/Tests/`.
- Naming: `<UnitUnderTest>Tests.swift` (example: `HeadlessBrowserSearchServiceTests.swift`).
- Run tests with `swift test -C WKWebViewSearch`.

## Commit & Pull Request Guidelines

- Commit messages: short subject line, optional body. Example: `Add WebLoader HTML caching`.
- PRs should include: purpose summary, linked issue (if any), short testing notes, and screenshots when UI changes are involved.
- Keep changes focused to the feature/bug; split large work into multiple PRs.

## Architecture Notes & Configuration Tips

- The project provides a headless WKWebView search service and a CLI wrapper. Configuration (search engine) can be set via `--engine` or `SEARCH_ENGINE` env var.
- macOS/Xcode required to build and run the headless WebKit components.

If you have questions or need to change guidelines, propose edits in a PR against this file.

