// swift-tools-version:5.9
import PackageDescription

// Egakium is a first-party product overlay on the single Intatis checkout.
// Shared runtime/core changes compile directly from ../../Intatis; this
// package owns only the Egakium product hosts and Canvas-specific resources.
let package = Package(
    name: "Egakium",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0"),
    ],
    products: [
        .library(name: "EgakiumCanvas", targets: ["EgakiumCanvas"]),
        .executable(name: "egakium", targets: ["EgakiumCLI"]),
    ],
    dependencies: [
        // Canonical shared implementation. This relative path intentionally
        // resolves to /Users/vita/Vitemis/Intatis from this repository.
        .package(path: "../../Intatis"),
    ],
    targets: [
        .target(
            name: "EgakiumCanvas",
            dependencies: [
                .product(name: "IntatisCore", package: "Intatis"),
            ],
            path: "Product/EgakiumCanvas",
            exclude: ["Tests"],
            sources: ["Sources"],
            resources: [
                .copy("Resources/BundledSkills"),
            ]
        ),
        .executableTarget(
            name: "EgakiumCLI",
            dependencies: [
                .product(name: "IntatisCore", package: "Intatis"),
                .product(name: "IntatisProtocol", package: "Intatis"),
                .product(name: "IntatisProviders", package: "Intatis"),
                .product(name: "IntatisConversation", package: "Intatis"),
                .product(name: "IntatisArtifacts", package: "Intatis"),
                .product(name: "IntatisTools", package: "Intatis"),
                .product(name: "IntatisKnowledge", package: "Intatis"),
                .product(name: "IntatisSkills", package: "Intatis"),
                .product(name: "IntatisPermission", package: "Intatis"),
                .product(name: "IntatisMCP", package: "Intatis"),
                .product(name: "IntatisMCPStdio", package: "Intatis"),
                .product(name: "IntatisAgentKernel", package: "Intatis"),
                .product(name: "IntatisCowork", package: "Intatis"),
                .product(name: "IntatisSharedUI", package: "Intatis"),
                .product(name: "IntatisCodexRuntime", package: "Intatis"),
            ],
            path: "Apps/egakium-cli/Sources"
        ),
        .testTarget(
            name: "EgakiumCLITests",
            dependencies: [
                "EgakiumCLI",
                .product(name: "IntatisCore", package: "Intatis"),
                .product(name: "IntatisProtocol", package: "Intatis"),
                .product(name: "IntatisProviders", package: "Intatis"),
                .product(name: "IntatisConversation", package: "Intatis"),
                .product(name: "IntatisArtifacts", package: "Intatis"),
                .product(name: "IntatisTools", package: "Intatis"),
                .product(name: "IntatisKnowledge", package: "Intatis"),
                .product(name: "IntatisSkills", package: "Intatis"),
                .product(name: "IntatisPermission", package: "Intatis"),
                .product(name: "IntatisMCP", package: "Intatis"),
                .product(name: "IntatisMCPStdio", package: "Intatis"),
                .product(name: "IntatisAgentKernel", package: "Intatis"),
                .product(name: "IntatisCowork", package: "Intatis"),
                .product(name: "IntatisSharedUI", package: "Intatis"),
                .product(name: "IntatisCodexRuntime", package: "Intatis"),
            ],
            path: "Apps/egakium-cli/Tests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
        .testTarget(
            name: "EgakiumCanvasTests",
            dependencies: [
                "EgakiumCanvas",
                .product(name: "IntatisCore", package: "Intatis"),
            ],
            path: "Product/EgakiumCanvas/Tests"
        ),
        .testTarget(
            name: "EgakiumRuntimeIntegrationTests",
            dependencies: [
                .product(name: "IntatisCore", package: "Intatis"),
                .product(name: "IntatisProtocol", package: "Intatis"),
                .product(name: "IntatisProviders", package: "Intatis"),
                .product(name: "IntatisCodexRuntime", package: "Intatis"),
            ],
            path: "Tests/EgakiumRuntimeIntegrationTests"
        ),
    ]
)
