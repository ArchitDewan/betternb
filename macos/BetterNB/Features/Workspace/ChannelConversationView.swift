import SwiftUI

struct ChannelConversationView: View {
    let destination: WorkspaceDestination
    let conversations: WorkspaceConversationStore

    @Environment(\.workspaceZoom) private var zoom
    @State private var draft = ""
    @State private var attachment: MessageAttachment?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20 * zoom) {
                        header

                        if conversations.messages(in: destination).isEmpty {
                            emptyState
                        } else {
                            ForEach(conversations.messages(in: destination)) { message in
                                ChannelMessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                    .frame(maxWidth: AppTheme.composerMaxWidth * zoom, alignment: .leading)
                    .padding(.horizontal, AppTheme.pagePadding * zoom)
                    .padding(.top, 22 * zoom)
                    .padding(.bottom, 28 * zoom)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .onChange(of: conversations.messages(in: destination).count) { _, _ in
                    if let last = conversations.messages(in: destination).last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            VStack(spacing: 8 * zoom) {
                if let error = conversations.errorsByChannel[destination] {
                    Text(error)
                        .zFont(12, zoom: zoom)
                        .foregroundStyle(.red)
                        .frame(maxWidth: AppTheme.composerMaxWidth * zoom, alignment: .leading)
                }

                PromptComposer(
                    draft: $draft,
                    attachment: $attachment,
                    placeholder: "Message \(destination.title)"
                ) {
                    sendDraft()
                }
                .frame(maxWidth: AppTheme.composerMaxWidth * zoom)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppTheme.pagePadding * zoom)
            .padding(.top, 8 * zoom)
            .padding(.bottom, 22 * zoom)
        }
        .background(AppTheme.canvas)
        .task(id: destination) {
            await conversations.load(destination)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6 * zoom) {
            Text(destination.title)
                .zFont(28, weight: .semibold, design: .serif, zoom: zoom)
                .foregroundStyle(AppTheme.primaryText)

            Text("Keep questions and ideas connected to this part of Calculus I.")
                .zFont(17, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var emptyState: some View {
        Text("Start a conversation about \(destination.title.lowercased()).")
            .zFont(17, zoom: zoom)
            .foregroundStyle(AppTheme.tertiaryText)
            .padding(.top, 8 * zoom)
    }

    private func sendDraft() {
        let submittedDraft = draft
        let submittedAttachment = attachment
        Task {
            if await conversations.send(
                submittedDraft,
                attachment: submittedAttachment,
                in: destination
            ) {
                if draft == submittedDraft {
                    draft = ""
                }
                if attachment?.id == submittedAttachment?.id {
                    attachment = nil
                }
            }
        }
    }
}

struct ChannelMessageBubble: View {
    let message: SessionMessage
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8 * zoom) {
                if !message.text.isEmpty {
                    Text(message.text)
                        .zFont(17, zoom: zoom)
                        .foregroundStyle(AppTheme.primaryText)
                        .lineSpacing(4)
                }

                if let attachment = message.attachment {
                    MessageAttachmentView(attachment: attachment)
                }
            }
                .padding(message.role == .student ? 12 * zoom : 0)
                .background(
                    message.role == .student ? AppTheme.paper : Color.clear,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .frame(
                    maxWidth: 520 * zoom,
                    alignment: message.role == .student ? .trailing : .leading
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: message.role == .student ? .trailing : .leading
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.role == .student ? "You" : "Tutor")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        [
            message.text.isEmpty ? nil : message.text,
            message.attachment.map { "Attachment: \($0.filename)" },
        ]
        .compactMap { $0 }
        .joined(separator: ". ")
    }
}

private struct MessageAttachmentView: View {
    let attachment: MessageAttachment
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        VStack(alignment: .leading, spacing: 7 * zoom) {
            if attachment.mediaType.hasPrefix("image/"),
               let image = NSImage(data: attachment.data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260 * zoom, maxHeight: 180 * zoom)
                    .clipShape(RoundedRectangle(cornerRadius: 10 * zoom, style: .continuous))
            }

            HStack(spacing: 7 * zoom) {
                Image(systemName: attachment.mediaType == "application/pdf" ? "doc.richtext" : "photo")
                    .foregroundStyle(AppTheme.ink)

                VStack(alignment: .leading, spacing: 1) {
                    Text(attachment.filename)
                        .zFont(13, weight: .medium, zoom: zoom)
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.byteCount), countStyle: .file))
                        .zFont(11, zoom: zoom)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Attachment")
        .accessibilityValue(attachment.filename)
    }
}
