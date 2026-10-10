import SwiftUI
import UniformTypeIdentifiers

struct StudyDeskView: View {
    let sourceCount: Int
    let problemCount: Int
    let recentThreads: [StudyThreadSummary]
    let totalThreadCount: Int
    let onManageSources: () -> Void
    let onOpenProblems: () -> Void
    let onOpenReview: () -> Void
    let onOpenFormulaSheet: () -> Void
    let onOpenThread: (UUID) -> Void
    let onShowAllThreads: () -> Void
    let onAskCourse: (String) -> Void
    let onStartProblem: (String, MessageAttachment?) -> Void

    @Environment(\.workspaceZoom) private var zoom
    @State private var draft = ""
    @State private var attachment: MessageAttachment?
    @State private var composerFocusRequest = UUID()
    @State private var composerBlurRequest = UUID()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 30 * zoom) {
                    pageHeading
                        .onTapGesture { composerBlurRequest = UUID() }
                    continuation
                        .onTapGesture { composerBlurRequest = UUID() }
                    studyActions
                        .onTapGesture { composerBlurRequest = UUID() }
                    askSection
                        .id("ask-lemma")
                    if !recentThreads.isEmpty {
                        recentStudy
                    }
                }
                .frame(maxWidth: 980 * zoom, alignment: .leading)
                .padding(.horizontal, LemmaSpacing.page * zoom)
                .padding(.top, 38 * zoom)
                .padding(.bottom, 70 * zoom)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .contentShape(Rectangle())
            .onTapGesture { composerBlurRequest = UUID() }
            .onChange(of: composerFocusRequest) { _, _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo("ask-lemma", anchor: .center)
                }
            }
        }
        .background(Color.clear)
    }

    private var pageHeading: some View {
        HStack(alignment: .top, spacing: 20 * zoom) {
            VStack(alignment: .leading, spacing: 9 * zoom) {
                Text("COURSE WORKSPACE")
                    .font(.system(size: 11 * zoom, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(LemmaColors.accent)
                Text("Calculus I")
                    .font(.system(size: 34 * zoom, weight: .semibold))
                    .foregroundStyle(LemmaColors.textPrimary)
                Text(recentThreads.isEmpty
                     ? "Make sense of a new idea, one step at a time."
                     : "Pick up where you left off, or follow a new question.")
                    .font(LemmaTypography.body(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
            }
            Spacer(minLength: 0)
            Button(action: onManageSources) {
                Label("\(sourceCount) \(sourceCount == 1 ? "source" : "sources")", systemImage: "books.vertical")
                    .font(.system(size: 12 * zoom, weight: .medium))
                    .foregroundStyle(LemmaColors.textSecondary)
                    .padding(.horizontal, 12 * zoom)
                    .frame(height: 32 * zoom)
                    .background(LemmaColors.hoverWash,
                                in: RoundedRectangle(cornerRadius: LemmaRadius.control * zoom))
                    .overlay(RoundedRectangle(cornerRadius: LemmaRadius.control * zoom)
                        .stroke(LemmaColors.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Manage course sources, \(sourceCount) added")
        }
    }

    private var continuation: some View {
        ViewThatFits(in: .horizontal) {
            continuationContent(showMotif: true)
            continuationContent(showMotif: false)
        }
        .padding(24 * zoom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LemmaColors.surfaceElevated.opacity(0.46),
                    in: RoundedRectangle(cornerRadius: LemmaRadius.card * zoom))
        .overlay {
            RoundedRectangle(cornerRadius: LemmaRadius.card * zoom)
                .stroke(LemmaColors.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func continuationContent(showMotif: Bool) -> some View {
        HStack(alignment: .center, spacing: 22 * zoom) {
            VStack(alignment: .leading, spacing: 13 * zoom) {
                Text(recentThreads.isEmpty ? "YOUR NEXT STEP" : "CONTINUE LEARNING")
                    .font(.system(size: 11 * zoom, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(LemmaColors.accent)
                Text(recentThreads.first?.title ?? emptyContinuationTitle)
                    .font(.system(size: 23 * zoom, weight: .semibold))
                    .foregroundStyle(LemmaColors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(continuationContext)
                    .font(LemmaTypography.ui(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14 * zoom) {
                    Button {
                        openContinuation()
                    } label: {
                        HStack(spacing: 8 * zoom) {
                            Text(recentThreads.isEmpty ? emptyContinuationAction : "Continue")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 13 * zoom, weight: .semibold))
                        .foregroundStyle(LemmaColors.onAccent)
                        .padding(.horizontal, 15 * zoom)
                        .frame(height: 35 * zoom)
                        .background(LemmaColors.accent,
                                    in: RoundedRectangle(cornerRadius: LemmaRadius.control * zoom))
                    }
                    .buttonStyle(.plain)
                    if recentThreads.isEmpty {
                        Button(problemCount > 0 ? "Ask Lemma" : "Browse problems") {
                            if problemCount > 0 {
                                composerFocusRequest = UUID()
                            } else {
                                onOpenProblems()
                            }
                        }
                        .font(.system(size: 13 * zoom, weight: .medium))
                        .foregroundStyle(LemmaColors.textSecondary)
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showMotif {
                LemmaKnowledgeMotif()
                    .frame(width: 190 * zoom)
            }
        }
    }

    private var continuationContext: String {
        guard let thread = recentThreads.first else {
            if problemCount > 0 { return "Your saved problems are ready for another attempt." }
            if sourceCount == 0 { return "Add a PDF to read, question, and study beside your notes." }
            return "Explore a concept or ask about the material you've added."
        }
        switch thread.kind {
        case .practice:
            return "Practice is open, with your earlier steps intact."
        case .courseQuestion:
            return "This course question is ready to continue."
        }
    }

    private func openContinuation() {
        if let thread = recentThreads.first {
            onOpenThread(thread.id)
        } else if problemCount > 0 {
            onOpenProblems()
        } else if sourceCount == 0 {
            onManageSources()
        } else {
            composerFocusRequest = UUID()
        }
    }

    private var emptyContinuationTitle: String {
        if problemCount > 0 { return "Work through a problem" }
        return sourceCount == 0 ? "Bring in your course material" : "Start with a question"
    }

    private var emptyContinuationAction: String {
        if problemCount > 0 { return "Open problems" }
        return sourceCount == 0 ? "Add a PDF" : "Ask Lemma"
    }

    private var studyActions: some View {
        VStack(alignment: .leading, spacing: 14 * zoom) {
            LemmaSectionHeader(title: "Your workspace", detail: "Tools for the next step")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 205 * zoom), spacing: 10 * zoom)], spacing: 10 * zoom) {
                workspaceAction("Sources", detail: "\(sourceCount) added", symbol: "books.vertical", tint: LemmaColors.toolSummary, action: onManageSources)
                workspaceAction("Problems", detail: "\(problemCount) saved", symbol: "function", tint: LemmaColors.toolQuiz, action: onOpenProblems)
                workspaceAction("Review", detail: "Revisit an idea", symbol: "clock.arrow.circlepath", tint: LemmaColors.toolChat, action: onOpenReview)
                workspaceAction("Formula sheet", detail: "Keep methods close", symbol: "sum", tint: LemmaColors.toolFlashcards, action: onOpenFormulaSheet)
            }
        }
    }

    private func workspaceAction(_ title: String, detail: String, symbol: String, tint: Color,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12 * zoom) {
                Image(systemName: symbol)
                    .font(.system(size: 16 * zoom, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 34 * zoom, height: 34 * zoom)
                    .background(tint.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 9 * zoom))
                VStack(alignment: .leading, spacing: 3 * zoom) {
                    Text(title)
                        .font(.system(size: 13 * zoom, weight: .semibold))
                        .foregroundStyle(LemmaColors.textPrimary)
                    Text(detail)
                        .font(.system(size: 11 * zoom))
                        .foregroundStyle(LemmaColors.textTertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10 * zoom, weight: .medium))
                    .foregroundStyle(LemmaColors.textTertiary)
            }
            .padding(12 * zoom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LemmaColors.hoverWash,
                        in: RoundedRectangle(cornerRadius: LemmaRadius.control * zoom))
            .overlay(RoundedRectangle(cornerRadius: LemmaRadius.control * zoom)
                .stroke(LemmaColors.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(detail)")
    }

    private var askSection: some View {
        VStack(alignment: .leading, spacing: 14 * zoom) {
            LemmaSectionHeader(title: "Ask Lemma", detail: sourceCount == 0
                               ? "Add a source for course-grounded answers"
                               : "Explore a question from your course material")
            PromptComposer(
                draft: $draft,
                attachment: $attachment,
                placeholder: "Ask anything about Calculus I…",
                allowedContentTypes: [.png, .jpeg],
                attachmentDescription: "a PNG or JPEG homework image",
                focusRequest: composerFocusRequest,
                blurRequest: composerBlurRequest
            ) {
                prepareSubmission()
            }
        }
    }

    private var recentStudy: some View {
        VStack(alignment: .leading, spacing: 12 * zoom) {
            HStack {
                LemmaSectionHeader(title: "Recent study", detail: "Pick up a thread")
                Button("View all", action: onShowAllThreads)
                    .font(.system(size: 12 * zoom, weight: .medium))
                    .foregroundStyle(LemmaColors.accent)
                    .buttonStyle(.plain)
            }
            ForEach(recentThreads) { thread in
                Button { onOpenThread(thread.id) } label: {
                    HStack(spacing: 10 * zoom) {
                        Image(systemName: thread.kind == .practice ? "function" : "bubble.left")
                            .foregroundStyle(LemmaColors.accent)
                            .frame(width: 20 * zoom)
                        Text(thread.title)
                            .font(LemmaTypography.ui(zoom))
                            .foregroundStyle(LemmaColors.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10 * zoom))
                            .foregroundStyle(LemmaColors.textTertiary)
                    }
                    .padding(.vertical, 8 * zoom)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func prepareSubmission() {
        guard let route = StudyDeskInputRouter.route(for: draft, attachment: attachment) else {
            return
        }
        let submittedText = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let submittedAttachment = attachment
        clearComposer()
        switch route {
        case .startProblem:
            onStartProblem(submittedText, submittedAttachment)
        case .askCourse, .choose:
            onAskCourse(submittedText)
        }
    }

    private func clearComposer() {
        draft = ""
        attachment = nil
    }
}

struct WorkspaceHomeView: View {
    let onOpenCalculus: () -> Void
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 27 * zoom) {
                VStack(alignment: .leading, spacing: 8 * zoom) {
                    Text("Your workspace")
                        .font(LemmaTypography.caption(zoom))
                        .foregroundStyle(LemmaColors.textTertiary)
                    Text("A place for the ideas that stay with you.")
                        .font(LemmaTypography.pageTitle(zoom))
                        .foregroundStyle(LemmaColors.textPrimary)
                    Text("Choose a course to continue learning.")
                        .font(LemmaTypography.body(zoom))
                        .foregroundStyle(LemmaColors.textSecondary)
                }

                LemmaSectionHeader(title: "Your courses")

                Button(action: onOpenCalculus) {
                    HStack(spacing: 20 * zoom) {
                        VStack(alignment: .leading, spacing: 11 * zoom) {
                            Text("Active course")
                                .font(LemmaTypography.caption(zoom))
                                .foregroundStyle(LemmaColors.textTertiary)
                            Text("Calculus I")
                                .font(LemmaTypography.conceptTitle(zoom))
                                .foregroundStyle(LemmaColors.textPrimary)
                            Text("Problems, sources, and study threads in one place.")
                                .font(LemmaTypography.body(zoom))
                                .foregroundStyle(LemmaColors.textSecondary)
                            Label("Open course", systemImage: "arrow.right")
                                .font(.system(size: 12 * zoom, weight: .semibold))
                                .foregroundStyle(LemmaColors.accent)
                                .padding(.top, 5 * zoom)
                        }
                        Spacer(minLength: 0)
                        LemmaKnowledgeMotif()
                    }
                    .padding(LemmaSpacing.card * zoom)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LemmaColors.surface,
                                in: RoundedRectangle(cornerRadius: LemmaRadius.card * zoom))
                    .overlay {
                        RoundedRectangle(cornerRadius: LemmaRadius.card * zoom)
                            .stroke(LemmaColors.border, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)

                Text("Linear Algebra · Coming next")
                    .font(.system(size: 12 * zoom))
                    .foregroundStyle(LemmaColors.textTertiary)
                    .padding(.leading, 4 * zoom)
            }
            .frame(maxWidth: 1080 * zoom, alignment: .leading)
            .padding(.horizontal, LemmaSpacing.page * zoom)
            .padding(.top, 22 * zoom)
            .padding(.bottom, 60 * zoom)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }
}

struct CourseSourcesView: View {
    let store: CourseSourceStore
    let onGeneratedProblems: ([GeneratedCourseProblem]) -> Void

    @Environment(\.workspaceZoom) private var zoom
    @Environment(\.dismiss) private var dismiss
    @State private var isImporterPresented = false
    @State private var generatedMessage: String?
    @State private var review = GeneratedProblemReviewStore()
    @State private var editingDraftIDs: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 18 * zoom) {
            HStack(alignment: .top, spacing: 12 * zoom) {
                Image(systemName: "books.vertical")
                    .zFont(18, weight: .medium, zoom: zoom)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 36 * zoom, height: 36 * zoom)
                    .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 9 * zoom))

                VStack(alignment: .leading, spacing: 5 * zoom) {
                    Text("Course sources")
                        .zFont(20, weight: .semibold, zoom: zoom)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Master resources for Calculus I")
                        .zFont(13, zoom: zoom)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer(minLength: 0)

                Button {
                    isImporterPresented = true
                } label: {
                    Label(store.isImporting ? "Indexing…" : "Add PDF", systemImage: "plus")
                        .zFont(12, weight: .semibold, zoom: zoom)
                        .foregroundStyle(AppTheme.inverseText)
                        .padding(.horizontal, 12 * zoom)
                        .frame(height: 30 * zoom)
                        .background(AppTheme.primaryText, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(store.isImporting)

                Button(action: dismiss.callAsFunction) {
                    Image(systemName: "xmark")
                        .zFont(11, weight: .semibold, zoom: zoom)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 30 * zoom, height: 30 * zoom)
                        .background(AppTheme.elevated, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close course sources")
            }

            if let error = store.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .zFont(12, zoom: zoom)
                    .foregroundStyle(AppTheme.critical)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8 * zoom) {
                    if store.sources.isEmpty, !store.isLoading {
                        emptyState
                    } else {
                        ForEach(store.sources) { source in
                            sourceRow(source)
                        }
                    }
                    if !review.drafts.isEmpty {
                        Text("Review generated problems")
                            .zFont(13, weight: .semibold, zoom: zoom)
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(.top, 12 * zoom)
                        ForEach(review.drafts) { draft in
                            HStack(alignment: .top, spacing: 8 * zoom) {
                                Toggle("Save", isOn: Binding(
                                    get: { review.drafts.first(where: { $0.id == draft.id })?.isSelected ?? false },
                                    set: { _ in review.toggleSelection(draft.id) }
                                ))
                                .labelsHidden()
                                VStack(alignment: .leading, spacing: 8 * zoom) {
                                    if editingDraftIDs.contains(draft.id) {
                                        TextField("Problem prompt", text: Binding(
                                            get: { review.drafts.first(where: { $0.id == draft.id })?.prompt ?? "" },
                                            set: { review.updatePrompt(draft.id, to: $0) }
                                        ), axis: .vertical)
                                        .lineLimit(2...6)
                                        .textFieldStyle(.plain)
                                        .zFont(12, zoom: zoom)
                                        .foregroundStyle(AppTheme.primaryText)
                                        Text("Preview")
                                            .zFont(10, zoom: zoom)
                                            .foregroundStyle(AppTheme.tertiaryText)
                                    }
                                    TutorMathText(
                                        source: review.drafts.first(where: { $0.id == draft.id })?.prompt ?? draft.prompt,
                                        fontSize: 12 * zoom
                                    )
                                    Button(editingDraftIDs.contains(draft.id) ? "Done editing" : "Edit prompt") {
                                        if editingDraftIDs.contains(draft.id) {
                                            editingDraftIDs.remove(draft.id)
                                        } else {
                                            editingDraftIDs.insert(draft.id)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .zFont(11, zoom: zoom)
                                    .foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                            .padding(10 * zoom)
                            .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 8 * zoom))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 10 * zoom) {
                VStack(alignment: .leading, spacing: 2 * zoom) {
                    Text("Build a practice set")
                        .zFont(13, weight: .semibold, zoom: zoom)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(generatedMessage ?? "Generate drafts from PDFs, then choose what to save.")
                        .zFont(11, zoom: zoom)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                Spacer(minLength: 0)
                if review.drafts.isEmpty {
                    Button(store.isGenerating ? "Creating…" : "Create drafts") {
                        Task {
                            let generated = await store.generateProblems(count: 3)
                            review.load(generated)
                            if !generated.isEmpty { generatedMessage = "Review and save selected drafts." }
                        }
                    }
                    .disabled(store.sources.isEmpty || store.isGenerating)
                } else {
                    Button("Discard") {
                        review.discard()
                        editingDraftIDs.removeAll()
                    }
                    Button("Save selected") {
                        let selected = review.selectedProblems
                        onGeneratedProblems(selected)
                        review.discard()
                        editingDraftIDs.removeAll()
                        generatedMessage = "Saved \(selected.count) problems to Problems."
                    }
                    .disabled(review.selectedProblems.isEmpty)
                }
            }
            .padding(14 * zoom)
            .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 12 * zoom))
            .overlay { RoundedRectangle(cornerRadius: 12 * zoom).stroke(AppTheme.stroke, lineWidth: 1) }
        }
        .padding(22 * zoom)
        .frame(width: 600 * zoom, height: 520 * zoom, alignment: .topLeading)
        .background(AppTheme.panel)
        .task { await store.refresh() }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            Task {
                do {
                    let attachment = try await Task.detached {
                        try MessageAttachment.importing(url)
                    }.value
                    _ = await store.importPDF(attachment)
                } catch {
                    // The store reports service failures; local file validation remains concise here.
                    generatedMessage = "That PDF couldn’t be opened."
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 9 * zoom) {
            Image(systemName: "doc.text.magnifyingglass")
                .zFont(20, weight: .medium, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
            Text("Add your first course PDF")
                .zFont(15, weight: .semibold, zoom: zoom)
                .foregroundStyle(AppTheme.primaryText)
            Text("Add a PDF with selectable text for cited Study answers. For scanned worksheets or photos, upload them in Problems.")
                .zFont(13, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18 * zoom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 12 * zoom))
        .overlay { RoundedRectangle(cornerRadius: 12 * zoom).stroke(AppTheme.stroke, lineWidth: 1) }
    }

    private func sourceRow(_ source: CourseSourceRecord) -> some View {
        HStack(spacing: 11 * zoom) {
            Image(systemName: "doc.richtext")
                .zFont(14, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
                .frame(width: 30 * zoom, height: 30 * zoom)
                .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 8 * zoom))
            VStack(alignment: .leading, spacing: 3 * zoom) {
                Text(source.filename)
                    .zFont(13, weight: .medium, zoom: zoom)
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Text("\(source.pageCount) \(source.pageCount == 1 ? "page" : "pages") · \(source.chunkCount) indexed sections")
                    .zFont(11, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.verified)
        }
        .padding(.horizontal, 12 * zoom)
        .frame(height: 52 * zoom)
        .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 10 * zoom))
        .overlay { RoundedRectangle(cornerRadius: 10 * zoom).stroke(AppTheme.stroke, lineWidth: 1) }
    }
}
