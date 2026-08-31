import Foundation
import XCTest
import IntatisCore
import IntatisCoworkUI
import IntatisProtocol
import IntatisProviders
import IntatisCodexRuntime

final class EgakiumRuntimeIntegrationTests: XCTestCase {
    func testCanvasAutoRefreshUsesCompletedCodexFileChangeEvents()
        throws
    {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let macSources = repositoryRoot
            .appendingPathComponent(
                "Apps/EgakiumMac/Sources",
                isDirectory: true)
        let viewModel = try String(
            contentsOf: macSources
                .appendingPathComponent("CoworkViewModel.swift"),
            encoding: .utf8)
        let canvasHost = try String(
            contentsOf: macSources
                .appendingPathComponent("CoworkCanvasHost.swift"),
            encoding: .utf8)
        let app = try String(
            contentsOf: macSources
                .appendingPathComponent("EgakiumMacApp.swift"),
            encoding: .utf8)

        XCTAssertTrue(viewModel.contains(
            "@Published private(set) var canvasReloadRevision"))
        XCTAssertTrue(viewModel.contains(
            "item.kind == .fileChange"))
        XCTAssertTrue(viewModel.contains(
            "CanvasAutomaticReloadPolicy.shouldReload"))
        XCTAssertTrue(viewModel.contains(
            "canvasReloadRevision &+= 1"))
        XCTAssertTrue(canvasHost.contains(
            "automaticReloadRevision: UInt64"))
        XCTAssertTrue(canvasHost.contains(
            "automaticRevision:"))
        XCTAssertTrue(canvasHost.contains(
            "manualRevision:"))
        XCTAssertTrue(app.contains(
            "automaticReloadRevision:"))
        XCTAssertTrue(app.contains(
            "vm.canvasReloadRevision"))

        let refreshSources = viewModel + "\n" + canvasHost
        for forbidden in [
            "DispatchSource.makeFileSystemObjectSource",
            "Timer.publish",
            "attributesOfItem(atPath:",
        ] {
            XCTAssertFalse(
                refreshSources.contains(forbidden),
                "Canvas auto-refresh must not use filesystem polling or watching: \(forbidden)")
        }
    }

    func testConsumesThePublishedIntatisCoworkUIContractDirectly() {
        XCTAssertEqual(IntatisCoworkUIContract.publicAPIMajorVersion, 1)
        _ = IntatisCoworkContentView.self
        _ = IntatisCoworkContentState.self
        _ = IntatisCoworkContentActions.self
        _ = IntatisCoworkThreadSource.self
    }

    func testConsumesThePublishedIntatisRuntimeContractDirectly() {
        XCTAssertEqual(CodexRuntimeHostContract.publicAPIMajorVersion, 1)
        XCTAssertEqual(CodexRuntimeHostContract.packageName, "Intatis")
        XCTAssertEqual(
            CodexRuntimeHostContract.productName,
            "IntatisCodexRuntime")
        XCTAssertEqual(
            CodexRuntimeHostContract.pinnedRuntimeVersion,
            "0.145.0-intatis.4")
    }

    func testEgakiumCanConstructAnIsolatedRuntimeUsingOnlyPublicTypes() {
        let route = ResponsesRuntimeRoute(
            endpointID: "egakium-test",
            model: ModelID(rawValue: "fixture-model"),
            baseURL: URL(string: "https://example.invalid/v1")!,
            bearerToken: "fixture-token")
        let configuration = CodexRuntimeConfiguration(
            sessionID: SessionID(rawValue: "sess_egakium_fixture"),
            mode: .cowork,
            workspaceURL: URL(fileURLWithPath: "/tmp/egakium-workspace"),
            runtimeRootURL: URL(fileURLWithPath: "/tmp/egakium-runtime"),
            route: route,
            executableOverride: URL(fileURLWithPath: "/tmp/codex"))

        XCTAssertFalse(configuration.description.contains("fixture-token"))
        XCTAssertNotNil(CodexAppServerSession(configuration: configuration))
    }

    func testHostIdentityPreservesEgakiumNamespaces() throws {
        let identity = try IntatisHostApplicationIdentity(name: "Egakium")
        XCTAssertEqual(identity.storageName, "Egakium")
        XCTAssertEqual(identity.fileNameStem, "egakium")
        XCTAssertEqual(identity.environmentVariable("CONFIG"), "EGAKIUM_CONFIG")
        XCTAssertEqual(identity.hiddenWorkspaceDirectoryName, ".egakium")
        XCTAssertEqual(
            identity.authorizationContextFieldName,
            "__egakium_authorization_context")
    }
}
