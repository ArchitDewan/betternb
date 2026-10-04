import SwiftUI
import UniformTypeIdentifiers

struct PracticeSessionView: View {
    let tutor: TutorSessionStore
    @Environment(\.workspaceZoom) private var zoom
    @State private var draft = ""
    @State private var attachment: MessageAttachment?
    @State private var intent: TutorSubmitIntent = .automatic

    var body: some View {
        VStack(spacing: 0) {
            if tutor.problem != nil, tutor.pendingTranscription == nil {
                workingRail
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28 * zoom) {
                        if let pending = tutor.pendingTranscription {
                            transcriptionConfirmation(pending)
                                .id("transcription")
                        } else if tutor.entries.isEmpty, !tutor.isBusy {
                            emptyState
                        }

                        ForEach(tutor.entries) { entry in
                            TutorConversationBubble(entry: entry)
                                .id(entry.id)
                        }

                        if tutor.isBusy {
                            TutorThinkingRow()
                                .id("thinking")
                        }
                    }
                    .frame(maxWidth: AppTheme.composerMaxWidth * zoom, alignment: .leading)
                    .padding(.horizontal, AppTheme.pagePadding * zoom)
                    .padding(.top, 26 * zoom)
                    .padding(.bottom, 34 * zoom)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .onChange(of: tutor.entries.count) { _, _ in
                    if tutor.isBusy {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("thinking", anchor: .bottom)
                        }
                    } else if let last = tutor.entries.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: tutor.isBusy) { _, busy in
                    withAnimation(.easeOut(duration: 0.2)) {
                        if busy {
                            proxy.scrollTo("thinking", anchor: .bottom)
                        } else if let last = tutor.entries.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: tutor.pendingTranscription) { _, pending in
                    guard pending != nil else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("transcription", anchor: .center)
                    }
                }
            }

