import SwiftUI

struct PracticeSessionView: View {
    let conversations: WorkspaceConversationStore
    @Environment(\.workspaceZoom) private var zoom
    @State private var draft = ""
    @State private var attachment: MessageAttachment?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22 * zoom) {
                        sessionHeader

                        ForEach(conversations.messages(in: .practice)) { message in
                            ChannelMessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .frame(maxWidth: AppTheme.composerMaxWidth * zoom, alignment: .leading)
                    .padding(.horizontal, AppTheme.pagePadding * zoom)
                    .padding(.top, 20 * zoom)
                    .padding(.bottom, 28 * zoom)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .onChange(of: conversations.messages(in: .practice).count) { _, _ in
                    if let last = conversations.messages(in: .practice).last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            composer
        }
        .background(AppTheme.canvas)
        .task {
            await conversations.load(.practice)
        }
    }

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 8 * zoom) {
            Text("Problem 4")
                .zFont(12, weight: .semibold, zoom: zoom)
                .foregroundStyle(AppTheme.ink)

            Text("limₓ→₂ f(x)")
                .zFont(34, weight: .medium, design: .serif, zoom: zoom)
                .foregroundStyle(AppTheme.primaryText)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)

            Text("Read both sides of the graph before you decide whether the limit exists.")
                .zFont(17, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var composer: some View {
        VStack(spacing: 10 * zoom) {
            if let error = conversations.errorsByChannel[.practice] {
                Text(error)
                    .zFont(12, zoom: zoom)
                    .foregroundStyle(.red)
                    .frame(maxWidth: AppTheme.composerMaxWidth * zoom, alignment: .leading)
            }

            if conversations.messages(in: .practice).count == 1 {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10 * zoom) {
                        suggestion("The left side looks higher")
                        suggestion("They look like they agree")
                    }
                    VStack(alignment: .leading, spacing: 8 * zoom) {
                        suggestion("The left side looks higher")
                        suggestion("They look like they agree")
                    }
                }
                .frame(maxWidth: AppTheme.composerMaxWidth * zoom)
            }

            PromptComposer(
                draft: $draft,
                attachment: $attachment,
                placeholder: "Ask about this step"
            ) {
                sendDraft()
            }
            .frame(maxWidth: AppTheme.composerMaxWidth * zoom)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.pagePadding * zoom)
        .padding(.bottom, 22 * zoom)
        .padding(.top, 8 * zoom)
    }

    private func suggestion(_ title: String) -> some View {
        Button {
            draft = title
            sendDraft()
        } label: {
            Text(title)
                .zFont(15, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.horizontal, 12 * zoom)
                .frame(height: 34 * zoom)
                .background(
                    AppTheme.paper,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    private func sendDraft() {
        let submittedDraft = draft
        let submittedAttachment = attachment
        Task {
            if await conversations.send(
                submittedDraft,
                attachment: submittedAttachment,
                in: .practice
            ) {
                if draft == submittedDraft {
                    draft = ""
                }
                if attachment?.id == submittedAttachment?.id {
                    attachment = nil
                }
                conversations.appendPreviewTutorReply(
                    "Don’t jump to the value yet. Compare the two sides first — do they meet?",
                    in: .practice
                )
            }
        }
    }
}
