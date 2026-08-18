import Foundation
import EgakiumProviders

func printConfig(_ config: CLIConfig) {
    out("""
    endpoint : (configured, hidden) · \(config.selectedRouteLabel)
    model    : \(config.model)
    wire     : \(config.wire.rawValue)
    reasoning: \(config.reasoningEffort?.rawValue ?? "off")
    mode     : \(config.mode.rawValue)
    api key  : \(config.hasConfiguredCredential ? "(configured, hidden)" : "(unset)")
    routes   : \(config.providerRoutes.count)
    config   : \(config.configurationFileURL == nil ? ConfigFile.url.path : "(advanced Egakium config, path hidden)")

    """)
}

func printHelp() {
    out("""
    Egakium CLI — a local AI agent for ANY OpenAI-compatible endpoint.

    USAGE
      egakium                 Start your default mode (set via `egakium settings`)
      egakium chat            Streaming chat (no tools)
      egakium code [dir]      Coding agent: read/search/edit files, git/shell (with approval)
      egakium cowork [dir]    Multi-agent work; use /goal <objective> for durable Goal execution
      egakium settings        Interactive settings (endpoint, key, model, reasoning, mode)
      egakium config          Print the resolved config
      egakium selftest        Offline smoke test (no key)
      egakium mcp help        Manage external MCP servers and session access
      egakium exec --session <id> --agent <id> [--task <id>] --prompt <text> [--yes]
                              Run one exact durable Code/MCP turn
      egakium diagnose-hang --pid <pid> [--output <directory>]
                              Capture a 10s sample and 5m Egakium logs into an owner-only bundle
      egakium help

    CONFIG  (env var > advanced Egakium config > Egakium CLI settings > default)
      EGAKIUM_CONFIG     optional egakium.json/jsonc using model + enabled_providers + provider map
      EGAKIUM_BASE_URL   default https://api.openai.com/v1
      EGAKIUM_API_KEY    required (any non-empty for local servers)
      EGAKIUM_MODEL      default gpt-4o-mini
      EGAKIUM_REASONING  minimal | low | medium | high
      EGAKIUM_MODE       chat | code | cowork

    In a session, type /help for slash commands (/model, /reasoning, /mode, /clear …).

    FIRST RUN
      egakium settings        # set endpoint + API key once
      egakium                 # then just run it — uses your saved config

    ANY VENDOR (same binary)
      EGAKIUM_BASE_URL=http://localhost:11434/v1 EGAKIUM_API_KEY=ollama EGAKIUM_MODEL=llama3.1 egakium chat
      EGAKIUM_BASE_URL=https://api.deepseek.com/v1 EGAKIUM_API_KEY=sk-... EGAKIUM_MODEL=deepseek-chat egakium chat

    """)
}
