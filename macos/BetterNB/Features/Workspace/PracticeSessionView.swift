import SwiftUI
import UniformTypeIdentifiers

struct PracticeSessionView: View {
    let tutor: TutorSessionStore
    var onBackToStudy: () -> Void = {}
    @Environment(\.workspaceZoom) private var zoom
    @State private var draft = ""
    @State private var attachment: MessageAttachment?

    private var sheet: PracticeWorksheet { tutor.worksheet }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                if tutor.problem != nil, tutor.pendingTranscription == nil {
                    worksheetBar
                } else {
                    studyNavigationBar
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if let pending = tutor.pendingTranscription {
                                transcriptionConfirmation(pending)
                                    .padding(.horizontal, AppTheme.pagePadding * zoom)
                                    .padding(.top, 22 * zoom)
                                    .id("transcription")
                            } else if tutor.problem == nil, tutor.entries.isEmpty, !tutor.isBusy {
                                emptyState
                                    .padding(.horizontal, AppTheme.pagePadding * zoom)
                                    .padding(.top, 26 * zoom)
                            } else {
                                worksheet
                            }

                            if tutor.isBusy {
                                PracticeThinkingRow()
                                    .padding(.horizontal, AppTheme.pagePadding * zoom)
                                    .padding(.vertical, 14 * zoom)
                                    .id("thinking")
                            }
                        }
                        .padding(.bottom, 28 * zoom)
                        .frame(maxWidth: AppTheme.practiceMeasure * zoom, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: tutor.entries.count) { _, _ in
                        scroll(proxy)
                    }
                    .onChange(of: tutor.isBusy) { _, _ in
                        scroll(proxy)
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
            .frame(minWidth: 0, maxWidth: .infinity)

            if showsInspectorRail {
                Rectangle()
                    .fill(AppTheme.stroke)
                    .frame(width: 1)
                PracticeInspectorPane(
                    worksheet: sheet,
                    nextHintLevel: tutor.nextHintLevel,
                    canRevealSolution: tutor.canRevealSolution,
                    solutionRevealed: tutor.solutionRevealed,
                    isBusy: tutor.isBusy,
                    onHint: { Task { _ = await tutor.requestHint() } },
                    onReveal: { Task { _ = await tutor.revealSolution() } }
                )
                .frame(width: 244)
            }
        }
        .background(AppTheme.canvas)
    }

    private var showsInspectorRail: Bool {
        tutor.problem != nil || !tutor.entries.isEmpty
    }

    private var worksheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let problem = sheet.problem {
                problemBlock(problem)
            }

            ForEach(sheet.items) { item in
                switch item {
                case .step(let step):
                    PracticeStepRow(step: step)
                        .id(step.id)
                case .note(let note):
                    if note.title == "Solution" {
                        PracticeSolutionBlock(text: note.text)
                            .id(note.id)
                    } else {
                        annotationBlock(title: note.title, text: note.text, emphasized: note.emphasized)
                            .id(note.id)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func problemBlock(_ problem: String) -> some View {
        VStack(alignment: .leading, spacing: 10 * zoom) {
            HStack(alignment: .firstTextBaseline) {
                Text("Problem")
                    .zFont(11, weight: .semibold, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .textCase(.uppercase)
                Spacer(minLength: 8 * zoom)
                if !sheet.steps.isEmpty, sheet.steps.allSatisfy({ $0.status == .correct }) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.verified)
                        .font(.system(size: 13 * zoom))
                }
            }
            TutorMathText(source: problem, fontSize: 18 * zoom)
            if let source = sheet.inspector.sourceTitle {
                Text(sourceLine(source))
                    .zFont(12, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
        }
        .padding(.horizontal, AppTheme.pagePadding * zoom)
        .padding(.vertical, 22 * zoom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.stroke).frame(height: 1)
        }
    }

    private func sourceLine(_ title: String) -> String {
        if let section = sheet.inspector.sourceSection, !section.isEmpty {
            return "\(title) · \(section)"
        }
        return title
    }

    private func annotationBlock(title: String, text: String, emphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8 * zoom) {
            Text(title)
                .zFont(11, weight: .semibold, zoom: zoom)
                .foregroundStyle(AppTheme.tertiaryText)
                .textCase(.uppercase)
            TutorMathText(source: text, fontSize: emphasized ? 16 * zoom : 14 * zoom)
        }
        .padding(.horizontal, AppTheme.pagePadding * zoom)
        .padding(.vertical, 16 * zoom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(AppTheme.stroke).frame(height: 1)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18 * zoom) {
            Text("Work one problem as numbered steps.")
                .zFont(20, weight: .medium, zoom: zoom)
                .foregroundStyle(AppTheme.primaryText)
                .tracking(0.2)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 12 * zoom) {
                emptyStep("1", "Paste the problem, or open one from Problems.")
                emptyStep("2", "Write the next line. Math is checked when you send.")
                emptyStep("3", "Hints stay on a ladder. Reveal only if you ask.")
            }
        }
    }

    private func emptyStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12 * zoom) {
            Text(number)
                .zFont(13, weight: .semibold, zoom: zoom)
                .foregroundStyle(AppTheme.tertiaryText)
                .frame(width: 18 * zoom, alignment: .leading)
            Text(text)
                .zFont(15, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
                .tracking(0.2)
                .lineSpacing(4 * zoom)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var worksheetBar: some View {
        HStack(spacing: 12 * zoom) {
            backToStudyButton

            VStack(alignment: .leading, spacing: 2 * zoom) {
                Text("Practice · Problem")
                    .zFont(12, weight: .medium, zoom: zoom)
                    .foregroundStyle(AppTheme.secondaryText)
                Text(sheet.inspector.totalCount == 0
                    ? "No steps checked"
                    : "\(sheet.inspector.checkedCount) / \(sheet.inspector.totalCount) checked")
                    .zFont(11, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            ProgressView(
                value: Double(sheet.inspector.checkedCount),
                total: Double(max(sheet.inspector.totalCount, 1))
            )
            .tint(AppTheme.verified)
            .frame(maxWidth: 120 * zoom)

            Spacer(minLength: 8 * zoom)

            Button {
                tutor.reset()
                draft = ""
                attachment = nil
                onBackToStudy()
            } label: {
                Label("New problem", systemImage: "plus")
                    .zFont(12, weight: .semibold, zoom: zoom)
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 11 * zoom)
                    .frame(height: 30 * zoom)
                    .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 7 * zoom))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7 * zoom)
                            .stroke(AppTheme.strongStroke, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(tutor.isBusy)
            .opacity(tutor.isBusy ? 0.55 : 1)
        }
        .padding(.horizontal, AppTheme.pagePadding * zoom)
        .padding(.vertical, 10 * zoom)
        .background(AppTheme.panel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.stroke).frame(height: 1)
        }
    }

    private var studyNavigationBar: some View {
        HStack {
            backToStudyButton
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.pagePadding * zoom)
        .frame(height: 42 * zoom)
        .background(AppTheme.panel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.stroke).frame(height: 1)
        }
    }

    private var backToStudyButton: some View {
        Button(action: onBackToStudy) {
            Image(systemName: "chevron.left")
                .zFont(11, weight: .semibold, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
                .frame(width: 26 * zoom, height: 26 * zoom)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to Study desk")
        .help("Back to Study desk")
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10 * zoom) {
            if let error = tutor.errorMessage {
                Text(error)
                    .zFont(12, zoom: zoom)
                    .foregroundStyle(AppTheme.critical)
            }

            PromptComposer(
                draft: $draft,
                attachment: $attachment,
                placeholder: composerPlaceholder,
                allowedContentTypes: [.png, .jpeg],
                attachmentDescription: "a PNG or JPEG image"
            ) {
                sendDraft(as: .automatic)
            }
            .disabled(tutor.pendingTranscription != nil)
            .opacity(tutor.pendingTranscription == nil ? 1 : 0.55)
            .allowsHitTesting(!tutor.isBusy)
        }
        .frame(maxWidth: AppTheme.practiceMeasure * zoom, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.pagePadding * zoom)
        .padding(.top, 10 * zoom)
        .padding(.bottom, 20 * zoom)
    }

    private var composerPlaceholder: String {
        if tutor.problem == nil {
            return "Paste a problem, or write the first line"
        }
        return "Write the next step, or ask a question"
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

    private func sendDraft(as submittedIntent: TutorSubmitIntent) {
        let submittedDraft = draft
        let submittedAttachment = attachment
        draft = ""
        attachment = nil
        Task {
            if await !tutor.submit(submittedDraft, attachment: submittedAttachment, intent: submittedIntent) {
                if draft.isEmpty { draft = submittedDraft }
                if attachment == nil { attachment = submittedAttachment }
            }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if tutor.isBusy {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let solution = sheet.latestSolution {
                proxy.scrollTo(solution.id, anchor: .top)
            } else if let last = sheet.items.last?.id {
                proxy.scrollTo(last, anchor: .bottom)
            }
        }
    }
}

private struct PracticeStepRow: View {
    let step: PracticeWorksheetStep
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * zoom) {
            HStack(alignment: .top, spacing: 14 * zoom) {
                Text("Step \(step.number)")
                    .zFont(12, weight: .medium, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .frame(width: 58 * zoom, alignment: .leading)

                TutorMathText(source: step.text, fontSize: 16 * zoom, compact: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                statusMark
            }

            if step.isFocus, let feedback = step.feedback {
                VStack(alignment: .leading, spacing: 6 * zoom) {
                    Text(step.status == .incorrect ? "First break" : "Check")
                        .zFont(11, weight: .semibold, zoom: zoom)
                        .foregroundStyle(AppTheme.coach)
                        .textCase(.uppercase)
                    TutorMathText(source: feedback, fontSize: 13 * zoom, color: AppTheme.primaryText, compact: true)
                }
                .padding(12 * zoom)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.coachFill, in: RoundedRectangle(cornerRadius: 10 * zoom, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10 * zoom, style: .continuous)
                        .stroke(AppTheme.coach.opacity(0.35), lineWidth: 1)
                }
                .padding(.leading, 72 * zoom)
            }
        }
        .padding(.horizontal, AppTheme.pagePadding * zoom)
        .padding(.vertical, 16 * zoom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(step.isFocus && step.status == .incorrect ? AppTheme.critical.opacity(0.06) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.stroke).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step.number), \(statusLabel)")
        .accessibilityValue(step.text)
    }

    @ViewBuilder
    private var statusMark: some View {
        switch step.status {
        case .correct:
            Image(systemName: "checkmark")
                .font(.system(size: 12 * zoom, weight: .semibold))
                .foregroundStyle(AppTheme.verified)
        case .incorrect:
            Image(systemName: "xmark")
                .font(.system(size: 12 * zoom, weight: .semibold))
                .foregroundStyle(AppTheme.critical)
        case .pending:
            ProgressView()
                .controlSize(.mini)
        case .unchecked:
            Circle()
                .stroke(AppTheme.stroke, lineWidth: 1)
                .frame(width: 12 * zoom, height: 12 * zoom)
        }
    }

    private var statusLabel: String {
        switch step.status {
        case .correct: "correct"
        case .incorrect: "incorrect"
        case .pending: "checking"
        case .unchecked: "not checked"
        }
    }
}

private struct PracticeSolutionBlock: View {
    let text: String
    @Environment(\.workspaceZoom) private var zoom

    private var layout: RevealedSolutionLayout { RevealedSolutionLayout(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18 * zoom) {
            HStack(spacing: 8 * zoom) {
                Image(systemName: "checkmark.seal.fill")
                    .zFont(13, weight: .semibold, zoom: zoom)
                    .foregroundStyle(AppTheme.verified)
                Text("Full solution")
                    .zFont(12, weight: .semibold, zoom: zoom)
                    .foregroundStyle(AppTheme.primaryText)
                    .textCase(.uppercase)
            }

            if let introduction = layout.introduction {
                TutorMathText(source: introduction, fontSize: 14 * zoom)
            }

            if layout.steps.isEmpty {
                if layout.introduction == nil {
                    TutorMathText(source: text, fontSize: 15 * zoom)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(layout.steps) { step in
                        HStack(alignment: .top, spacing: 14 * zoom) {
                            Text("\(step.number)")
                                .zFont(12, weight: .semibold, zoom: zoom)
                                .foregroundStyle(AppTheme.primaryText)
                                .frame(width: 26 * zoom, height: 26 * zoom)
                                .background(AppTheme.elevated, in: Circle())
                                .overlay {
                                    Circle().stroke(AppTheme.strongStroke, lineWidth: 1)
                                }

                            VStack(alignment: .leading, spacing: 9 * zoom) {
                                if !step.textWithoutBoxedAnswer.isEmpty {
                                    TutorMathText(source: step.textWithoutBoxedAnswer, fontSize: 15 * zoom)
                                }
                                if let answer = step.boxedAnswer {
                                    TutorMathText(source: answer, fontSize: 16 * zoom)
                                        .padding(.horizontal, 12 * zoom)
                                        .padding(.vertical, 9 * zoom)
                                        .background(
                                            AppTheme.elevated,
                                            in: RoundedRectangle(cornerRadius: 8 * zoom)
                                        )
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8 * zoom)
                                                .stroke(AppTheme.verified.opacity(0.55), lineWidth: 1)
                                        }
                                        .accessibilityLabel("Final answer, \(answer)")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 12 * zoom)
                        .overlay(alignment: .bottom) {
                            if step.id != layout.steps.last?.id {
                                Rectangle()
                                    .fill(AppTheme.stroke)
                                    .frame(height: 1)
                                    .padding(.leading, 40 * zoom)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppTheme.pagePadding * zoom)
        .padding(.vertical, 18 * zoom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.verified.opacity(0.035))
        .overlay(alignment: .top) {
            Rectangle().fill(AppTheme.stroke).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Full solution")
    }
}

private struct PracticeInspectorPane: View {
    let worksheet: PracticeWorksheet
    let nextHintLevel: Int?
    let canRevealSolution: Bool
    let solutionRevealed: Bool
    let isBusy: Bool
    let onHint: () -> Void
    let onReveal: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                guidanceActions

                Divider()
                    .overlay(AppTheme.stroke)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Step check")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .textCase(.uppercase)
                    Text(worksheet.inspector.totalCount == 0
                        ? "—"
                        : "\(worksheet.inspector.checkedCount) / \(worksheet.inspector.totalCount)")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                    ProgressView(
                        value: Double(worksheet.inspector.checkedCount),
                        total: Double(max(worksheet.inspector.totalCount, 1))
                    )
                    .tint(verdictColor)
                    Text(worksheet.inspector.totalCount == 0 ? "No steps checked" : "Checked so far")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.tertiaryText)
                }

                if worksheet.inspector.note == nil, worksheet.inspector.verdict == nil {
                    Text("A checked step will show the verdict here.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let verdict = worksheet.inspector.verdict {
                    inspectorField("Verdict", verdict)
                }
                if let error = worksheet.inspector.errorType {
                    inspectorField("Error type", error)
                }
                if let title = worksheet.inspector.sourceTitle {
                    let detail = [title, worksheet.inspector.sourceSection].compactMap { $0 }.joined(separator: " · ")
                    inspectorField("Course source", detail)
                }
                if let note = worksheet.inspector.note {
                    inspectorField(
                        worksheet.inspector.noteCaption.isEmpty ? "Summary" : worksheet.inspector.noteCaption,
                        note
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.panel)
        .environment(\.workspaceZoom, 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Guidance and step check")
    }

    private var guidanceActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Guidance")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.tertiaryText)
                .textCase(.uppercase)

            if solutionRevealed {
                Label("Solution revealed", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.verified)
                    .padding(.vertical, 4)
            } else {
                Text("Stay moving without leaving the worksheet.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let level = nextHintLevel {
                    railButton(
                        "Hint \(level)",
                        systemImage: "lightbulb",
                        primary: true,
                        action: onHint
                    )
                }

                if canRevealSolution {
                    railButton(
                        "Reveal solution",
                        systemImage: "eye",
                        primary: false,
                        action: onReveal
                    )
                }
            }
        }
    }

    private func railButton(
        _ title: String,
        systemImage: String,
        primary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(primary ? AppTheme.inverseText : AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(
                    primary ? AppTheme.primaryText : AppTheme.elevated,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(primary ? Color.clear : AppTheme.strongStroke, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.55 : 1)
    }

    private var verdictColor: Color {
        switch worksheet.inspector.verdict {
        case "Correct": AppTheme.verified
        case "Incorrect": AppTheme.critical
        default: AppTheme.tertiaryText
        }
    }

    private func inspectorField(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.tertiaryText)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PracticeThinkingRow: View {
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        HStack(spacing: 10 * zoom) {
            ProgressView()
                .controlSize(.small)
            Text("Checking")
                .zFont(13, weight: .medium, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tutor is checking")
    }
}
