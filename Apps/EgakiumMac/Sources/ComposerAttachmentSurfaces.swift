#if canImport(SwiftUI)
import SwiftUI
import UniformTypeIdentifiers
import EgakiumSharedUI

/// The macOS composer attachment control shared verbatim by Chat and Cowork.
/// Surface-specific code supplies only the current draft and its callbacks.
struct EgakiumMacComposerAttachmentAccessory: View {
    let attachments: [EgakiumComposerDraftAttachment]
    let accessibilityPrefix: String
    var isBusy = false
    var isDisabled = false
    let onAttach: () -> Void
    let onRemove: (EgakiumComposerDraftAttachment.ID) -> Void

    var body: some View {
        HStack(
            alignment: .center,
            spacing: EgakiumComposerControlMetrics.rowSpacing
        ) {
            Button(action: onAttach) {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .frame(
                            width: EgakiumComposerControlMetrics.iconLabelExtent,
                            height: EgakiumComposerControlMetrics.iconLabelExtent)
                } else {
                    Label(
                        EgakiumLocalization.string("Attach files"),
                        systemImage: "paperclip")
                        .egakiumComposerIconLabel()
                }
            }
            .egakiumCompactIconButton()
            .help(EgakiumLocalization.string("Attach files"))
            .accessibilityLabel(EgakiumLocalization.string("Attach files"))
            .accessibilityIdentifier("\(accessibilityPrefix).composer.attach")
            .disabled(isDisabled || isBusy)

            if !attachments.isEmpty {
                Menu {
                    ForEach(attachments) { attachment in
                        Button(EgakiumLocalization.format(
                            "Remove %@",
                            attachment.name)) {
                            onRemove(attachment.id)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(EgakiumLocalization.format(
                            "%lld attached",
                            Int64(attachments.count)))
                            .font(EgakiumTypography.body(13, .semibold))
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .egakiumComposerSelectionLabel()
                }
                .egakiumComposerSelectionMenu()
                .accessibilityIdentifier(
                    "\(accessibilityPrefix).composer.attachments")
                .disabled(isDisabled || isBusy)
            }
        }
        .frame(
            minHeight: EgakiumComposerControlMetrics.controlHeight,
            alignment: .center)
    }
}

private struct EgakiumMacComposerAttachmentImportModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onImport: ([URL]) -> Void
    let onFailure: (Error) -> Void

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: [.data, .content],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    onImport(urls)
                case .failure(let error):
                    onFailure(error)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard !urls.isEmpty else { return false }
                onImport(urls)
                return true
            }
    }
}

extension View {
    func egakiumComposerAttachmentImport(
        isPresented: Binding<Bool>,
        onImport: @escaping ([URL]) -> Void,
        onFailure: @escaping (Error) -> Void
    ) -> some View {
        modifier(EgakiumMacComposerAttachmentImportModifier(
            isPresented: isPresented,
            onImport: onImport,
            onFailure: onFailure))
    }
}
#endif