            composer
        }
        .background(AppTheme.canvas)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14 * zoom) {
            Text("Work a derivative like a notebook.")
                .zFont(15, weight: .medium, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
            VStack(alignment: .leading, spacing: 8 * zoom) {
                emptyStep("1", "Paste the problem, or add it from Problems.")
                emptyStep("2", "Write one step, then send it as Check.")
                emptyStep("3", "Hints stay on a ladder. Reveal only if you ask.")
            }
            Text("The tutor remembers this thread, checks written derivatives with SymPy, and keeps English out of the math.")
                .zFont(13, zoom: zoom)
                .foregroundStyle(AppTheme.tertiaryText)
        }
    }

    private func emptyStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10 * zoom) {
            Text(number)
                .zFont(12, weight: .semibold, zoom: zoom)
                .foregroundStyle(AppTheme.tertiaryText)
                .frame(width: 16 * zoom, alignment: .leading)
            Text(text)
                .zFont(13, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var workingRail: some View {
        HStack(alignment: .center, spacing: 12 * zoom) {
            VStack(alignment: .leading, spacing: 3 * zoom) {
                Text("Working on")
                    .zFont(11, weight: .semibold, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
                Text(tutor.problem ?? "")
                    .zFont(13, zoom: zoom)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 8 * zoom)
            Button("New problem") {
                tutor.reset()
                draft = ""
                attachment = nil
                intent = .automatic
            }
            .buttonStyle(.plain)
            .zFont(12, weight: .medium, zoom: zoom)
            .foregroundStyle(AppTheme.secondaryText)
            .disabled(tutor.isBusy)
        }
        .padding(.horizontal, AppTheme.pagePadding * zoom)
        .padding(.vertical, 10 * zoom)
        .background(AppTheme.panel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.stroke).frame(height: 1)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10 * zoom) {
            if let error = tutor.errorMessage {
                Text(error)
                    .zFont(12, zoom: zoom)
                    .foregroundStyle(AppTheme.critical)
            }

            if let guidance = tutor.nextGuidance {
                Text(guidance)
                    .zFont(12, zoom: zoom)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            if tutor.problem != nil, tutor.pendingTranscription == nil {
                helpControls
                intentPicker
            }

            if showsDraftPreview {
                TutorMathText(source: draft, fontSize: 15 * zoom)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12 * zoom)
                    .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 10 * zoom, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10 * zoom, style: .continuous)
                            .stroke(AppTheme.stroke, lineWidth: 1)
                    }
                    .accessibilityLabel("Draft math preview")
            }

            PromptComposer(
                draft: $draft,
                attachment: $attachment,
                placeholder: composerPlaceholder,
                allowedContentTypes: [.png, .jpeg],
                attachmentDescription: "a PNG or JPEG image"
            ) {
                sendDraft()
            }
            .disabled(tutor.pendingTranscription != nil)
            .opacity(tutor.pendingTranscription == nil ? 1 : 0.55)
            .allowsHitTesting(!tutor.isBusy)
        }
        .frame(maxWidth: AppTheme.composerMaxWidth * zoom, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.pagePadding * zoom)
        .padding(.top, 10 * zoom)
        .padding(.bottom, 20 * zoom)
    }

    private var composerPlaceholder: String {
        if tutor.problem == nil {
            return "Paste a derivative problem"
        }
        return resolvedIntent == .check ? "Write the next step to check" : "Ask about this problem"
    }

    private var showsDraftPreview: Bool {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("\\") || trimmed.contains("^") || TutorMessageKind.looksLikeMathStep(trimmed)
    }

    private var resolvedIntent: TutorSubmitIntent {
        if tutor.problem == nil { return .ask }
        if intent != .automatic { return intent }
        return TutorMessageKind.looksLikeMathStep(draft) ? .check : .ask
    }

    private var intentPicker: some View {
        HStack(spacing: 8 * zoom) {
            intentChip("Ask", selected: resolvedIntent == .ask) { intent = .ask }
            intentChip("Check step", selected: resolvedIntent == .check) { intent = .check }
        }
        .disabled(tutor.isBusy)
    }

    private func intentChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .zFont(12, weight: .medium, zoom: zoom)
                .foregroundStyle(selected ? AppTheme.primaryText : AppTheme.tertiaryText)
                .padding(.horizontal, 10 * zoom)
                .padding(.vertical, 5 * zoom)
                .background(selected ? AppTheme.elevated : Color.clear, in: Capsule())
                .overlay {
                    Capsule().stroke(selected ? AppTheme.strongStroke : AppTheme.stroke, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var helpControls: some View {
        HStack(spacing: 10 * zoom) {
            ForEach(1...3, id: \.self) { level in
                let used = tutor.usedHintCount >= level
                let current = tutor.nextHintLevel == level
                Button {
                    guard current else { return }
                    Task { _ = await tutor.requestHint() }
                } label: {
                    Text("Hint \(level)")
                        .underline(current)
                        .foregroundStyle(used || current ? AppTheme.primaryText : AppTheme.tertiaryText)
                }
                .disabled(!current || tutor.isBusy)
                .help(current ? "Request hint \(level)" : used ? "Hint \(level) already shown" : "Hints unlock in order")
            }

            if tutor.canRevealSolution {
                Button {
                    Task { _ = await tutor.revealSolution() }
                } label: {
                    Text("Reveal")
                }
                .help("Explicitly request the complete solution")
            }
        }
        .buttonStyle(.plain)
        .zFont(12, weight: .medium, zoom: zoom)
        .foregroundStyle(AppTheme.secondaryText)
        .disabled(tutor.isBusy)
    }

    private func transcriptionConfirmation(_ pending: PendingMathTranscription) -> some View {
        VStack(alignment: .leading, spacing: 12 * zoom) {
            HStack {
                Label("Confirm extracted math", systemImage: "text.viewfinder")
                    .zFont(13, weight: .semibold, zoom: zoom)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text(pending.filename)
                    .zFont(11, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .lineLimit(1)
            }

            Text("Check every symbol before the tutor uses this as your \(pending.purpose == .problem ? "problem" : "step").")
                .zFont(13, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)

            TutorMathText(source: pending.text, fontSize: 16 * zoom)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14 * zoom)
                .background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 9 * zoom))
                .overlay {
                    RoundedRectangle(cornerRadius: 9 * zoom)
                        .stroke(AppTheme.strongStroke, lineWidth: 1)
                }
                .accessibilityLabel("Extracted math preview")

            Text("Edit the source if a symbol is wrong.")
                .zFont(12, zoom: zoom)
                .foregroundStyle(AppTheme.tertiaryText)

            TextEditor(text: Binding(
                get: { tutor.pendingTranscription?.text ?? "" },
                set: { tutor.updatePendingTranscription($0) }
            ))
            .font(.system(size: 13 * zoom, design: .monospaced))
            .foregroundStyle(AppTheme.secondaryText)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 64 * zoom)
            .padding(8 * zoom)
            .background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 9 * zoom))
            .overlay {
                RoundedRectangle(cornerRadius: 9 * zoom)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            }

            HStack(spacing: 10 * zoom) {
                Button("Cancel") { tutor.cancelTranscription() }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.secondaryText)

                Button("Use confirmed math") {
                    Task { _ = await tutor.confirmTranscription() }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primaryText)
                .foregroundStyle(AppTheme.inverseText)
                .disabled(tutor.isBusy)
            }
            .zFont(13, weight: .medium, zoom: zoom)
        }
        .padding(16 * zoom)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14 * zoom))
        .overlay {
            RoundedRectangle(cornerRadius: 14 * zoom)
                .stroke(AppTheme.strongStroke, lineWidth: 1)
        }
    }

    private func sendDraft() {
        let submittedDraft = draft
        let submittedAttachment = attachment
        let submittedIntent = resolvedIntent
        draft = ""
        attachment = nil
        Task {
            if await !tutor.submit(submittedDraft, attachment: submittedAttachment, intent: submittedIntent) {
                if draft.isEmpty { draft = submittedDraft }
                if attachment == nil { attachment = submittedAttachment }
            }
        }
    }
}

