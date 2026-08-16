import Foundation

public enum SessionCanvasStoreError: Error, LocalizedError, Equatable {
    case invalidSessionID
    case unsafePath(String)
    case indexIsNotRegularFile(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSessionID:
            return "The session identifier cannot be used for a Canvas path."
        case .unsafePath(let path):
            return "The Canvas path is unsafe or is not a directory: \(path)"
        case .indexIsNotRegularFile(let path):
            return "The Canvas index is not a regular file: \(path)"
        }
    }
}

/// The workspace-local HTML entry point for one Cowork Session.
///
/// The host creates the file from a deterministic template, then exact
/// `@main` may edit it through the ordinary workspace tool chain. A SessionID
/// namespace prevents two Cowork sessions that use the same primary workspace
/// from overwriting each other's Canvas.
public struct SessionCanvasDocument: Equatable, Sendable {
    public let sessionID: SessionID
    public let workspaceRoot: URL
    public let relativeIndexPath: String
    public let wasCreated: Bool

    public init(
        sessionID: SessionID,
        workspaceRoot: URL,
        relativeIndexPath: String,
        wasCreated: Bool
    ) {
        self.sessionID = sessionID
        self.workspaceRoot = workspaceRoot
        self.relativeIndexPath = relativeIndexPath
        self.wasCreated = wasCreated
    }

    public var indexURL: URL {
        workspaceRoot.appendingPathComponent(relativeIndexPath)
    }

    public var directoryURL: URL {
        indexURL.deletingLastPathComponent()
    }
}

public enum SessionCanvasStore {
    public static let canvasRootRelativePath = ".egakium/canvas"

    public static func relativeDirectoryPath(
        for sessionID: SessionID
    ) throws -> String {
        let component = try validatedSessionComponent(sessionID)
        return "\(canvasRootRelativePath)/\(component)"
    }

    public static func relativeIndexPath(
        for sessionID: SessionID
    ) throws -> String {
        "\(try relativeDirectoryPath(for: sessionID))/index.html"
    }

