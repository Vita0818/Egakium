#!/bin/zsh

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
project_root="$(cd "$script_dir/.." && pwd -P)"
intatis_root="$(cd "$project_root/../../Intatis" && pwd -P)"

fail() {
    print -u2 -- "error: $*"
    exit 1
}

require_text() {
    local file="$1"
    local text="$2"
    /usr/bin/grep -Fq -- "$text" "$file" \
        || fail "$file is missing required text: $text"
}

[[ "$intatis_root" == "/Users/vita/Vitemis/Intatis" ]] \
    || fail "../../Intatis resolved to unexpected root: $intatis_root"
[[ -f "$intatis_root/Package.swift" ]] \
    || fail "Intatis Package.swift is unavailable"

require_text "$project_root/Package.swift" '.package(path: "../../Intatis")'
require_text "$project_root/Package.swift" 'name: "IntatisCodexRuntime"'
require_text "$project_root/Package.swift" 'name: "EgakiumCanvas"'
require_text "$project_root/project.yml" 'path: ../../Intatis'
require_text "$project_root/project.yml" 'product: IntatisCodexRuntime'
require_text "$project_root/project.yml" 'product: EgakiumCanvas'
require_text "$project_root/project.yml" 'PRODUCT_BUNDLE_IDENTIFIER: com.Vita0818.EgakiumMac'
require_text "$project_root/Apps/EgakiumMac/Sources/AppConfig.swift" '"Egakium", isDirectory: true'
require_text "$project_root/Apps/EgakiumMac/Sources/AppConfig.swift" '"EGAKIUM_CONFIG"'
require_text "$project_root/Apps/egakium-cli/Sources/CLIConfig.swift" '"EGAKIUM_MODEL"'
require_text "$project_root/Apps/EgakiumMac/Sources/EgakiumMacApp.swift" \
    'IntatisHostApplication.configure(name: "Egakium")'
require_text "$project_root/Apps/EgakiumiOS/Sources/EgakiumiOSApp.swift" \
    'IntatisHostApplication.configure(name: "Egakium")'
require_text "$project_root/Apps/egakium-cli/Sources/EgakiumCLI.swift" \
    'IntatisHostApplication.configure(name: "Egakium")'
require_text "$project_root/Apps/EgakiumMac/Sources/CodeViewModel.swift" \
    'CodexAppServerSession'
require_text "$project_root/Apps/EgakiumMac/Sources/CoworkViewModel.swift" \
    'CodexAppServerSession'
require_text "$project_root/Apps/egakium-cli/Sources/Interactive.swift" \
    'codexRuntimeREPL'
require_text "$project_root/Apps/EgakiumMac/Sources/EgakiumMacApp.swift" \
    'EgakiumCEFInitialize()'
require_text "$project_root/Apps/EgakiumMac/Sources/EgakiumMacApp.swift" \
    'CoworkCanvasHost('
require_text "$project_root/scripts/package-macos-release.sh" \
    'sign_codex_runtime'
require_text "$project_root/scripts/package-macos-release.sh" \
    'validate_signed_codex_runtime'

if /usr/bin/grep -Fq '.package(path: "Vendor/' "$project_root/Package.swift"; then
    fail "Package.swift still selects a local vendored runtime dependency"
fi
if /usr/bin/grep -Eq 'library\(name: "Egakium(Core|Protocol|Providers|AgentKernel|Cowork|Tools|MCP|Skills|Knowledge)' \
    "$project_root/Package.swift"; then
    fail "Package.swift still publishes a copied Egakium runtime product"
fi

legacy_source_markers=(
    "$project_root/Packages/EgakiumCore/Sources/IDs.swift"
    "$project_root/Packages/EgakiumAgentKernel/Sources/AgentLoop.swift"
    "$project_root/Packages/EgakiumCowork/Sources/Orchestrator.swift"
    "$project_root/Packages/EgakiumTools/Sources/ToolProtocol.swift"
    "$project_root/Vendor/MCPClientSDK/Package.swift"
    "$project_root/Vendor/SwiftStreamingMarkdown/Package.swift"
    "$project_root/ThirdPartyStandards/OpenKnowledgeFormat/0.2/SPEC.md"
    "$project_root/Tests/MCPBM25ParityOracle/Cargo.toml"
    "$project_root/Tests/MCPConformance/official/run-official.sh"
)
for legacy_source in $legacy_source_markers; do
    [[ ! -e "$legacy_source" && ! -L "$legacy_source" ]] \
        || fail "copied snapshot source is still present: $legacy_source"
done

if /usr/bin/grep -R -E '^import Egakium(Core|Protocol|Providers|Artifacts|Conversation|Tools|Knowledge|Skills|Permission|MCP|MCPStdio|AgentKernel|Cowork|Multimodal|SharedUI)$' \
    "$project_root/Apps/EgakiumMac/Sources" \
    "$project_root/Apps/EgakiumiOS/Sources" \
    "$project_root/Apps/egakium-cli/Sources"; then
    fail "active product source still imports a copied Egakium implementation module"
fi

require_text "$project_root/Apps/EgakiumMac/Sources/CodeViewModel.swift" \
    '_ = try await runtime.runTurn('
require_text "$project_root/Apps/EgakiumMac/Sources/CoworkViewModel.swift" \
    'runtime = try await self.codexSession('
require_text "$project_root/Apps/egakium-cli/Sources/Interactive.swift" \
    'case .code, .cowork:'

require_text "$project_root/Apps/EgakiumMac/Sources/EgakiumMacRootView.swift" \
    'Text("Egakium")'
require_text "$project_root/Apps/EgakiumMac/Sources/EgakiumMacRootView.swift" \
    '[.cowork]'
require_text "$project_root/Apps/egakium-cli/Sources/Commands.swift" \
    'Egakium CLI'

if /usr/bin/grep -R -E '"(Intatis|Message Intatis|Open Intatis Config)' \
    "$project_root/Apps/EgakiumMac/Sources" \
    "$project_root/Apps/EgakiumiOS/Sources" \
    "$project_root/Apps/egakium-cli/Sources"; then
    fail "active product source contains a user-visible Intatis brand literal"
fi

print -- "Egakium integration is consistent: product overlay -> $intatis_root"