private struct TutorThinkingRow: View {
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        HStack(alignment: .center, spacing: 10 * zoom) {
            PracticeSpeakerMark(role: .tutor)
            HStack(spacing: 8 * zoom) {
                ProgressView()
                    .controlSize(.small)
                Text("Thinking")
                    .zFont(13, weight: .medium, zoom: zoom)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(.vertical, 4 * zoom)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tutor is thinking")
    }
}

private struct PracticeSpeakerMark: View {
    let role: TutorConversationEntry.Role
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        Image(systemName: role == .student ? "person.fill" : "function")
            .font(.system(size: 10 * zoom, weight: .semibold))
            .foregroundStyle(role == .student ? AppTheme.secondaryText : AppTheme.primaryText)
            .frame(width: 22 * zoom, height: 22 * zoom)
            .background(
                role == .student ? AppTheme.paper : AppTheme.elevated,
                in: Circle()
            )
            .overlay {
                Circle()
                    .stroke(AppTheme.stroke, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

private struct TutorConversationBubble: View {
    let entry: TutorConversationEntry
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        HStack(alignment: .top, spacing: 10 * zoom) {
            if entry.role == .tutor {
                PracticeSpeakerMark(role: .tutor)
            }

            content
                .frame(
                    maxWidth: (entry.role == .tutor ? AppTheme.composerMaxWidth : 560) * zoom,
                    alignment: entry.role == .student ? .trailing : .leading
                )

            if entry.role == .student {
                PracticeSpeakerMark(role: .student)
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: entry.role == .student ? .trailing : .leading
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySpeaker)
        .accessibilityValue(entry.text)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6 * zoom) {
            if !entry.kind.caption.isEmpty {
                Text(entry.kind.caption)
                    .zFont(11, weight: .semibold, zoom: zoom)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            if entry.role == .tutor, let status = entry.verificationStatus, entry.assessment != "not_assessed" {
                verificationBadge(status)
            }

            TutorMathText(source: entry.text, fontSize: entry.kind == .solution ? 16 * zoom : 15 * zoom)
                .lineSpacing(5)
        }
        .padding(entry.role == .student ? 12 * zoom : entry.kind == .solution ? 4 * zoom : 0)
        .background(
            entry.role == .student ? AppTheme.paper : Color.clear,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            if entry.role == .student {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            }
        }
    }

    private var accessibilitySpeaker: String {
        switch (entry.role, entry.kind) {
        case (.student, .problem):
            "You, Problem"
        case (.student, .step(let number)):
            "You, Step \(number)"
        case (.student, _):
            "You"
        case (.tutor, .hint(let level)):
            "Tutor, Hint \(level)"
        case (.tutor, .solution):
            "Tutor, Solution"
        case (.tutor, .problem), (.tutor, .step), (.tutor, .message):
            "Tutor"
        }
    }

    private func verificationBadge(_ status: TutorVerificationStatus) -> some View {
        let label: String
        let color: Color
        let symbol: String
        switch status {
        case .verified:
            label = "Symbolically verified"
            color = AppTheme.verified
            symbol = "checkmark.seal"
        case .modelJudged:
            label = "Agent assessment · not verified"
            color = AppTheme.caution
            symbol = "sparkles"
        case .inconclusive:
            label = "Verification inconclusive"
            color = AppTheme.secondaryText
            symbol = "questionmark.circle"
        }
        return Label(label, systemImage: symbol)
            .zFont(11, weight: .semibold, zoom: zoom)
            .foregroundStyle(color)
    }
}
