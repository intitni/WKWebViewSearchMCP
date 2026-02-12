# WKWebViewSearchMCP

A web search MCP server using a headless WKWebView.

This repo contains two packages:

- `CLI` — A command-line tool that exposes search and crawling operations and can run an MCP server over stdio.
- `WKWebViewSearch` — Core library and services that perform web searches and fetch page HTML using a headless WebKit engine.

## Build

Requirements:

- macOS with Xcode and the Swift toolchain installed.
- Xcode command line tools (for `swift build` and `swift run`).

To build the CLI using Swift Package Manager:

```sh
swift build --package-path CLI -c release --product wk-web-search
```

To run the CLI directly from the workspace:

```sh
swift run --package-path CLI wk-web-search <subcommand> [options]
```

## Commands

The CLI exposes three subcommands.

- `mcp-server` — Start an MCP server that exposes `web_search` and `read_web_page` tools over stdio.

  Usage:

  ```sh
  wk-web-search mcp-server
  ```

  Options:

  - `--engine <engine>` — Choose search engine: `google`, `baidu`, `bing`, `duckduckgo`. Default: `google`.
  - Or set `SEARCH_ENGINE` environment variable to a value above.

- `search` — Perform a web search using a headless web engine.

  Usage:

  ```sh
  wk-web-search search "your query here"
  ```

  Options:

  - `--engine <engine>` — Choose search engine.
  - Or set `SEARCH_ENGINE` environment variable to a value above.

- `crawl` — Fetch the HTML of a web page.

  Usage:

  ```sh
  wk-web-search crawl "https://example.com"
  ```

