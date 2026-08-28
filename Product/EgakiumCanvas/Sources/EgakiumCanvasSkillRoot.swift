import Foundation

/// Product-owned native Codex Skill root. It contains only Egakium Canvas
/// instructions and assets; Intatis continues to own Skill discovery/runtime.
public enum EgakiumCanvasSkillRoot {
    public static var url: URL {
        Bundle.module.resourceURL!
            .appendingPathComponent("BundledSkills", isDirectory: true)
    }
}
