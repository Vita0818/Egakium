import Foundation

public enum SessionCanvasStoreError: Error, LocalizedError, Equatable {
    case invalidSessionID
    case invalidElementID
    case unsafePath(String)
    case indexIsNotRegularFile(String)
    case elementAlreadyExists(String)
    case elementDescriptorMismatch(String)
    case elementRollbackRefused(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSessionID:
            return "The session identifier cannot be used for a Canvas path."
        case .invalidElementID:
            return "The element identifier cannot be used for a Canvas path."
        case .unsafePath(let path):
            return "The Canvas path is unsafe or is not a directory: \(path)"
        case .indexIsNotRegularFile(let path):
            return "The Canvas index is not a regular file: \(path)"
        case .elementAlreadyExists(let path):
            return "A Canvas element already exists at: \(path)"
        case .elementDescriptorMismatch(let path):
            return "The Canvas element descriptor does not match its Session path: \(path)"
        case .elementRollbackRefused(let path):
            return "The Canvas element changed after provisioning, so rollback was refused: \(path)"
        }
    }
}

/// Additive durable provenance for the generic element document provisioned by
/// one successful `spawn_agent` admission.
///
/// The descriptor records only a workspace-relative resource. It intentionally
/// carries no Agent owner or lease: authorization continues to come from the
/// invocation's ordinary WorkspaceLease and CapabilityLease.
public struct SessionCanvasElementDescriptor: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let elementID: CanvasElementID
    public let relativeIndexPath: String
    public let templateVersion: Int

    public init(
        elementID: CanvasElementID,
        relativeIndexPath: String,
        templateVersion: Int = SessionCanvasElementTemplate.templateVersion,
        schemaVersion: Int = currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.elementID = elementID
        self.relativeIndexPath = relativeIndexPath
        self.templateVersion = templateVersion
    }
}

/// A freshly provisioned generic element document. Unlike the idempotent
/// Session Canvas entry point, every instance is created with no-overwrite
/// semantics and can be precisely compensated before spawn admission commits.
public struct SessionCanvasElementDocument: Equatable, Sendable {
    public let sessionID: SessionID
    public let workspaceRoot: URL
    public let descriptor: SessionCanvasElementDescriptor
    /// Process-local proof that this value came directly from the fresh
    /// provisioning call, rather than from a later lookup. It is deliberately
    /// neither public nor durable.
    fileprivate let rollbackNonce: UUID?

    fileprivate init(
        sessionID: SessionID,
        workspaceRoot: URL,
        descriptor: SessionCanvasElementDescriptor,
        rollbackNonce: UUID? = nil
    ) {
        self.sessionID = sessionID
        self.workspaceRoot = workspaceRoot
        self.descriptor = descriptor
        self.rollbackNonce = rollbackNonce
    }

    public static func == (
        lhs: SessionCanvasElementDocument,
        rhs: SessionCanvasElementDocument
    ) -> Bool {
        lhs.sessionID == rhs.sessionID
            && lhs.workspaceRoot == rhs.workspaceRoot
            && lhs.descriptor == rhs.descriptor
    }

    public var indexURL: URL {
        workspaceRoot.appendingPathComponent(descriptor.relativeIndexPath)
    }

