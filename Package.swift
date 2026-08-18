// swift-tools-version:5.9
import PackageDescription

// Egakium root SwiftPM manifest. Product versioning is owned by project.yml;
// package comments below that mention early v0.x milestones describe when a
// subsystem was introduced, not the current product version. See
// docs/VERSIONING.md.

let package = Package(
    name: "Egakium",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0"),
    ],
    products: [
        .library(name: "EgakiumCore", targets: ["EgakiumCore"]),
        .library(name: "EgakiumProtocol", targets: ["EgakiumProtocol"]),
        .library(name: "EgakiumProviders", targets: ["EgakiumProviders"]),
        .library(name: "EgakiumArtifacts", targets: ["EgakiumArtifacts"]),
        .library(name: "EgakiumConversation", targets: ["EgakiumConversation"]),
        .library(name: "EgakiumTools", targets: ["EgakiumTools"]),
        .library(name: "EgakiumKnowledge", targets: ["EgakiumKnowledge"]),
        .library(name: "EgakiumSkills", targets: ["EgakiumSkills"]),
        .library(name: "EgakiumPermission", targets: ["EgakiumPermission"]),
        .library(name: "EgakiumMCP", targets: ["EgakiumMCP"]),
        .library(name: "EgakiumMCPStdio", targets: ["EgakiumMCPStdio"]),
        .library(name: "EgakiumAgentKernel", targets: ["EgakiumAgentKernel"]),
        .library(name: "EgakiumCowork", targets: ["EgakiumCowork"]),
        .library(name: "EgakiumMultimodal", targets: ["EgakiumMultimodal"]),
        .library(name: "EgakiumSharedUI", targets: ["EgakiumSharedUI"]),
        // The CLI IS a SwiftPM executable (no Xcode needed): `swift run egakium chat`.
        .executable(name: "egakium", targets: ["EgakiumCLI"]),
        // The GUI apps (EgakiumMac, EgakiumiOS) are Xcode App targets, not SPM
        // products — SwiftPM cannot build a .app bundle, and iOS apps cannot be
        // built from SPM at all. See project.yml (XcodeGen) + README.
    ],
    dependencies: [
        // Audited in-tree thin derivative of Microsoft SwiftStreamingMarkdown
        // v0.6.0. Provenance and local patches live beside the vendored source.
        .package(path: "Vendor/SwiftStreamingMarkdown"),
        // Audited client-only derivative of the official Model Context
        // Protocol Swift SDK 0.12.1 at a0ae212e. Its upstream identity,
        // exclusions, licenses, and patch ledger live beside the source.
        .package(path: "Vendor/MCPClientSDK"),
        // Official portable CryptoKit-compatible backend for Linux CLI builds.
        // Exact release provenance and license inventory are recorded in
        // ThirdPartyNotices/SwiftCrypto.md.
        .package(
            url: "https://github.com/apple/swift-crypto.git",
            exact: "4.5.1"
        ),
        // Safe YAML parser for bounded OKF frontmatter in the non-iOS
        // knowledge target. Exact commit/license provenance is recorded in
        // ThirdPartyNotices/KnowledgeRetrieval.md.
        .package(
            url: "https://github.com/jpsim/Yams.git",
            exact: "6.2.2"
        ),
    ],
    targets: [
        // MARK: Library targets (module == target)
        .target(
            name: "EgakiumCore",
            path: "Packages/EgakiumCore/Sources"
        ),
        .target(
            name: "EgakiumProtocol",
            dependencies: ["EgakiumCore"],
            path: "Packages/EgakiumProtocol/Sources"
        ),
        .target(
            name: "EgakiumProviders",
            dependencies: [
                "EgakiumCore", "EgakiumProtocol",
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Packages/EgakiumProviders/Sources"
        ),
        .target(
            name: "EgakiumArtifacts",
            dependencies: ["EgakiumCore", "EgakiumProtocol"],
            path: "Packages/EgakiumArtifacts/Sources"
        ),
        .target(
            name: "EgakiumConversation",
            // ChatLoop drives a ChatProvider, so Conversation depends on Providers
            // (still tool-free — see ARCHITECTURE.md §3.4 / §4: iOS links this, not the kernel).
            dependencies: ["EgakiumCore", "EgakiumProtocol", "EgakiumProviders", "EgakiumArtifacts"],
            path: "Packages/EgakiumConversation/Sources"
        ),
        // v0.2 — Code: tools, deterministic permission gate, single-agent kernel.
        .target(
            name: "EgakiumPTYLauncher",
            path: "Packages/EgakiumPTYLauncher",
            publicHeadersPath: "include"
        ),
        .target(
            name: "EgakiumTools",
            dependencies: [
                "EgakiumCore", "EgakiumProtocol", "EgakiumPTYLauncher",
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Packages/EgakiumTools/Sources"
        ),
        // OKF/Profile snapshots, deterministic validation, local embedding,
        // derived indexes, and the snapshot-bound search_knowledge tool.
        // No iOS app target links this product.
        .target(
            name: "EgakiumKnowledge",
            dependencies: [
                "EgakiumCore", "EgakiumProtocol", "EgakiumTools",
                "EgakiumProviders", "EgakiumPermission",
                .product(name: "Yams", package: "Yams"),
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Packages/EgakiumKnowledge",
            exclude: ["Tests"],
            sources: ["Sources"],
            resources: [
                .copy("Resources/Schemas"),
            ]
        ),
        .target(
            name: "EgakiumSkills",
            dependencies: [
                "EgakiumCore", "EgakiumProtocol", "EgakiumTools",
                "EgakiumPermission",
            ],
            path: "Packages/EgakiumSkills",
            exclude: ["Tests"],
            sources: ["Sources"],
            resources: [
                .copy("Resources/BundledSkills"),
            ]
        ),
        .target(
            name: "EgakiumPermission",
            // Providers added in v0.3 for the model-backed reviewer (layer B).
            dependencies: ["EgakiumCore", "EgakiumProtocol", "EgakiumProviders"],
            path: "Packages/EgakiumPermission/Sources"
        ),
        // Production remote MCP HTTP/OAuth requests use libcurl's
        // CURLOPT_RESOLVE socket binding on macOS and Linux. The iOS product
        // does not link EgakiumMCP.
        .target(
            name: "EgakiumCurlTransport",
            path: "Packages/EgakiumCurlTransport",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("curl"),
            ]
        ),
        // External MCP Server client core, including the client-side handlers
        // for callbacks initiated by a connected server. This target contains
        // no MCP Server implementation or server-facing product seam. It has
        // no dependency on Conversation, Providers, AgentKernel, Cowork, or an
        // app target; those layers inject event/artifact/inference services
        // through narrow interfaces.
        .target(
            name: "EgakiumMCP",
            dependencies: [
                "EgakiumCore", "EgakiumProtocol", "EgakiumTools",
                .target(
                    name: "EgakiumCurlTransport",
                    condition: .when(platforms: [.macOS, .linux])
                ),
                .product(name: "MCP", package: "MCPClientSDK"),
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Packages/EgakiumMCP/Sources"
        ),
        // Linux-only kernel execution guard support for local MCP stdio.
        // The C shim is inert on Apple platforms; keeping it separate avoids
        // placing fork/ptrace/seccomp code in the portable client core.
        .target(
            name: "EgakiumMCPStdioGuard",
            path: "Packages/EgakiumMCPStdio/ExecutionGuard",
            publicHeadersPath: "include"
        ),
        // Local stdio process ownership is a separate linkage boundary so the
        // App Store target can remain remote-HTTP-only.
        .target(
            name: "EgakiumMCPStdio",
            dependencies: [
                "EgakiumMCP", "EgakiumMCPStdioGuard",
                "EgakiumCore", "EgakiumProtocol", "EgakiumTools",
                .product(name: "MCP", package: "MCPClientSDK"),
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Packages/EgakiumMCPStdio/Sources"
        ),
        .target(
            name: "EgakiumAgentKernel",
            dependencies: [
                "EgakiumCore", "EgakiumProtocol", "EgakiumProviders",
                "EgakiumTools", "EgakiumPermission", "EgakiumConversation",
                "EgakiumArtifacts", "EgakiumMCP", "EgakiumSkills",
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Packages/EgakiumAgentKernel/Sources"
        ),
        // v0.3 — Cowork: multi-agent orchestration over a mediated message bus.
        .target(
            name: "EgakiumCowork",
            dependencies: [
                "EgakiumCore", "EgakiumProtocol", "EgakiumProviders", "EgakiumTools",
                "EgakiumPermission", "EgakiumConversation", "EgakiumAgentKernel",
                "EgakiumSkills",
            ],
            path: "Packages/EgakiumCowork/Sources"
        ),
        // v0.4 — Multimodal: image/video generation + transcription → artifacts.
        .target(
            name: "EgakiumMultimodal",
            dependencies: [
                "EgakiumCore", "EgakiumProtocol", "EgakiumProviders",
                "EgakiumArtifacts", "EgakiumConversation",
            ],
            path: "Packages/EgakiumMultimodal/Sources"
        ),
        .target(
            name: "EgakiumSharedUI",
            // Providers is needed because ChatViewModel drives ProviderRegistry.
            dependencies: [
                "EgakiumCore", "EgakiumProtocol", "EgakiumProviders",
                "EgakiumConversation", "EgakiumArtifacts",
                .product(
                    name: "SwiftStreamingMarkdown",
                    package: "SwiftStreamingMarkdown",
                    condition: .when(platforms: [.macOS, .iOS])
                ),
            ],
            path: "Packages/EgakiumSharedUI/Sources"
        ),
        // v0.6 — CLI: Swift-native `egakium` command (chat + code agent), talks to
        // any OpenAI-compatible endpoint via env vars.
        .executableTarget(
            name: "EgakiumCLI",
            dependencies: [
                "EgakiumCore", "EgakiumProtocol", "EgakiumProviders", "EgakiumConversation",
                "EgakiumArtifacts", "EgakiumTools", "EgakiumPermission", "EgakiumAgentKernel", "EgakiumCowork",
                "EgakiumMCP", "EgakiumMCPStdio", "EgakiumSkills", "EgakiumKnowledge",
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Apps/egakium-cli/Sources"
        ),
        // Development-only executable exercised by the pinned official MCP
        // client conformance runner. It is not a shipped product and contains
        // no MCP server implementation or server-facing API.
        .executableTarget(
            name: "EgakiumMCPConformanceClient",
            dependencies: [
                "EgakiumMCP", "EgakiumCore", "EgakiumProtocol",
                .product(name: "MCP", package: "MCPClientSDK"),
            ],
            path: "Packages/EgakiumMCPConformanceClient/Sources"
        ),
        // GUI app targets (EgakiumMac macOS app, EgakiumiOS iOS app) are defined in
        // the Xcode project generated from project.yml — they link these library
        // products. The iOS app intentionally links only the subset.

        // MARK: Test targets (none depend on app targets; SharedUI tests run headlessly on macOS)
        .testTarget(
            name: "EgakiumCoreTests",
            dependencies: ["EgakiumCore"],
            path: "Packages/EgakiumCore/Tests"
        ),
        .testTarget(
            name: "EgakiumProtocolTests",
            dependencies: ["EgakiumProtocol", "EgakiumCore"],
            path: "Packages/EgakiumProtocol/Tests"
        ),
        .testTarget(
            name: "EgakiumProvidersTests",
            dependencies: ["EgakiumProviders", "EgakiumCore", "EgakiumProtocol"],
            path: "Packages/EgakiumProviders/Tests"
        ),
        .testTarget(
            name: "EgakiumArtifactsTests",
            dependencies: ["EgakiumArtifacts", "EgakiumCore"],
            path: "Packages/EgakiumArtifacts/Tests"
        ),
        .testTarget(
            name: "EgakiumConversationTests",
            dependencies: ["EgakiumConversation", "EgakiumCore", "EgakiumProtocol", "EgakiumProviders"],
            path: "Packages/EgakiumConversation/Tests"
        ),
        .testTarget(
            name: "EgakiumToolsTests",
            dependencies: ["EgakiumTools", "EgakiumCore"],
            path: "Packages/EgakiumTools/Tests"
        ),
        .testTarget(
            name: "EgakiumKnowledgeTests",
            dependencies: [
                "EgakiumKnowledge", "EgakiumCore", "EgakiumProtocol",
                "EgakiumTools",
            ],
            path: "Packages/EgakiumKnowledge/Tests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
        .testTarget(
            name: "EgakiumSkillsTests",
            dependencies: [
                "EgakiumSkills", "EgakiumCore", "EgakiumProtocol", "EgakiumTools",
            ],
            path: "Packages/EgakiumSkills/Tests"
        ),
        .testTarget(
            name: "EgakiumPermissionTests",
            dependencies: ["EgakiumPermission", "EgakiumCore", "EgakiumProtocol", "EgakiumProviders"],
            path: "Packages/EgakiumPermission/Tests"
        ),
        .testTarget(
            name: "EgakiumMCPTests",
            dependencies: [
                "EgakiumMCP", "EgakiumMCPStdio", "EgakiumCore",
                "EgakiumProtocol", "EgakiumTools",
                .product(name: "MCP", package: "MCPClientSDK"),
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Packages/EgakiumMCP/Tests"
        ),
        .testTarget(
            name: "EgakiumCLITests",
            dependencies: [
                "EgakiumCLI", "EgakiumAgentKernel",
                "EgakiumConversation", "EgakiumCore",
                "EgakiumMCP", "EgakiumProtocol",
            ],
            path: "Apps/egakium-cli/Tests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
        .testTarget(
            name: "EgakiumAgentKernelTests",
            dependencies: [
                "EgakiumAgentKernel", "EgakiumCore", "EgakiumProtocol", "EgakiumProviders",
                "EgakiumTools", "EgakiumPermission", "EgakiumConversation",
                "EgakiumArtifacts", "EgakiumMCP", "EgakiumSkills", "EgakiumKnowledge",
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Packages/EgakiumAgentKernel/Tests"
        ),
        .testTarget(
            name: "EgakiumCoworkTests",
            dependencies: [
                "EgakiumCowork", "EgakiumCore", "EgakiumProtocol", "EgakiumProviders",
                "EgakiumTools", "EgakiumPermission", "EgakiumConversation", "EgakiumAgentKernel",
                "EgakiumSkills",
            ],
            path: "Packages/EgakiumCowork/Tests"
        ),
        .testTarget(
            name: "EgakiumMultimodalTests",
            dependencies: [
                "EgakiumMultimodal", "EgakiumCore", "EgakiumProtocol", "EgakiumProviders",
                "EgakiumArtifacts", "EgakiumConversation",
            ],
            path: "Packages/EgakiumMultimodal/Tests"
        ),
        .testTarget(
            name: "EgakiumSharedUITests",
            dependencies: ["EgakiumSharedUI"],
            path: "Packages/EgakiumSharedUI/Tests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
