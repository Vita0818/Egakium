import Foundation
import IntatisCore

/// Egakium-owned development override for the exact shared Intatis Codex
/// executable. The runtime performs executable, version, and derivation checks.
enum EgakiumCodexRuntimeOverride {
    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        // The shipping-identity App always consumes its sealed resource.
        // Development Xcode builds embed the same exact runtime during the
        // post-build phase, so an ambient path must not override the bundle.
        if Bundle.main.bundleIdentifier
            == IntatisHostApplication.identity.expectedMacBundleIdentifier {
            return nil
        }
        guard let raw = environment["EGAKIUM_CODEX_RUNTIME"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: raw).standardizedFileURL
    }
}
