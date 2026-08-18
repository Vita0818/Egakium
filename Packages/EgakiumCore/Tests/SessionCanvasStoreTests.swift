import XCTest
@testable import EgakiumCore

final class SessionCanvasStoreTests: XCTestCase {
    func testEnsureCreatesOneEditableCanvasAndPreservesMainEdits() throws {
        let workspace = try temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let session = SessionID(rawValue: "cowork_canvas_one")

        let created = try SessionCanvasStore.ensureCanvas(
            in: workspace,
            sessionID: session)

        XCTAssertTrue(created.wasCreated)
        XCTAssertEqual(
            created.relativeIndexPath,
            ".egakium/canvas/cowork_canvas_one/index.html")
        let initial = try String(contentsOf: created.indexURL, encoding: .utf8)
        XCTAssertTrue(initial.contains("<main id=\"canvas\""))
        XCTAssertTrue(initial.contains("data-egakium-session=\"cowork_canvas_one\""))
        XCTAssertTrue(initial.contains("data-egakium-canvas-contract=\"1\""))
        XCTAssertTrue(initial.contains("class=\"egakium-canvas-empty-state\""))
        XCTAssertTrue(initial.contains("class=\"egakium-element\""))
        XCTAssertTrue(initial.contains("data-element-id=\"element-001\""))
        XCTAssertTrue(initial.contains("data-x=\"64\" data-y=\"64\""))
        XCTAssertTrue(initial.contains("data-width=\"420\" data-height=\"300\""))
        XCTAssertTrue(initial.contains(
            "src=\"elements/element-001/index.html\""))
        XCTAssertTrue(initial.contains("sandbox=\"allow-scripts\""))
        XCTAssertTrue(initial.contains("frame-src 'self' data: blob:"))

        let edited = "<!doctype html><html><body><section>main edit</section></body></html>"
        try Data(edited.utf8).write(to: created.indexURL, options: .atomic)

        let restored = try SessionCanvasStore.ensureCanvas(
            in: workspace,
            sessionID: session)

        XCTAssertFalse(restored.wasCreated)
        XCTAssertEqual(
            try String(contentsOf: restored.indexURL, encoding: .utf8),
            edited)
    }

    func testCanvasTemplateIsSourceOwnedAndHasNoInjectedRuntime() {
        let template = SessionCanvasStore.defaultHTML(
            sessionID: SessionID(rawValue: "cef_source_contract"))

        XCTAssertEqual(SessionCanvasStore.canvasContractVersion, 1)
        XCTAssertTrue(template.contains("left: attr(data-x px, 64px)"))
        XCTAssertTrue(template.contains("top: attr(data-y px, 64px)"))
        XCTAssertTrue(template.contains("width: attr(data-width px, 420px)"))
        XCTAssertTrue(template.contains("height: attr(data-height px, 300px)"))
        XCTAssertTrue(template.contains("CEF renders these source-owned cards"))
        XCTAssertFalse(template.contains("SessionCanvasRuntime"))
        XCTAssertFalse(template.contains("sessionStorage"))
        XCTAssertFalse(template.contains("MutationObserver"))
        XCTAssertFalse(template.contains("egakium:canvas-layout-change"))
    }

    func testGenericElementTemplateIsOneIdentityFreeContentDocument() {
        let template = SessionCanvasStore.defaultElementHTML()

        XCTAssertEqual(
            template,
            SessionCanvasElementTemplate.html)
        XCTAssertEqual(SessionCanvasElementTemplate.templateVersion, 1)
        XCTAssertTrue(template.contains(
            "data-egakium-element-template=\"1\""))
        XCTAssertTrue(template.contains(
            "data-egakium-element-document=\"1\""))
        XCTAssertTrue(template.contains("<main id=\"element\""))
        XCTAssertTrue(template.contains("<section id=\"content\""))
        XCTAssertTrue(template.contains("connect-src 'none'"))
        XCTAssertTrue(template.contains("frame-src 'none'"))
        XCTAssertTrue(template.contains(
            "CEF renders this document directly"))
        XCTAssertFalse(template.contains("data-element-id"))
        XCTAssertFalse(template.contains(".egakium/canvas/"))
        XCTAssertFalse(template.contains("AgentID"))
        XCTAssertFalse(template.contains("SessionID"))
        XCTAssertFalse(template.contains("http://"))
        XCTAssertFalse(template.contains("https://"))
    }

    func testProvisionCreatesFreshRealElementWithoutCreatingSharedIndex() throws {
        let workspace = try temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let session = SessionID(rawValue: "cowork_element_seed")
        let elementID = CanvasElementID(rawValue: "element_seed_001")

        let document = try SessionCanvasStore.provisionElementTemplate(
            in: workspace,
            sessionID: session,
            elementID: elementID)

        XCTAssertEqual(document.sessionID, session)
        XCTAssertEqual(document.descriptor.elementID, elementID)
        XCTAssertEqual(document.descriptor.schemaVersion, 1)
        XCTAssertEqual(document.descriptor.templateVersion, 1)
        XCTAssertEqual(
            document.descriptor.relativeIndexPath,
            ".egakium/canvas/cowork_element_seed/elements/element_seed_001/index.html")
        XCTAssertEqual(
            try String(contentsOf: document.indexURL, encoding: .utf8),
            SessionCanvasElementTemplate.html)
        XCTAssertFalse(FileManager.default.fileExists(atPath:
            workspace.appendingPathComponent(
                ".egakium/canvas/cowork_element_seed/index.html").path))
        let lookedUp = try XCTUnwrap(SessionCanvasStore.existingElement(
            in: workspace,
            sessionID: session,
            descriptor: document.descriptor))
        XCTAssertEqual(lookedUp, document)
        XCTAssertThrowsError(
            try SessionCanvasStore.rollbackProvisionedElement(lookedUp)
        ) { error in
            XCTAssertEqual(
                error as? SessionCanvasStoreError,
                .elementRollbackRefused(document.directoryURL.path))
        }

        XCTAssertThrowsError(try SessionCanvasStore.provisionElementTemplate(
            in: workspace,
            sessionID: session,
            elementID: elementID)) { error in
                guard case SessionCanvasStoreError.elementAlreadyExists = error else {
                    return XCTFail("unexpected error: \(error)")
                }
            }
        XCTAssertEqual(
            try String(contentsOf: document.indexURL, encoding: .utf8),
            SessionCanvasElementTemplate.html)
    }

