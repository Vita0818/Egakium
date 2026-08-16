import XCTest
@testable import IntatisCore

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
