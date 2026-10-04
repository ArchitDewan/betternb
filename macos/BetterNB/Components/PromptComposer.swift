import SwiftUI
import UniformTypeIdentifiers

struct PromptComposer: View {
    @Binding var draft: String
    @Binding var attachment: MessageAttachment?
    var placeholder = "Ask about this step"
    var onSend: () -> Void = {}
    @Environment(\.workspaceZoom) private var zoom
    @State private var isImporterPresented = false
    @State private var attachmentError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * zoom) {
            if let attachment {
                attachmentChip(attachment)
            }

            if let attachmentError {
                Text(attachmentError)
                    .zFont(12, zoom: zoom)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10 * zoom)
            }

            HStack(alignment: .bottom, spacing: 10 * zoom) {
                Button {
                    isImporterPresented = true
                } label: {
                    Image(systemName: "plus")
                        .zFont(15, weight: .medium, zoom: zoom)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 32 * zoom, height: 32 * zoom)
                }
                .buttonStyle(.plain)
                .help("Add PNG, JPEG, or PDF")

                TextField(placeholder, text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .zFont(17, zoom: zoom)
                    .lineLimit(1...6)
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.vertical, 10 * zoom)
                    .submitLabel(.send)
                    .onSubmit {
                        if canSend {
                            onSend()
                        }
                    }

                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .zFont(12, weight: .bold, zoom: zoom)
                        .foregroundStyle(canSend ? AppTheme.canvas : AppTheme.tertiaryText)
                        .frame(width: 32 * zoom, height: 32 * zoom)
                        .background(
                            canSend ? AppTheme.ink : AppTheme.elevatedHover,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .help("Send")
            }
            .padding(.leading, 10 * zoom)
            .padding(.trailing, 10 * zoom)
        }
        .padding(.vertical, 6 * zoom)
        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.png, .jpeg, .pdf],
            allowsMultipleSelection: false
        ) { result in
            importSelection(result)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachment != nil
    }

    private func attachmentChip(_ attachment: MessageAttachment) -> some View {
        HStack(spacing: 8 * zoom) {
            Image(systemName: attachment.mediaType == "application/pdf" ? "doc.richtext" : "photo")
                .foregroundStyle(AppTheme.ink)

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
            .help("Remove attachment")
        }
        .padding(.leading, 12 * zoom)
        .padding(.trailing, 8 * zoom)
        .padding(.top, 4 * zoom)
    }

    private func importSelection(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }

        Task {
            do {
                let importedAttachment = try await Task.detached {
                    try MessageAttachment.importing(url)
                }.value
                attachment = importedAttachment
                attachmentError = nil
            } catch ChannelMessageError.attachmentTooLarge {
                attachmentError = "Choose a file that is 10 MiB or smaller."
            } catch ChannelMessageError.unsupportedAttachment {
                attachmentError = "Choose a PNG, JPEG, or PDF."
            } catch {
                attachmentError = "That file couldn’t be read. Try another one."
            }
        }
    }
}
