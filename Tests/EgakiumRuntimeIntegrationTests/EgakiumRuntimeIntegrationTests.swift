import Foundation
import XCTest
import IntatisCore
import IntatisProtocol
import IntatisProviders
import IntatisCodexRuntime

final class EgakiumRuntimeIntegrationTests: XCTestCase {
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
