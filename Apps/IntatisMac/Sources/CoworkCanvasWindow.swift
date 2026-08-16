#if canImport(SwiftUI) && canImport(AppKit) && canImport(WebKit)
import SwiftUI
import AppKit
import WebKit
import IntatisCore
import IntatisSharedUI

struct CoworkCanvasWindowValue: Codable, Hashable {
    let sessionID: SessionID
}

@MainActor
private final class CoworkCanvasWindowModel: ObservableObject {
    @Published private(set) var document: SessionCanvasDocument?
    @Published private(set) var errorMessage: String?
    @Published private(set) var reloadRevision: UInt64 = 0

    let sessionID: SessionID

    private var workspaceAccess: WorkspaceAccessLease?
    private var monitorTask: Task<Void, Never>?
    private var lastSignature: FileSignature?

    init(sessionID: SessionID) {
        self.sessionID = sessionID
    }

    func start() {
        guard monitorTask == nil else { return }
        errorMessage = nil
        monitorTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let access = try WorkspaceAccess.restoredWorkspace(
                    for: sessionID) else {
                    throw IntatisError.io(
                        "The primary Cowork workspace must be reopened before the Canvas can be displayed.")
                }
                guard let document = try SessionCanvasStore.existingCanvas(
                    in: access.canonicalURL,
                    sessionID: sessionID) else {
                    throw IntatisError.notFound(
                        "The Session Canvas has not been initialized. Open the Cowork Session before retrying.")
                }
                workspaceAccess = access
                self.document = document
                lastSignature = fileSignature(at: document.indexURL)
                reloadRevision &+= 1

                while !Task.isCancelled {
                    try await Task.sleep(nanoseconds: 600_000_000)
                    guard !Task.isCancelled else { break }
                    let signature = fileSignature(at: document.indexURL)
                    if signature != lastSignature {
                        lastSignature = signature
                        reloadRevision &+= 1
                    }
                }
            } catch is CancellationError {
                // Window closure owns normal monitor cancellation.
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        workspaceAccess?.release()
        workspaceAccess = nil
    }

    func retry() {
        stop()
        document = nil
        errorMessage = nil
        start()
    }

    func reload() {
        reloadRevision &+= 1
    }

    private struct FileSignature: Equatable {
        let modificationDate: Date?
        let fileSize: Int?
    }

    private func fileSignature(at url: URL) -> FileSignature? {
        guard let values = try? url.resourceValues(forKeys: [
            .contentModificationDateKey,
            .fileSizeKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
        ]),
        values.isRegularFile == true,
        values.isSymbolicLink != true else {
            return nil
        }
        return FileSignature(
            modificationDate: values.contentModificationDate,
            fileSize: values.fileSize)
    }
}

struct CoworkCanvasWindowView: View {
    @StateObject private var model: CoworkCanvasWindowModel

    init(sessionID: SessionID) {
        _model = StateObject(
            wrappedValue: CoworkCanvasWindowModel(sessionID: sessionID))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 720, minHeight: 520)
        .navigationTitle(
            IntatisLocalization.format(
                "Canvas — %@",
                model.sessionID.rawValue))
        .task { model.start() }
        .onDisappear { model.stop() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(IntatisLocalization.string("Session Canvas"))
                    .font(.headline)
                Text(
                    model.document?.relativeIndexPath
                        ?? IntatisLocalization.string("Preparing index.html…"))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 12)

            Button {
                model.reload()
            } label: {
                Label(
                    IntatisLocalization.string("Reload Canvas"),
                    systemImage: "arrow.clockwise")
            }
            .disabled(model.document == nil)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var content: some View {
        if let document = model.document {
            CoworkCanvasWebView(
                indexURL: document.indexURL,
                readAccessURL: document.directoryURL,
                reloadRevision: model.reloadRevision)
        } else if let errorMessage = model.errorMessage {
            ContentUnavailableView {
                Label(
                    IntatisLocalization.string("Canvas Unavailable"),
                    systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button(IntatisLocalization.string("Retry")) {
                    model.retry()
                }
            }
        } else {
            VStack(spacing: 12) {
                ProgressView()
                Text(IntatisLocalization.string("Preparing Session Canvas…"))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct CoworkCanvasWebView: NSViewRepresentable {
    let indexURL: URL
    let readAccessURL: URL
    let reloadRevision: UInt64

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        webView.underPageBackgroundColor = .clear
        #if DEBUG
        webView.isInspectable = true
        #endif
        context.coordinator.prepare(webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.requestLoad(
            in: webView,
            descriptor: LoadDescriptor(
                indexURL: indexURL,
                readAccessURL: readAccessURL,
                revision: reloadRevision))
    }

    static func dismantleNSView(
        _ webView: WKWebView,
        coordinator: Coordinator
    ) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeAllUserScripts()
        coordinator.stop()
    }

    struct LoadDescriptor: Equatable {
        let indexURL: URL
        let readAccessURL: URL
        let revision: UInt64
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        private var pendingLoad: LoadDescriptor?
        private var loaded: LoadDescriptor?
        private var networkBlockerReady = false
        private var stopped = false

        func prepare(_ webView: WKWebView) {
            let rules = #"[{"trigger":{"url-filter":"^http://"},"action":{"type":"block"}},{"trigger":{"url-filter":"^https://"},"action":{"type":"block"}},{"trigger":{"url-filter":"^ws://"},"action":{"type":"block"}},{"trigger":{"url-filter":"^wss://"},"action":{"type":"block"}},{"trigger":{"url-filter":"^ftp://"},"action":{"type":"block"}}]"#
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "egakium-canvas-network-deny-v1",
                encodedContentRuleList: rules
            ) { [weak self, weak webView] list, error in
                Task { @MainActor in
                    guard let self, let webView, !self.stopped else { return }
                    guard let list else {
                        self.showConfigurationFailure(
                            in: webView,
                            message: error?.localizedDescription
                                ?? "The Canvas network blocker could not be installed.")
                        return
                    }
                    webView.configuration.userContentController.add(list)
                    self.networkBlockerReady = true
                    self.loadPendingIfNeeded(in: webView)
                }
            }
        }

        func requestLoad(
            in webView: WKWebView,
            descriptor: LoadDescriptor
        ) {
            pendingLoad = descriptor
            loadPendingIfNeeded(in: webView)
        }

        func stop() {
            stopped = true
            pendingLoad = nil
            loaded = nil
        }

        private func loadPendingIfNeeded(in webView: WKWebView) {
            guard networkBlockerReady,
                  let pendingLoad,
                  pendingLoad != loaded else { return }
            guard FileManager.default.fileExists(
                atPath: pendingLoad.indexURL.path) else {
                showConfigurationFailure(
                    in: webView,
                    message: "The Session Canvas index.html is missing.")
                return
            }
            loaded = pendingLoad
            _ = webView.loadFileURL(
                pendingLoad.indexURL,
                allowingReadAccessTo: pendingLoad.readAccessURL)
        }

        private func showConfigurationFailure(
            in webView: WKWebView,
            message: String
        ) {
            let escaped = message
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
            webView.loadHTMLString(
                """
                <!doctype html><meta charset="utf-8">
                <style>body{font:14px -apple-system;margin:32px;color:#a12622}</style>
                <h1>Canvas unavailable</h1><p>\(escaped)</p>
                """,
                baseURL: nil)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable
                (WKNavigationActionPolicy) -> Void
        ) {
            guard let scheme = navigationAction.request.url?.scheme?.lowercased(),
                  ["file", "about", "data", "blob"].contains(scheme) else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
#endif
