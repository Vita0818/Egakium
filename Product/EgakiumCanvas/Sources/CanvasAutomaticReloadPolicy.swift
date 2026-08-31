/// The host-proven source of one completed runtime item considered for a
/// Canvas presentation reload. Workspace strings are canonical identities
/// resolved by the embedding host; this value grants no filesystem access.
public enum CanvasAutomaticReloadSource: Equatable, Sendable {
    case root
    case descendant(canonicalWorkspaceIdentity: String?)
}

/// Pure fail-closed policy for turning an exact App Server item completion
/// into a Canvas presentation reload. It neither observes the filesystem nor
/// mutates Canvas content.
public enum CanvasAutomaticReloadPolicy {
    public static func shouldReload(
        isFileChange: Bool,
        isFailure: Bool,
        canvasWorkspaceIdentity: String?,
        source: CanvasAutomaticReloadSource
    ) -> Bool {
        guard isFileChange,
              !isFailure,
              let canvasWorkspaceIdentity,
              !canvasWorkspaceIdentity.isEmpty else {
            return false
        }

        switch source {
        case .root:
            return true
        case .descendant(let descendantWorkspaceIdentity):
            return descendantWorkspaceIdentity == canvasWorkspaceIdentity
        }
    }
}
