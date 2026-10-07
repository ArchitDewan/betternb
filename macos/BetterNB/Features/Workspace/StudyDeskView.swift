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

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22 * zoom) {
                    pageHeading
                    continuation
                    studyActions
                    askSection
                        .id("ask-lemma")
                }
                .frame(maxWidth: 1080 * zoom, alignment: .leading)
                .padding(.horizontal, LemmaSpacing.page * zoom)
                .padding(.top, 18 * zoom)
                .padding(.bottom, 40 * zoom)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .onChange(of: composerFocusRequest) { _, _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo("ask-lemma", anchor: .center)
                }
            }
        }
        .background(Color.clear)
    }

    private var pageHeading: some View {
        HStack(alignment: .top, spacing: 16 * zoom) {
            VStack(alignment: .leading, spacing: 7 * zoom) {
                Text("Course workspace")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.textTertiary)
                Text("Calculus I")
                    .font(LemmaTypography.pageTitle(zoom))
                    .foregroundStyle(LemmaColors.textPrimary)
                Text(recentThreads.isEmpty
                     ? "Find a starting point, or ask a question from your course material."
                     : "Continue where you left off, or explore a new idea.")
                    .font(LemmaTypography.body(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
            }
            Spacer(minLength: 0)
            Button(action: onManageSources) {
                Label("\(sourceCount) \(sourceCount == 1 ? "source" : "sources")", systemImage: "books.vertical")
                    .font(.system(size: 12 * zoom, weight: .medium))
                    .foregroundStyle(LemmaColors.textTertiary)
                    .padding(.horizontal, 8 * zoom)
                    .frame(height: 28 * zoom)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Manage course sources, \(sourceCount) added")
        }
    }

    private var continuation: some View {
        VStack(alignment: .leading, spacing: 8 * zoom) {
            Text("Continue")
                .font(LemmaTypography.caption(zoom))
                .foregroundStyle(LemmaColors.textTertiary)
            Text(recentThreads.first?.title ?? "A place to begin")
                .font(LemmaTypography.conceptTitle(zoom))
                .foregroundStyle(LemmaColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(continuationContext)
                .font(LemmaTypography.body(zoom))
                .foregroundStyle(LemmaColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: openContinuation) {
                HStack(spacing: 6 * zoom) {
                    Text(recentThreads.isEmpty ? "Browse problems" : "Continue")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11 * zoom, weight: .semibold))
                }
                .font(.system(size: 13 * zoom, weight: .medium))
                .foregroundStyle(LemmaColors.accent)
                .padding(.top, 4 * zoom)
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .contain)
    }

    private var continuationContext: String {
        guard let thread = recentThreads.first else {
            return "Your questions, problems, and course sources belong together here."
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
        } else {
            onOpenProblems()
        }
    }

    private var studyActions: some View {
        VStack(alignment: .leading, spacing: 6 * zoom) {
            Text("Study")
                .font(LemmaTypography.caption(zoom))
                .foregroundStyle(LemmaColors.textTertiary)
            HStack(spacing: 2 * zoom) {
                LemmaStudyAction(title: "Review", symbol: "clock.arrow.circlepath", action: onOpenReview)
                LemmaStudyAction(
                    title: "Practice",
                    detail: "\(problemCount) saved",
                    symbol: "function",
                    action: onOpenProblems
                )
                LemmaStudyAction(title: "Formula sheet", symbol: "sum", action: onOpenFormulaSheet)
                LemmaStudyAction(title: "Ask Lemma", symbol: "sparkle.magnifyingglass") {
                    composerFocusRequest = UUID()
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var askSection: some View {
        VStack(alignment: .leading, spacing: 10 * zoom) {
            HStack(alignment: .firstTextBaseline, spacing: 10 * zoom) {
                Text("Ask Lemma")
                    .font(LemmaTypography.ui(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
                Text("Grounded in your course sources")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.textTertiary)
                Spacer(minLength: 0)
            }
            PromptComposer(
                draft: $draft,
                attachment: $attachment,
                placeholder: "Ask anything about Calculus I…",
                allowedContentTypes: [.png, .jpeg],
                attachmentDescription: "a PNG or JPEG homework image",
                focusRequest: composerFocusRequest
            ) {
                prepareSubmission()
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
            Text("Lemma extracts text, builds a semantic index, and keeps answers tied to the pages it used. Scanned PDFs need OCR and are not supported yet.")
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
                Text("\(source.pageCount) pages · \(source.chunkCount) indexed sections")
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
