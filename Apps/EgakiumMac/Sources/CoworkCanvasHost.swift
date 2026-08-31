#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI
import AppKit
import IntatisCore
import EgakiumCanvas
import IntatisSharedUI

struct CoworkCanvasHost: View {
    @State private var manualReloadRevision: UInt64 = 0

    let document: SessionCanvasDocument?
    let errorMessage: String?
    let automaticReloadRevision: UInt64
    let onRetry: (() -> Void)?

    init(
        document: SessionCanvasDocument?,
        errorMessage: String?,
        automaticReloadRevision: UInt64 = 0,
        onRetry: (() -> Void)? = nil
    ) {
        self.document = document
        self.errorMessage = errorMessage
        self.automaticReloadRevision = automaticReloadRevision
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(IntatisLocalization.string("Session Canvas"))
                    .font(IntatisTypography.system(.headline))
                Text(
                    document?.relativeIndexPath
                        ?? IntatisLocalization.string("Preparing index.html…"))
                    .font(IntatisTypography.system(.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 12)

            Button {
                manualReloadRevision &+= 1
            } label: {
                Label(
                    IntatisLocalization.string("Reload Canvas"),
                    systemImage: "arrow.clockwise")
            }
            .disabled(document == nil || !cefIsAvailable)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var content: some View {
        if let document {
            #if EGAKIUM_MAC_APP_STORE
            canvasUnavailable(
                "The legacy App Store target does not contain the required CEF runtime.")
            #else
            if cefIsAvailable {
                CoworkCanvasCEFView(
                    indexURL: document.indexURL,
                    readAccessURL: document.directoryURL,
                    reloadToken: CanvasReloadToken(
                        automaticRevision:
                            automaticReloadRevision,
                        manualRevision:
                            manualReloadRevision))
                    .id(document.relativeIndexPath)
            } else {
                canvasUnavailable(
                    EgakiumCEFInitializationError()
                        ?? "The official Chromium Embedded Framework is unavailable.")
            }
            #endif
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

    private var cefIsAvailable: Bool {
        #if EGAKIUM_MAC_APP_STORE
        false
        #else
        EgakiumCEFIsAvailable()
        #endif
    }

    private func canvasUnavailable(_ message: String) -> some View {
        ContentUnavailableView {
            Label(
                IntatisLocalization.string("Canvas Unavailable"),
                systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if !EGAKIUM_MAC_APP_STORE
private struct CanvasReloadToken: Equatable {
    let automaticRevision: UInt64
    let manualRevision: UInt64
}

private struct CoworkCanvasCEFView: NSViewRepresentable {
    let indexURL: URL
    let readAccessURL: URL
    let reloadToken: CanvasReloadToken

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> EgakiumCEFView {
        EgakiumCEFView(frame: .zero)
    }

    func updateNSView(_ cefView: EgakiumCEFView, context: Context) {
        let descriptor = LoadDescriptor(
            indexURL: indexURL,
            readAccessURL: readAccessURL,
            reloadToken: reloadToken)
        context.coordinator.update(cefView, descriptor: descriptor)
    }

    static func dismantleNSView(
        _ cefView: EgakiumCEFView,
        coordinator: Coordinator
    ) {
        cefView.closeBrowser()
        coordinator.reset()
    }

    struct LoadDescriptor: Equatable {
        let indexURL: URL
        let readAccessURL: URL
        let reloadToken: CanvasReloadToken

        var source: SourceDescriptor {
            SourceDescriptor(
                indexURL: indexURL,
                readAccessURL: readAccessURL)
        }
    }

    struct SourceDescriptor: Equatable {
        let indexURL: URL
        let readAccessURL: URL
    }

    @MainActor
    final class Coordinator {
        private var loadedSource: SourceDescriptor?
        private var loadedReloadToken: CanvasReloadToken?

        func update(
            _ cefView: EgakiumCEFView,
            descriptor: LoadDescriptor
        ) {
            if descriptor.source != loadedSource {
                guard cefView.loadCanvasIndexURL(
                    descriptor.indexURL,
                    readAccessURL: descriptor.readAccessURL)
                else { return }
                loadedSource = descriptor.source
                loadedReloadToken = descriptor.reloadToken
                return
            }

            guard loadedReloadToken != descriptor.reloadToken else { return }
            loadedReloadToken = descriptor.reloadToken
            cefView.reloadCanvas()
        }

        func reset() {
            loadedSource = nil
            loadedReloadToken = nil
        }
    }
}
#endif
#endif
