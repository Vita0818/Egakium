#if canImport(SwiftUI) && canImport(AppKit) && canImport(WebKit)
import SwiftUI
import AppKit
import WebKit
import IntatisCore
import IntatisSharedUI

@MainActor
private final class CoworkCanvasHostModel: ObservableObject {
    @Published private(set) var reloadRevision: UInt64 = 0

    private var monitorTask: Task<Void, Never>?
    private var monitoredIndexURL: URL?
    private var lastSignature: FileSignature?

    func present(_ document: SessionCanvasDocument?) {
        let indexURL = document?.indexURL
        guard indexURL != monitoredIndexURL else { return }

        monitorTask?.cancel()
        monitorTask = nil
        monitoredIndexURL = indexURL
        if let indexURL {
            lastSignature = fileSignature(at: indexURL)
        } else {
            lastSignature = nil
        }

        guard let indexURL else { return }
        reloadRevision &+= 1
        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 600_000_000)
                } catch {
                    return
                }
                guard let self,
                      !Task.isCancelled,
                      self.monitoredIndexURL == indexURL else { return }
                let signature = self.fileSignature(at: indexURL)
                if signature != self.lastSignature {
                    self.lastSignature = signature
                    self.reloadRevision &+= 1
                }
            }
        }
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        monitoredIndexURL = nil
        lastSignature = nil
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

struct CoworkCanvasHost: View {
    @StateObject private var model = CoworkCanvasHostModel()

    let document: SessionCanvasDocument?
    let errorMessage: String?
    let onRetry: (() -> Void)?

    init(
        document: SessionCanvasDocument?,
        errorMessage: String?,
        onRetry: (() -> Void)? = nil
    ) {
        self.document = document
        self.errorMessage = errorMessage
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onAppear { model.present(document) }
        .onChange(of: document) { _, document in
            model.present(document)
        }
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
                    document?.relativeIndexPath
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
            .disabled(document == nil)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var content: some View {
        if let document {
            CoworkCanvasWebView(
                indexURL: document.indexURL,
                readAccessURL: document.directoryURL,
                reloadRevision: model.reloadRevision)
        } else if let errorMessage {
            ContentUnavailableView {
                Label(
                    IntatisLocalization.string("Canvas Unavailable"),
                    systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                if let onRetry {
                    Button(IntatisLocalization.string("Retry")) {
                        onRetry()
                    }
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