    public var directoryURL: URL {
        indexURL.deletingLastPathComponent()
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
    public static let canvasContractVersion = 1

    /// Returns the single generic child-document seed used by every fresh
    /// Canvas element task. This does not create a file or grant path access.
    public static func defaultElementHTML() -> String {
        SessionCanvasElementTemplate.html
    }

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

    public static func relativeElementsDirectoryPath(
        for sessionID: SessionID
    ) throws -> String {
        "\(try relativeDirectoryPath(for: sessionID))/elements"
    }

    public static func relativeElementDirectoryPath(
        for sessionID: SessionID,
        elementID: CanvasElementID
    ) throws -> String {
        let element = try validatedElementComponent(elementID)
        return "\(try relativeElementsDirectoryPath(for: sessionID))/\(element)"
    }

    public static func relativeElementIndexPath(
        for sessionID: SessionID,
        elementID: CanvasElementID
    ) throws -> String {
        "\(try relativeElementDirectoryPath(for: sessionID, elementID: elementID))/index.html"
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

        _ = try ensureDirectoryChain(
            relativeDirectory,
            within: canonicalRoot,
            fileManager: fileManager)

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

    /// Creates one real, fresh generic element document beneath the new
    /// agent's exact workspace root. The host may do this for a read-only
    /// agent, just as it initializes the Session Canvas for `@main`; whether
    /// the agent can later edit the document still depends on its leases.
    ///
    /// This method never creates or edits the shared Session `index.html` and
    /// never replaces an existing element directory or document.
    public static func provisionElementTemplate(
        in workspaceRoot: URL,
        sessionID: SessionID,
        elementID: CanvasElementID,
        fileManager: FileManager = .default
    ) throws -> SessionCanvasElementDocument {
        let canonicalRoot = try PathConfinement.canonicalExistingDirectory(
            workspaceRoot)
        let elementsRelative = try relativeElementsDirectoryPath(for: sessionID)
        let elementRelative = try relativeElementDirectoryPath(
            for: sessionID,
            elementID: elementID)
        let indexRelative = try relativeElementIndexPath(
            for: sessionID,
            elementID: elementID)
        let elementsDirectory = try ensureDirectoryChain(
            elementsRelative,
            within: canonicalRoot,
            fileManager: fileManager)
        let elementDirectory = try PathConfinement.resolve(
            elementRelative,
            within: canonicalRoot)
        guard elementDirectory.deletingLastPathComponent().standardizedFileURL
                == elementsDirectory.standardizedFileURL else {
            throw SessionCanvasStoreError.unsafePath(elementDirectory.path)
        }

        do {
            try fileManager.createDirectory(
                at: elementDirectory,
                withIntermediateDirectories: false)
        } catch CocoaError.fileWriteFileExists {
            throw SessionCanvasStoreError.elementAlreadyExists(
                elementDirectory.path)
        }

        let indexURL = try PathConfinement.resolve(
            indexRelative,
            within: canonicalRoot)
        do {
            let created = try publishInitialIndex(
                Data(defaultElementHTML().utf8),
                at: indexURL,
                fileManager: fileManager)
            guard created else {
                throw SessionCanvasStoreError.elementAlreadyExists(indexURL.path)
            }
            try validateIndex(indexURL)
        } catch {
            // The directory did not exist before this call. Remove it only if
            // it still has the exact empty/template shape we just created.
            try? removeProvisionedElementDirectoryIfUnchanged(
                elementDirectory,
                allowEmpty: true,
                fileManager: fileManager)
            throw error
        }

        let descriptor = SessionCanvasElementDescriptor(
            elementID: elementID,
            relativeIndexPath: indexRelative)
        return SessionCanvasElementDocument(
            sessionID: sessionID,
            workspaceRoot: canonicalRoot,
            descriptor: descriptor,
            rollbackNonce: UUID())
    }

    /// Validates that a descriptor is the canonical v1 path for its exact
    /// Session and template. Replay uses this before injecting the path into a
    /// model-facing prompt, so malformed or future records fail closed.
    public static func validateElementDescriptor(
        _ descriptor: SessionCanvasElementDescriptor,
        sessionID: SessionID
    ) throws {
        let expected = try relativeElementIndexPath(
            for: sessionID,
            elementID: descriptor.elementID)
        guard descriptor.schemaVersion
                == SessionCanvasElementDescriptor.currentSchemaVersion,
              descriptor.templateVersion
                == SessionCanvasElementTemplate.templateVersion,
              descriptor.relativeIndexPath == expected else {
            throw SessionCanvasStoreError.elementDescriptorMismatch(
                descriptor.relativeIndexPath)
        }
    }

    /// Resolves a durably described element without creating or resetting it.
    /// Edited child-document bytes are valid; only the canonical path and file
    /// type are checked here.
    public static func existingElement(
        in workspaceRoot: URL,
        sessionID: SessionID,
        descriptor: SessionCanvasElementDescriptor,
        fileManager: FileManager = .default
    ) throws -> SessionCanvasElementDocument? {
        try validateElementDescriptor(descriptor, sessionID: sessionID)
        let canonicalRoot = try PathConfinement.canonicalExistingDirectory(
            workspaceRoot)
        let relativeDirectory = try relativeElementDirectoryPath(
            for: sessionID,
            elementID: descriptor.elementID)

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
            descriptor.relativeIndexPath,
            within: canonicalRoot)
        guard fileManager.fileExists(atPath: indexURL.path) else {
            return nil
        }
        try validateIndex(indexURL)
        return SessionCanvasElementDocument(
            sessionID: sessionID,
            workspaceRoot: canonicalRoot,
            descriptor: descriptor)
    }

    /// Compensates a just-provisioned document when the atomic EventLog spawn
    /// admission fails. It refuses to delete if any byte, entry, type, symlink,
    /// Session binding, or workspace binding no longer matches the object this
    /// process created.
    public static func rollbackProvisionedElement(
        _ document: SessionCanvasElementDocument,
        fileManager: FileManager = .default
    ) throws {
        guard document.rollbackNonce != nil else {
            throw SessionCanvasStoreError.elementRollbackRefused(
                document.directoryURL.path)
        }
        try validateElementDescriptor(
            document.descriptor,
            sessionID: document.sessionID)
        let canonicalRoot = try PathConfinement.canonicalExistingDirectory(
            document.workspaceRoot)
        guard canonicalRoot.standardizedFileURL
                == document.workspaceRoot.standardizedFileURL else {
            throw SessionCanvasStoreError.elementRollbackRefused(
                document.directoryURL.path)
        }
        let resolved = try PathConfinement.resolve(
            document.descriptor.relativeIndexPath,
            within: canonicalRoot)
        guard resolved.standardizedFileURL == document.indexURL.standardizedFileURL else {
            throw SessionCanvasStoreError.elementRollbackRefused(
                document.directoryURL.path)
        }
        try removeProvisionedElementDirectoryIfUnchanged(
            document.directoryURL,
            allowEmpty: false,
            fileManager: fileManager)
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
          <title>Egakium Canvas</title>
          <style>
            :root {
              color-scheme: light dark;
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
              --canvas-grid: rgba(60, 60, 67, 0.10);
              --canvas-surface: #f7f7f5;
              --card-surface: rgba(255, 255, 255, 0.96);
              --card-border: rgba(60, 60, 67, 0.22);
              --card-muted: rgba(60, 60, 67, 0.68);
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
              color: CanvasText;
              background: var(--canvas-surface);
            }
            #canvas {
              position: relative;
              width: 100%;
              min-width: 1200px;
              min-height: 900px;
              background-color: var(--canvas-surface);
              background-image:
                linear-gradient(var(--canvas-grid) 1px, transparent 1px),
                linear-gradient(90deg, var(--canvas-grid) 1px, transparent 1px);
              background-size: 24px 24px;
            }
            .egakium-canvas-empty-state {
              position: absolute;
              top: 48px;
              left: 48px;
              width: 360px;
              padding: 18px 20px;
              border: 1px dashed var(--card-border);
              border-radius: 16px;
              color: var(--card-muted);
              background: var(--card-surface);
            }
            #canvas:has(> .egakium-element) > .egakium-canvas-empty-state {
              display: none;
            }
            .egakium-canvas-empty-state strong,
            .egakium-canvas-empty-state span {
              display: block;
            }
            .egakium-canvas-empty-state strong { margin-bottom: 6px; }
            .egakium-element {
              position: absolute;
              left: attr(data-x px, 64px);
              top: attr(data-y px, 64px);
              display: grid;
              grid-template-rows: 38px minmax(0, 1fr);
              width: attr(data-width px, 420px);
              height: attr(data-height px, 300px);
              min-width: 240px;
              min-height: 160px;
              overflow: hidden;
              border: 1px solid var(--card-border);
              border-radius: 16px;
              background: var(--card-surface);
              box-shadow: 0 12px 32px rgba(0, 0, 0, 0.14);
            }
            .egakium-element::before {
              content: attr(data-element-title);
              display: flex;
              align-items: center;
              min-width: 0;
              padding: 0 12px;
              overflow: hidden;
              border-bottom: 1px solid var(--card-border);
              font-size: 13px;
              font-weight: 650;
              text-overflow: ellipsis;
              white-space: nowrap;
            }
            .egakium-element > iframe {
              display: block;
              width: 100%;
              height: 100%;
              min-width: 0;
              min-height: 0;
              border: 0;
              background: Canvas;
            }
          </style>
        </head>
        <body>
          <!--
            Host-created once per Session. exact @main may directly edit this
            document. A child HTML document is represented by one direct
            .egakium-element card. CEF renders these source-owned cards and
            child documents directly; the host injects no DOM runtime and
            persists no parallel layout. Successful sub-agent spawns provision
            child documents from the single host-owned element template.