    /// Idempotently creates the Session Canvas without replacing an existing
    /// file. Existing `@main` edits therefore survive restore and repeated host
    /// initialization.
    @discardableResult
    public static func ensureCanvas(
        in workspaceRoot: URL,
        sessionID: SessionID,
        fileManager: FileManager = .default
    ) throws -> SessionCanvasDocument {
        let canonicalRoot = try PathConfinement.canonicalExistingDirectory(
            workspaceRoot)
        let relativeDirectory = try relativeDirectoryPath(for: sessionID)
        let relativeIndex = try relativeIndexPath(for: sessionID)

        var current = canonicalRoot
        for component in relativeDirectory.split(separator: "/").map(String.init) {
            current.appendPathComponent(component, isDirectory: true)
            if fileManager.fileExists(atPath: current.path) {
                let values = try current.resourceValues(forKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey,
                ])
                guard values.isDirectory == true,
                      values.isSymbolicLink != true else {
                    throw SessionCanvasStoreError.unsafePath(current.path)
                }
            } else {
                do {
                    try fileManager.createDirectory(
                        at: current,
                        withIntermediateDirectories: false)
                } catch CocoaError.fileWriteFileExists {
                    // A concurrent initializer may have created this exact
                    // component after our existence check. Validate the
                    // winner below instead of treating the race as failure.
                }
                let values = try current.resourceValues(forKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey,
                ])
                guard values.isDirectory == true,
                      values.isSymbolicLink != true else {
                    throw SessionCanvasStoreError.unsafePath(current.path)
                }
            }
        }

        let confinedDirectory = try PathConfinement.resolve(
            relativeDirectory,
            within: canonicalRoot)
        guard confinedDirectory.standardizedFileURL
                == current.standardizedFileURL else {
            throw SessionCanvasStoreError.unsafePath(current.path)
        }

        let indexURL = try PathConfinement.resolve(
            relativeIndex,
            within: canonicalRoot)
        let created: Bool
        if fileManager.fileExists(atPath: indexURL.path) {
            try validateIndex(indexURL)
            created = false
        } else {
            let bytes = Data(defaultHTML(sessionID: sessionID).utf8)
            created = try publishInitialIndex(
                bytes,
                at: indexURL,
                fileManager: fileManager)
            try validateIndex(indexURL)
        }

        return SessionCanvasDocument(
            sessionID: sessionID,
            workspaceRoot: canonicalRoot,
            relativeIndexPath: relativeIndex,
            wasCreated: created)
    }

    /// Resolves an already initialized Session Canvas without creating any
    /// directory or file. Presentation surfaces use this API so opening or
    /// restoring a window cannot become Canvas lifecycle authority.
    public static func existingCanvas(
        in workspaceRoot: URL,
        sessionID: SessionID,
        fileManager: FileManager = .default
    ) throws -> SessionCanvasDocument? {
        let canonicalRoot = try PathConfinement.canonicalExistingDirectory(
            workspaceRoot)
        let relativeDirectory = try relativeDirectoryPath(for: sessionID)
        let relativeIndex = try relativeIndexPath(for: sessionID)

        var current = canonicalRoot
        for component in relativeDirectory.split(separator: "/").map(String.init) {
            current.appendPathComponent(component, isDirectory: true)
            guard fileManager.fileExists(atPath: current.path) else {
                return nil
            }
            let values = try current.resourceValues(forKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ])
            guard values.isDirectory == true,
                  values.isSymbolicLink != true else {
                throw SessionCanvasStoreError.unsafePath(current.path)
            }
        }

        let confinedDirectory = try PathConfinement.resolve(
            relativeDirectory,
            within: canonicalRoot)
        guard confinedDirectory.standardizedFileURL
                == current.standardizedFileURL else {
            throw SessionCanvasStoreError.unsafePath(current.path)
        }

        let indexURL = try PathConfinement.resolve(
            relativeIndex,
            within: canonicalRoot)
        guard fileManager.fileExists(atPath: indexURL.path) else {
            return nil
        }
        try validateIndex(indexURL)
        return SessionCanvasDocument(
            sessionID: sessionID,
            workspaceRoot: canonicalRoot,
            relativeIndexPath: relativeIndex,
            wasCreated: false)
    }

    public static func defaultHTML(sessionID: SessionID) -> String {
        let session = (try? validatedSessionComponent(sessionID)) ?? "invalid-session"
        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta http-equiv="Content-Security-Policy" content="default-src 'self' data: blob:; connect-src 'none'; img-src 'self' data: blob:; media-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; frame-src 'self' data: blob:; object-src 'none'; base-uri 'none'; form-action 'none'">
          <title>Ekagium Canvas</title>
          <style>
            :root {
              color-scheme: light dark;
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
              background: #f7f7f5;
            }

            * { box-sizing: border-box; }

            html, body {
              width: 100%;
              min-width: 100%;
              min-height: 100%;
              margin: 0;
            }

            body {
              min-height: 100vh;
              overflow: auto;
              background-color: #f7f7f5;
              background-image:
                linear-gradient(rgba(92, 92, 92, 0.08) 1px, transparent 1px),
                linear-gradient(90deg, rgba(92, 92, 92, 0.08) 1px, transparent 1px);
              background-size: 24px 24px;
            }

            #canvas {
              position: relative;
              width: 100%;
              min-width: 1200px;
              min-height: 900px;
              isolation: isolate;
            }

            /* exact @main may add nested elements or local iframe documents. */
            .egakium-element {
              position: absolute;
              overflow: hidden;
            }

            .egakium-element > iframe {
              width: 100%;
              height: 100%;
              border: 0;
            }

            @media (prefers-color-scheme: dark) {
              :root, body { background-color: #1d1d1f; }
              body {
                background-image:
                  linear-gradient(rgba(235, 235, 245, 0.09) 1px, transparent 1px),
                  linear-gradient(90deg, rgba(235, 235, 245, 0.09) 1px, transparent 1px);
              }
            }
          </style>
        </head>
        <body>
          <!-- Host-created once per Session. exact @main may directly edit this file. -->
          <main id="canvas" data-egakium-session="\(session)"></main>
        </body>
        </html>
        """
    }

    private static func validatedSessionComponent(
        _ sessionID: SessionID
    ) throws -> String {
        let value = sessionID.rawValue
        guard !value.isEmpty,
              value.count <= 128,
              value.unicodeScalars.allSatisfy({ scalar in
                  CharacterSet.alphanumerics.contains(scalar)
                      || scalar == "_"
                      || scalar == "-"
              }) else {
            throw SessionCanvasStoreError.invalidSessionID
        }
        return value
    }

    private static func validateIndex(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
        ])
        guard values.isRegularFile == true,
              values.isSymbolicLink != true else {
            throw SessionCanvasStoreError.indexIsNotRegularFile(url.path)
        }
    }

    /// Publishes complete bytes without ever replacing an existing index.
    ///
    /// Foundation rejects `.atomic` combined with `.withoutOverwriting` at
    /// runtime. Writing a unique atomic file in the destination directory and
    /// then linking it into place gives us both properties: the linked bytes
    /// are already complete, and the link operation fails when another host
    /// instance won the creation race.
    private static func publishInitialIndex(
        _ bytes: Data,
        at indexURL: URL,
        fileManager: FileManager
    ) throws -> Bool {
        let temporaryURL = indexURL.deletingLastPathComponent()
            .appendingPathComponent(".index-\(UUID().uuidString).tmp")
        defer { try? fileManager.removeItem(at: temporaryURL) }

        try bytes.write(to: temporaryURL, options: .atomic)
        try validateIndex(temporaryURL)

        do {
            try fileManager.linkItem(at: temporaryURL, to: indexURL)
            return true
        } catch CocoaError.fileWriteFileExists {
            // A second process or Canvas window won the idempotent publish
            // race. Its complete file is authoritative and must not change.
            try validateIndex(indexURL)
            return false
        }
    }
}
