#if os(macOS)
import Foundation
import XCTest
import EgakiumArtifacts
import EgakiumCore
import EgakiumProviders
@testable import EgakiumSharedUI

final class ComposerAttachmentTests: XCTestCase {
    func testSharedAttachmentFlowReadsPreservesAndResolvesImage() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "egakium-composer-attachments-\(UUID().uuidString)",
                isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true)
        let sourceURL = root.appendingPathComponent("reference.png")
        let bytes = try XCTUnwrap(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))
        try bytes.write(to: sourceURL)

        let file = try EgakiumComposerAttachmentFileReader.read(sourceURL)
        XCTAssertEqual(file.name, "reference.png")
        XCTAssertEqual(file.mime, "image/png")
        XCTAssertEqual(file.data, bytes)

        let jpegURL = root.appendingPathComponent("reference.JpEg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: jpegURL)
        XCTAssertEqual(
            try EgakiumComposerAttachmentFileReader.read(jpegURL).mime,
            "image/jpeg")

        let artifactStore = try ArtifactStore(
            root: root.appendingPathComponent("artifacts", isDirectory: true))
        let attachmentStore = EgakiumComposerAttachmentStore(store: artifactStore)
        let draft = try await attachmentStore.preserve(file)

        XCTAssertEqual(draft.name, "reference.png")
        XCTAssertEqual(draft.mime, "image/png")
        let preservedBytes = try await artifactStore.data(for: draft.id)
        XCTAssertEqual(preservedBytes, bytes)
        let images = try await attachmentStore.imageAttachments(
            for: [draft.id],
            surface: "Chat")
        XCTAssertEqual(
            images,
            [.base64(
                mime: "image/png",
                base64: bytes.base64EncodedString())])
    }

    func testSharedAttachmentFlowPreservesNonImageButRejectsProviderInput() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "egakium-composer-non-image-\(UUID().uuidString)",
                isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let artifactStore = try ArtifactStore(root: root)
        let attachmentStore = EgakiumComposerAttachmentStore(store: artifactStore)
        let draft = try await attachmentStore.preserve(
            EgakiumComposerAttachmentFile(
                name: "notes.txt",
                data: Data("notes".utf8),
                mime: "text/plain"))

        do {
            _ = try await attachmentStore.imageAttachments(
                for: [draft.id],
                surface: "Chat")
            XCTFail("expected unsupported attachment error")
        } catch let error as EgakiumComposerAttachmentResolutionError {
            XCTAssertEqual(error.code, "attachment_type_unsupported")
            XCTAssertFalse(error.retryable)
            XCTAssertTrue(error.localizedDescription.contains("Chat"))
        }

        let preservedBytes = try await artifactStore.data(for: draft.id)
        XCTAssertEqual(preservedBytes, Data("notes".utf8))
    }
}
#endif
