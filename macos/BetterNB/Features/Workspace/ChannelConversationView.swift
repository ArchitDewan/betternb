import SwiftUI

struct ChannelConversationView: View {
    let destination: WorkspaceDestination
    let conversations: WorkspaceConversationStore
    var onBackToStudy: (() -> Void)? = nil

    @Environment(\.workspaceZoom) private var zoom
    @State private var draft = ""
    @State private var attachment: MessageAttachment?

    var body: some View {
        VStack(spacing: 0) {
            if let onBackToStudy {
                HStack {
                    Button(action: onBackToStudy) {
                        Label("Study desk", systemImage: "chevron.left")
                            .zFont(12, weight: .medium, zoom: zoom)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppTheme.pagePadding * zoom)
                .frame(height: 40 * zoom)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(AppTheme.stroke).frame(height: 1)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20 * zoom) {
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
                    .padding(.top, 26 * zoom)
                    .padding(.bottom, 34 * zoom)
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
                        .foregroundStyle(AppTheme.critical)
                        .frame(maxWidth: AppTheme.composerMaxWidth * zoom, alignment: .leading)
                }

                PromptComposer(
                    draft: $draft,
                    attachment: $attachment,
                    placeholder: "Message \(destination.title)",
                    allowedContentTypes: [.png, .jpeg],
                    attachmentDescription: "a PNG or JPEG image"
                ) {
                    sendDraft()
                }
                .frame(maxWidth: AppTheme.composerMaxWidth * zoom)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppTheme.pagePadding * zoom)
            .padding(.top, 10 * zoom)
            .padding(.bottom, 20 * zoom)
        }
        .background(AppTheme.canvas)
        .task(id: destination) {
            await conversations.load(destination)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 5 * zoom) {
            Text("Start a conversation about \(destination.title.lowercased()).")
                .zFont(15, weight: .medium, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
            Text("Questions and files stay connected to this part of Calculus I.")
                .zFont(13, zoom: zoom)
                .foregroundStyle(AppTheme.tertiaryText)
        }
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
                    if message.role == .tutor {
                        TutorMathText(source: message.text, fontSize: 15 * zoom)
                    } else {
                        Text(message.text)
                            .zFont(15, zoom: zoom)
                            .foregroundStyle(AppTheme.primaryText)
                            .lineSpacing(3)
                    }
                }

                if let attachment = message.attachment {
                    MessageAttachmentView(attachment: attachment)
                }

                if !message.sources.isEmpty {
                    VStack(alignment: .leading, spacing: 4 * zoom) {
                        Text("SOURCES")
                            .zFont(10, weight: .semibold, zoom: zoom)
                            .foregroundStyle(AppTheme.tertiaryText)
                        ForEach(message.sources) { source in
                            Label("\(source.title) · \(source.section)", systemImage: "doc.text")
                                .zFont(11, zoom: zoom)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                    .padding(.top, 3 * zoom)
                }
            }
                .padding(message.role == .student ? 12 * zoom : 0)
                .background(
                    message.role == .student ? AppTheme.paper : Color.clear,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    if message.role == .student {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.stroke, lineWidth: 1)
                    }
                }
                .frame(
                    maxWidth: 560 * zoom,
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
            message.sources.isEmpty
                ? nil
                : "Sources: " + message.sources.map { "\($0.title), \($0.section)" }.joined(separator: "; "),
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
                    .foregroundStyle(AppTheme.secondaryText)

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
