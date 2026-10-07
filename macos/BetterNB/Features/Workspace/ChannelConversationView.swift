import SwiftUI

struct ChannelConversationView: View {
    let destination: WorkspaceDestination
    let conversations: WorkspaceConversationStore
    var topicTitle = "Study conversation"
    var onBackToStudy: (() -> Void)? = nil
    var onAskCourse: ((String) async -> Bool)? = nil

    @Environment(\.workspaceZoom) private var zoom
    @State private var composerFocusRequest = UUID()

    var body: some View {
        VStack(spacing: 0) {
            if let onBackToStudy {
                HStack {
                    Button(action: onBackToStudy) {
                        Label("Course workspace", systemImage: "chevron.left")
                            .zFont(12, weight: .medium, zoom: zoom)
                            .foregroundStyle(LemmaColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppTheme.pagePadding * zoom)
                .frame(height: 42 * zoom)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(AppTheme.stroke).frame(height: 1)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20 * zoom) {
                        VStack(alignment: .leading, spacing: 8 * zoom) {
                            Text("Study with Lemma")
                                .font(LemmaTypography.caption(zoom))
                                .foregroundStyle(LemmaColors.textTertiary)
                            Text(topicTitle)
                                .font(LemmaTypography.conceptTitle(zoom))
                                .foregroundStyle(LemmaColors.textPrimary)
                            Text("A focused space to understand the idea, one question at a time.")
                                .font(LemmaTypography.body(zoom))
                                .foregroundStyle(LemmaColors.textSecondary)
                        }
                        .padding(.bottom, 10 * zoom)
                        if conversations.messages(in: destination).isEmpty {
                            emptyState
                        } else {
                            ForEach(conversations.messages(in: destination)) { message in
                                ChannelMessageBubble(message: message)
                                    .id(message.id)
                            }
                            if conversations.messages(in: destination).last?.role == .tutor {
                                followUpActions
                            }
                        }
                    }
                    .frame(maxWidth: 820 * zoom, alignment: .leading)
                    .padding(.horizontal, AppTheme.pagePadding * zoom)
                    .padding(.top, 34 * zoom)
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
                    draft: Binding(
                        get: { conversations.composerDraft },
                        set: { conversations.composerDraft = $0 }
                    ),
                    attachment: Binding(
                        get: { conversations.composerAttachment },
                        set: { conversations.composerAttachment = $0 }
                    ),
                    placeholder: "Ask a follow-up about \(topicTitle)…",
                    allowedContentTypes: [.png, .jpeg],
                    attachmentDescription: "a PNG or JPEG image",
                    focusRequest: composerFocusRequest
                ) {
                    sendDraft()
                }
                .frame(maxWidth: AppTheme.composerMaxWidth * zoom)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppTheme.pagePadding * zoom)
            .padding(.top, 10 * zoom)
            .padding(.bottom, 22 * zoom)
        }
        .background(Color.clear)
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

    private var followUpActions: some View {
        HStack(spacing: 14 * zoom) {
            followUpButton("Explain more simply", prompt: "Could you explain that more simply?")
            followUpButton("Another example", prompt: "Could you show me another example?")
            followUpButton("Check my understanding", prompt: "Can you ask me a question to check my understanding?")
            Spacer(minLength: 0)
        }
        .padding(.top, 3 * zoom)
    }

    private func followUpButton(_ title: String, prompt: String) -> some View {
        Button {
            conversations.composerDraft = prompt
            composerFocusRequest = UUID()
        } label: {
            Text(title)
                .font(.system(size: 12 * zoom, weight: .medium))
                .foregroundStyle(LemmaColors.accent)
                .padding(.horizontal, 2 * zoom)
                .frame(height: 26 * zoom)
        }
        .buttonStyle(.plain)
    }

    private func sendDraft() {
        let submittedDraft = conversations.composerDraft
        let submittedAttachment = conversations.composerAttachment
        Task {
            let didSend: Bool
            if let onAskCourse, submittedAttachment == nil {
                didSend = await onAskCourse(submittedDraft)
            } else {
                didSend = await conversations.send(
                    submittedDraft,
                    attachment: submittedAttachment,
                    in: destination
                )
            }
            if didSend {
                if conversations.composerDraft == submittedDraft {
                    conversations.composerDraft = ""
                }
                if conversations.composerAttachment?.id == submittedAttachment?.id {
                    conversations.composerAttachment = nil
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
                Text(message.role == .student ? "YOUR QUESTION" : "LEMMA · EXPLANATION")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(message.role == .student ? LemmaColors.textTertiary : LemmaColors.textSecondary)
                    .padding(.bottom, 3 * zoom)
                if !message.text.isEmpty {
                    if message.role == .tutor {
                        TutorMathText(source: message.text, fontSize: 15 * zoom)
                    } else {
                        Text(message.text)
                            .zFont(15, zoom: zoom)
                            .foregroundStyle(AppTheme.primaryText)
                            .lineSpacing(5)
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
                .padding(message.role == .student ? 14 * zoom : 0)
                .background(
                    message.role == .student ? LemmaColors.surfaceElevated : Color.clear,
                    in: RoundedRectangle(cornerRadius: LemmaRadius.control * zoom, style: .continuous)
                )
                .overlay {
                    if message.role == .student {
                        RoundedRectangle(cornerRadius: LemmaRadius.control * zoom, style: .continuous)
                            .stroke(LemmaColors.border, lineWidth: 1)
                    }
                }
                .frame(
                    maxWidth: message.role == .student ? 620 * zoom : 760 * zoom,
                    alignment: message.role == .student ? .trailing : .leading
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: message.role == .student ? .trailing : .leading
        )
        .padding(.vertical, message.role == .student ? 4 * zoom : 13 * zoom)
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