    func testProvisionRollbackRemovesOnlyUnchangedElementDirectory() throws {
        let workspace = try temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let document = try SessionCanvasStore.provisionElementTemplate(
            in: workspace,
            sessionID: SessionID(rawValue: "cowork_element_rollback"),
            elementID: CanvasElementID(rawValue: "element_rollback_001"))

        try SessionCanvasStore.rollbackProvisionedElement(document)

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: document.directoryURL.path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: document.directoryURL.deletingLastPathComponent().path))
    }

    func testProvisionRollbackRefusesEditedElementAndPreservesIt() throws {
        let workspace = try temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let document = try SessionCanvasStore.provisionElementTemplate(
            in: workspace,
            sessionID: SessionID(rawValue: "cowork_element_changed"),
            elementID: CanvasElementID(rawValue: "element_changed_001"))
        let edited = "<!doctype html><html><body>worker progress</body></html>"
        try Data(edited.utf8).write(to: document.indexURL, options: .atomic)

        XCTAssertThrowsError(
            try SessionCanvasStore.rollbackProvisionedElement(document)
        ) { error in
            XCTAssertEqual(
                error as? SessionCanvasStoreError,
                .elementRollbackRefused(document.directoryURL.path))
        }
        XCTAssertEqual(
            try String(contentsOf: document.indexURL, encoding: .utf8),
            edited)
        XCTAssertEqual(
            try SessionCanvasStore.existingElement(
                in: workspace,
                sessionID: document.sessionID,
                descriptor: document.descriptor),
            document)
    }

    func testUnsafeElementIdentifierIsRejectedBeforeWriting() throws {
        let workspace = try temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        XCTAssertThrowsError(try SessionCanvasStore.provisionElementTemplate(
            in: workspace,
            sessionID: SessionID(rawValue: "cowork_element_invalid"),
            elementID: CanvasElementID(rawValue: "../escape"))) { error in
                XCTAssertEqual(
                    error as? SessionCanvasStoreError,
                    .invalidElementID)
            }
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: workspace.appendingPathComponent(".egakium").path))
    }

    func testSessionsInSameWorkspaceUseDifferentCanvasIndexes() throws {
        let workspace = try temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let first = try SessionCanvasStore.ensureCanvas(
            in: workspace,
            sessionID: SessionID(rawValue: "cowork_first"))
        let second = try SessionCanvasStore.ensureCanvas(
            in: workspace,
            sessionID: SessionID(rawValue: "cowork_second"))

        XCTAssertNotEqual(first.indexURL, second.indexURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.indexURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.indexURL.path))
    }

    func testUnsafeSessionIdentifierIsRejectedBeforeWriting() throws {
        let workspace = try temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        XCTAssertThrowsError(try SessionCanvasStore.ensureCanvas(
            in: workspace,
            sessionID: SessionID(rawValue: "../escape"))) { error in
                XCTAssertEqual(error as? SessionCanvasStoreError, .invalidSessionID)
            }
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: workspace.appendingPathComponent(".egakium").path))
    }

    func testExistingCanvasLookupNeverCreatesMissingCanvas() throws {
        let workspace = try temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let existing = try SessionCanvasStore.existingCanvas(
            in: workspace,
            sessionID: SessionID(rawValue: "cowork_not_started"))

        XCTAssertNil(existing)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: workspace.appendingPathComponent(".egakium").path))
    }

    func testConcurrentInitializationPublishesOneCompleteIndex() async throws {
        let workspace = try temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let session = SessionID(rawValue: "cowork_concurrent")

        let documents = try await withThrowingTaskGroup(
            of: SessionCanvasDocument.self
        ) { group in
            for _ in 0..<12 {
                group.addTask {
                    try SessionCanvasStore.ensureCanvas(
                        in: workspace,
                        sessionID: session)
                }
            }
            var values: [SessionCanvasDocument] = []
            for try await document in group {
                values.append(document)
            }
            return values
        }

        XCTAssertEqual(documents.filter(\.wasCreated).count, 1)
        XCTAssertEqual(Set(documents.map(\.indexURL)).count, 1)
        let html = try String(
            contentsOf: try XCTUnwrap(documents.first).indexURL,
            encoding: .utf8)
        XCTAssertTrue(html.hasPrefix("<!doctype html>"))
        XCTAssertTrue(html.contains("data-egakium-session=\"cowork_concurrent\""))
    }

    func testCanvasDirectorySymlinkIsRejected() throws {
        let workspace = try temporaryWorkspace()
        let outside = try temporaryWorkspace()
        defer {
            try? FileManager.default.removeItem(at: workspace)
            try? FileManager.default.removeItem(at: outside)
        }
        try FileManager.default.createSymbolicLink(
            at: workspace.appendingPathComponent(".egakium"),
            withDestinationURL: outside)

        XCTAssertThrowsError(try SessionCanvasStore.ensureCanvas(
            in: workspace,
            sessionID: SessionID(rawValue: "cowork_symlink")))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: outside.appendingPathComponent("canvas").path))
    }

    private func temporaryWorkspace() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("session-canvas-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: false)
        return url
    }
}
