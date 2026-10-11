import SwiftUI
import UniformTypeIdentifiers

struct StudyDeskView: View {
    let courseTitle: String
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
                Text(courseTitle)
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
            continuationContent(showMotif: courseTitle == "Calculus I")
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
                workspaceAction("Course materials", detail: "\(sourceCount) added", symbol: "books.vertical", tint: LemmaColors.toolSummary, action: onManageSources)
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
                placeholder: "Ask anything about \(courseTitle)…",
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
    let notebooks: [CourseNotebook]
    let activeNotebookID: String
    let onOpenNotebook: (String) -> Void
    let onCreateNotebook: () -> Void
    let onRequestRenameNotebook: (CourseNotebook) -> Void
    let onRequestDeleteNotebook: (CourseNotebook) -> Void
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28 * zoom) {
                HStack(alignment: .bottom, spacing: 18 * zoom) {
                    VStack(alignment: .leading, spacing: 8 * zoom) {
                        Text("YOUR WORKSPACE")
                            .font(.system(size: 11 * zoom, weight: .semibold, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(LemmaColors.accent)
                        Text("Your notebooks")
                            .font(LemmaTypography.pageTitle(zoom))
                            .foregroundStyle(LemmaColors.textPrimary)
                        Text("Keep each course and its work together.")
                            .font(LemmaTypography.body(zoom))
                            .foregroundStyle(LemmaColors.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Button(action: onCreateNotebook) {
                        Label("New notebook", systemImage: "plus")
                            .font(.system(size: 12 * zoom, weight: .semibold))
                            .foregroundStyle(AppTheme.inverseText)
                            .padding(.horizontal, 16 * zoom)
                            .frame(height: 36 * zoom)
                            .background(LemmaColors.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)
                }

                VStack(alignment: .leading, spacing: 14 * zoom) {
                    Text("COURSES  ·  \(notebooks.count)")
                        .font(.system(size: 11 * zoom, weight: .semibold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(LemmaColors.textTertiary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 270 * zoom), spacing: 14 * zoom)],
                              spacing: 14 * zoom) {
                        ForEach(notebooks) { notebook in
                            notebookCard(notebook)
                        }
                        Button(action: onCreateNotebook) {
                            VStack(alignment: .leading, spacing: 16 * zoom) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16 * zoom, weight: .medium))
                                    .foregroundStyle(LemmaColors.accent)
                                    .frame(width: 38 * zoom, height: 38 * zoom)
                                    .background(LemmaColors.selectionWash,
                                                in: RoundedRectangle(cornerRadius: 10 * zoom))
                                Spacer(minLength: 0)
                                Text("Another course?")
                                    .font(.system(size: 17 * zoom, weight: .medium))
                                    .foregroundStyle(LemmaColors.textPrimary)
                                Text("Create a notebook with any course name.")
                                    .font(.system(size: 12 * zoom))
                                    .foregroundStyle(LemmaColors.textSecondary)
                            }
                            .padding(20 * zoom)
                            .frame(maxWidth: .infinity, minHeight: 175 * zoom, alignment: .topLeading)
                            .background(LemmaColors.surfaceElevated.opacity(0.35),
                                        in: RoundedRectangle(cornerRadius: LemmaRadius.card * zoom))
                            .overlay {
                                RoundedRectangle(cornerRadius: LemmaRadius.card * zoom)
                                    .strokeBorder(LemmaColors.border, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Create another notebook")
                    }
                }
            }
            .frame(maxWidth: 1080 * zoom, alignment: .leading)
            .padding(.horizontal, LemmaSpacing.page * zoom)
            .padding(.top, 38 * zoom)
            .padding(.bottom, 60 * zoom)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }

    private func notebookCard(_ notebook: CourseNotebook) -> some View {
        Button { onOpenNotebook(notebook.id) } label: {
            VStack(alignment: .leading, spacing: 18 * zoom) {
                HStack {
                    Image(systemName: "book.closed")
                        .font(.system(size: 17 * zoom))
                        .foregroundStyle(LemmaColors.accent)
                        .frame(width: 38 * zoom, height: 38 * zoom)
                        .background(LemmaColors.selectionWash,
                                    in: RoundedRectangle(cornerRadius: 10 * zoom))
                    Spacer()
                    if notebook.id == activeNotebookID {
                        Text("Current")
                            .font(.system(size: 11 * zoom))
                            .foregroundStyle(LemmaColors.textTertiary)
                    }
                }
                VStack(alignment: .leading, spacing: 6 * zoom) {
                    Text(notebook.title)
                        .font(LemmaTypography.conceptTitle(zoom))
                        .foregroundStyle(LemmaColors.textPrimary)
                        .lineLimit(2)
                    Text("Study, sources, and problems")
                        .font(.system(size: 12 * zoom))
                        .foregroundStyle(LemmaColors.textSecondary)
                }
                HStack {
                    Text("Open notebook")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 12 * zoom, weight: .medium))
                .foregroundStyle(LemmaColors.accent)
            }
            .padding(20 * zoom)
            .frame(maxWidth: .infinity, minHeight: 175 * zoom, alignment: .topLeading)
            .background(LemmaColors.surface,
                        in: RoundedRectangle(cornerRadius: LemmaRadius.card * zoom))
            .overlay {
                RoundedRectangle(cornerRadius: LemmaRadius.card * zoom)
                    .stroke(LemmaColors.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: LemmaRadius.card * zoom))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(notebook.title) notebook")
        .contextMenu {
            Button("Rename") { onRequestRenameNotebook(notebook) }
            Button("Delete notebook", role: .destructive) { onRequestDeleteNotebook(notebook) }
                .disabled(notebooks.count == 1)
        }
    }
}

struct CreateNotebookSheet: View {
    let catalog: CourseNotebookCatalog
    let onCreated: (CourseNotebook) -> Void
    @Environment(\.workspaceZoom) private var zoom
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18 * zoom) {
            HStack {
                Image(systemName: "book.closed")
                    .font(.system(size: 16 * zoom))
                    .foregroundStyle(LemmaColors.accent)
                    .frame(width: 36 * zoom, height: 36 * zoom)
                    .background(LemmaColors.selectionWash,
                                in: RoundedRectangle(cornerRadius: 9 * zoom))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(LemmaColors.textSecondary)
            }
            VStack(alignment: .leading, spacing: 6 * zoom) {
                Text("New notebook")
                    .font(.system(size: 21 * zoom, weight: .semibold))
                    .foregroundStyle(LemmaColors.textPrimary)
                Text("Name the course you want to study.")
                    .font(LemmaTypography.body(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
            }
            TextField("Course name, e.g. Linear Algebra", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 14 * zoom))
                .padding(12 * zoom)
                .background(LemmaColors.surfaceElevated,
                            in: RoundedRectangle(cornerRadius: 9 * zoom))
                .focused($nameFocused)
                .onSubmit(create)
            HStack {
                if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !catalog.canCreate(name) {
                    Text("Use a different name (up to 80 characters).")
                        .font(.system(size: 11 * zoom))
                        .foregroundStyle(AppTheme.critical)
                }
                Spacer()
                Button("Create notebook", action: create)
                    .disabled(!catalog.canCreate(name))
            }
        }
        .padding(24 * zoom)
        .frame(width: 440 * zoom)
        .background(AppTheme.panel)
        .onAppear { nameFocused = true }
    }

    private func create() {
        guard let notebook = catalog.create(name) else { return }
        dismiss()
        onCreated(notebook)
    }
}

struct RenameNotebookSheet: View {
    let catalog: CourseNotebookCatalog
    let notebook: CourseNotebook
    @Environment(\.workspaceZoom) private var zoom
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool
    @State private var name: String

    init(catalog: CourseNotebookCatalog, notebook: CourseNotebook) {
        self.catalog = catalog
        self.notebook = notebook
        _name = State(initialValue: notebook.title)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18 * zoom) {
            HStack {
                Text("Rename notebook")
                    .font(.system(size: 21 * zoom, weight: .semibold))
                    .foregroundStyle(LemmaColors.textPrimary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(LemmaColors.textSecondary)
            }
            TextField("Course name", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 14 * zoom))
                .padding(12 * zoom)
                .background(LemmaColors.surfaceElevated,
                            in: RoundedRectangle(cornerRadius: 9 * zoom))
                .focused($nameFocused)
                .onSubmit(save)
            HStack {
                if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !catalog.canRename(notebook.id, to: name) {
                    Text("Use a different name (up to 80 characters).")
                        .font(.system(size: 11 * zoom))
                        .foregroundStyle(AppTheme.critical)
                }
                Spacer()
                Button("Save name", action: save)
                    .disabled(!catalog.canRename(notebook.id, to: name))
            }
        }
        .padding(24 * zoom)
        .frame(width: 440 * zoom)
        .background(AppTheme.panel)
        .onAppear { nameFocused = true }
    }

    private func save() {
        guard catalog.rename(notebook.id, to: name) else { return }
        dismiss()
    }
}