            Example:
            <article class="egakium-element"
                     data-element-id="element-001"
                     data-element-title="Element title"
                     data-x="64" data-y="64"
                     data-width="420" data-height="300">
              <iframe src="elements/element-001/index.html"
                      title="Element title"
                      sandbox="allow-scripts"></iframe>
            </article>
          -->
          <main id="canvas"
                data-egakium-session="\(session)"
                data-egakium-canvas-contract="\(canvasContractVersion)">
            <section class="egakium-canvas-empty-state"
                     data-egakium-canvas-empty-state="true"
                     aria-live="polite">
              <strong>Canvas ready</strong>
              <span>Child HTML documents will appear here as Canvas elements.</span>
            </section>
          </main>
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

    private static func validatedElementComponent(
        _ elementID: CanvasElementID
    ) throws -> String {
        let value = elementID.rawValue
        guard !value.isEmpty,
              value.count <= 128,
              value.unicodeScalars.allSatisfy({ scalar in
                  let code = scalar.value
                  return (48...57).contains(code)
                      || (65...90).contains(code)
                      || (97...122).contains(code)
                      || code == 95
                      || code == 45
              }) else {
            throw SessionCanvasStoreError.invalidElementID
        }
        return value
    }

    private static func ensureDirectoryChain(
        _ relativeDirectory: String,
        within canonicalRoot: URL,
        fileManager: FileManager
    ) throws -> URL {
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
        return current
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

    private static func removeProvisionedElementDirectoryIfUnchanged(
        _ directoryURL: URL,
        allowEmpty: Bool,
        fileManager: FileManager
    ) throws {
        let directoryValues = try directoryURL.resourceValues(forKeys: [
            .isDirectoryKey,
            .isSymbolicLinkKey,
        ])
        guard directoryValues.isDirectory == true,
              directoryValues.isSymbolicLink != true else {
            throw SessionCanvasStoreError.elementRollbackRefused(
                directoryURL.path)
        }
        let entries = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [])
        if allowEmpty, entries.isEmpty {
            try fileManager.removeItem(at: directoryURL)
            return
        }
        guard entries.count == 1,
              entries[0].lastPathComponent == "index.html" else {
            throw SessionCanvasStoreError.elementRollbackRefused(
                directoryURL.path)
        }
        try validateIndex(entries[0])
        let bytes = try Data(contentsOf: entries[0], options: [.mappedIfSafe])
        guard bytes == Data(defaultElementHTML().utf8) else {
            throw SessionCanvasStoreError.elementRollbackRefused(
                directoryURL.path)
        }
        try fileManager.removeItem(at: entries[0])
        try fileManager.removeItem(at: directoryURL)
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
