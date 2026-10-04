import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PromptComposer: View {
    @Binding var draft: String
    @Binding var attachment: MessageAttachment?
    var placeholder = "Ask about this step"
    var allowedContentTypes: [UTType] = [.png, .jpeg, .pdf]
    var attachmentDescription = "PNG, JPEG, or PDF"
    var onSend: () -> Void = {}
    @Environment(\.workspaceZoom) private var zoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isImporterPresented = false
    @State private var isImporting = false
    @State private var attachmentError: String?
    @State private var isAddHovering = false
    @State private var isSendHovering = false
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * zoom) {
            if let attachment {
                attachmentChip(attachment)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if let attachmentError {
                Label(attachmentError, systemImage: "exclamationmark.circle")
                    .zFont(12, zoom: zoom)
                    .foregroundStyle(AppTheme.critical)
                    .padding(.horizontal, 8 * zoom)
                    .transition(.opacity)
            }

            composerRow
        }
        .padding(8 * zoom)
        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(isComposerFocused ? AppTheme.strongStroke : AppTheme.stroke, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: attachment?.id)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: attachmentError)
        .onPasteCommand(of: [.image, .png, .jpeg, .tiff]) { _ in
            _ = pasteImageFromClipboard()
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            importSelection(result)
        }
    }

    private var composerRow: some View {
        HStack(alignment: .bottom, spacing: 10 * zoom) {
            addButton
            draftField
            sendButton
        }
    }

    private var addButton: some View {
        Button {
            attachmentError = nil
            isImporterPresented = true
        } label: {
            Group {
                if isImporting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "plus")
                        .zFont(14, weight: .medium, zoom: zoom)
                }
            }
            .foregroundStyle(AppTheme.secondaryText)
            .frame(width: 34 * zoom, height: 34 * zoom)
            .background(
                isAddHovering ? AppTheme.elevatedHover : Color.clear,
                in: Circle()
            )
            .contentShape(Circle())
        }
        .buttonStyle(ComposerButtonStyle())
        .disabled(isImporting)
        .onHover { isAddHovering = $0 }
        .accessibilityLabel(isImporting ? "Importing attachment" : "Add attachment")
        .accessibilityHint("Choose \(attachmentDescription)")
        .help("Add \(attachmentDescription)")
    }

    private var draftField: some View {
        TextField(placeholder, text: $draft, axis: .vertical)
            .textFieldStyle(.plain)
            .zFont(15, zoom: zoom)
            .lineLimit(1...6)
            .foregroundStyle(AppTheme.primaryText)
            .padding(.vertical, 7 * zoom)
            .frame(minHeight: 34 * zoom, alignment: .leading)
            .focused($isComposerFocused)
            .submitLabel(.send)
            .onSubmit {
                if canSend {
                    onSend()
                }
            }
            .onKeyPress(.init("v"), phases: .down) { keyPress in
                guard keyPress.modifiers.contains(.command) else { return .ignored }
                return pasteImageFromClipboard() ? .handled : .ignored
            }
    }

    private var sendButton: some View {
        Button(action: onSend) {
            Image(systemName: "arrow.up")
                .zFont(12, weight: .bold, zoom: zoom)
                .foregroundStyle(canSend ? AppTheme.inverseText : AppTheme.tertiaryText)
                .frame(width: 34 * zoom, height: 34 * zoom)
                .background(sendButtonBackground, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(ComposerButtonStyle())
        .disabled(!canSend)
        .onHover { isSendHovering = $0 }
        .accessibilityLabel("Send message")
        .accessibilityHint("Sends the current message and attachment")
        .help("Send")
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachment != nil
    }

    private var sendButtonBackground: Color {
        guard canSend else { return AppTheme.elevatedHover }
        return isSendHovering ? AppTheme.secondaryText : AppTheme.primaryText
    }

    private func attachmentChip(_ attachment: MessageAttachment) -> some View {
        HStack(spacing: 8 * zoom) {
            Image(systemName: attachment.mediaType == "application/pdf" ? "doc.richtext" : "photo")
                .foregroundStyle(AppTheme.secondaryText)
                .accessibilityHidden(true)

            Text(attachment.filename)
                .zFont(13, zoom: zoom)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                self.attachment = nil
                attachmentError = nil
            } label: {
                Image(systemName: "xmark")
                    .zFont(10, weight: .semibold, zoom: zoom)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 24 * zoom, height: 24 * zoom)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(attachment.filename)")
            .help("Remove attachment")
        }
        .padding(.leading, 10 * zoom)
        .padding(.trailing, 6 * zoom)
        .frame(height: 34 * zoom)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 9 * zoom, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9 * zoom, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        }
    }

    private func importSelection(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            importAttachment(from: url)
        case let .failure(error):
            guard (error as NSError).code != NSUserCancelledError else { return }
            attachmentError = "That file couldn’t be opened. Try another one."
        }
    }

    @discardableResult
    private func pasteImageFromClipboard() -> Bool {
        guard allowedContentTypes.contains(where: { $0.conforms(to: .image) }) else { return false }
        let board = NSPasteboard.general
        if let png = board.data(forType: .png) {
            return attachPastedImage(png, mediaType: "image/png", filename: "pasted-image.png")
        }
        if let tiff = board.data(forType: .tiff),
           let image = NSImage(data: tiff),
           let png = image.betternbPNGData() {
            return attachPastedImage(png, mediaType: "image/png", filename: "pasted-image.png")
        }
        return false
    }

    @discardableResult
    private func attachPastedImage(_ data: Data, mediaType: String, filename: String) -> Bool {
        do {
            attachment = try MessageAttachment(filename: filename, mediaType: mediaType, data: data)
            attachmentError = nil
            isComposerFocused = true
            return true
        } catch ChannelMessageError.attachmentTooLarge {
            attachmentError = "Choose a file that is 10 MiB or smaller."
        } catch {
            attachmentError = "Choose \(attachmentDescription)."
        }
        return false
    }

    private func importAttachment(from url: URL) {
        isImporting = true
        attachmentError = nil

        Task {
            defer { isImporting = false }
            do {
                let importedAttachment = try await Task.detached {
                    try MessageAttachment.importing(url)
                }.value
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
                    attachment = importedAttachment
                }
                attachmentError = nil
                isComposerFocused = true
            } catch ChannelMessageError.attachmentTooLarge {
                attachmentError = "Choose a file that is 10 MiB or smaller."
            } catch ChannelMessageError.unsupportedAttachment {
                attachmentError = "Choose \(attachmentDescription)."
            } catch {
                attachmentError = "That file couldn’t be read. Try another one."
            }
        }
    }
}

private struct ComposerButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private extension NSImage {
    func betternbPNGData() -> Data? {
        guard let tiff = tiffRepresentation, let representation = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return representation.representation(using: .png, properties: [:])
    }
}
