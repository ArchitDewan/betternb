import SwiftUI
import UniformTypeIdentifiers

struct StudyDeskView: View {
    let tutor: TutorSessionStore
    let sourceCount: Int
    let onContinue: () -> Void
    let onManageSources: () -> Void
    let onAskCourse: (String) -> Void
    let onStartProblem: (String, MessageAttachment?) -> Void

    @Environment(\.workspaceZoom) private var zoom
    @State private var draft = ""
    @State private var attachment: MessageAttachment?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 12 * zoom) {
                    contextBar
                    startArea
                    if tutor.problem != nil {
                        continueAction
                    }
                }
                .frame(maxWidth: 780 * zoom, alignment: .leading)
                .padding(.horizontal, AppTheme.pagePadding * zoom)
                .padding(.top, max(68 * zoom, geometry.size.height * 0.30))
                .padding(.bottom, 40 * zoom)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .background(AppTheme.canvas)
    }

    private var contextBar: some View {
        HStack(spacing: 8 * zoom) {
            Image(systemName: "sparkles")
                .zFont(11, weight: .semibold, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
            Text("Study desk")
                .zFont(13, weight: .semibold, zoom: zoom)
                .foregroundStyle(AppTheme.primaryText)
            Text("Calculus I")
                .zFont(13, zoom: zoom)
                .foregroundStyle(AppTheme.tertiaryText)

            Spacer(minLength: 0)

                Button(action: onManageSources) {
                    HStack(spacing: 5 * zoom) {
                        Image(systemName: "books.vertical")
                            .zFont(10, weight: .medium, zoom: zoom)
                        Text(sourceCount == 1 ? "1 source" : "\(sourceCount) sources")
                            .zFont(12, weight: .medium, zoom: zoom)
                        Image(systemName: "chevron.right")
                            .zFont(8, weight: .semibold, zoom: zoom)
                    }
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.horizontal, 10 * zoom)
                    .frame(height: 28 * zoom)
                    .background(AppTheme.paper, in: Capsule())
                    .overlay { Capsule().stroke(AppTheme.stroke, lineWidth: 1) }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Manage course sources")
                .accessibilityLabel("Manage course sources, \(sourceCount) added")
        }
    }

    private var continueAction: some View {
        Button(action: onContinue) {
            HStack(spacing: 9 * zoom) {
                Image(systemName: "arrow.turn.down.right")
                    .zFont(11, weight: .semibold, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
                Text("Continue current problem")
                    .zFont(12, weight: .medium, zoom: zoom)
                    .foregroundStyle(AppTheme.secondaryText)
                if let problem = tutor.problem {
                    Text(problem)
                        .zFont(12, zoom: zoom)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .zFont(10, weight: .semibold, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6 * zoom)
        .padding(.top, 2 * zoom)
        .accessibilityLabel("Continue current problem")
    }

    private var startArea: some View {
        PromptComposer(
            draft: $draft,
            attachment: $attachment,
            placeholder: "Ask, solve, or create study material",
            allowedContentTypes: [.png, .jpeg],
            attachmentDescription: "a PNG or JPEG homework image",
            expanded: true
        ) {
            prepareSubmission()
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
        VStack(alignment: .leading, spacing: 24 * zoom) {
            VStack(alignment: .leading, spacing: 7 * zoom) {
                Text("Your courses")
                    .zFont(28, weight: .semibold, zoom: zoom)
                    .foregroundStyle(AppTheme.primaryText)
                Text("Open a course to continue at its Study desk.")
                    .zFont(15, zoom: zoom)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Button(action: onOpenCalculus) {
                HStack(spacing: 14 * zoom) {
                    Image(systemName: "function")
                        .zFont(18, weight: .medium, zoom: zoom)
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 36 * zoom, height: 36 * zoom)
                        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 9 * zoom))
                    VStack(alignment: .leading, spacing: 4 * zoom) {
                        Text("Calculus I")
                            .zFont(17, weight: .medium, zoom: zoom)
                            .foregroundStyle(AppTheme.primaryText)
                        Text("Continue limits and continuity")
                            .zFont(13, zoom: zoom)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    Spacer(minLength: 0)
                    Text("Open Study")
                        .zFont(12, weight: .semibold, zoom: zoom)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(18 * zoom)
                .frame(maxWidth: 620 * zoom, alignment: .leading)
                .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 14 * zoom))
                .overlay {
                    RoundedRectangle(cornerRadius: 14 * zoom)
                        .stroke(AppTheme.stroke, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4 * zoom) {
                Text("Linear Algebra")
                    .zFont(15, weight: .medium, zoom: zoom)
                    .foregroundStyle(AppTheme.secondaryText)
                Text("Coming next")
                    .zFont(12, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .padding(.leading, 4 * zoom)

        }
        .padding(.horizontal, AppTheme.pagePadding * zoom)
        .padding(.top, 30 * zoom)
        .padding(.bottom, 40 * zoom)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppTheme.canvas)
    }
}

struct CourseSourcesView: View {
    let store: CourseSourceStore
    let onGeneratedProblems: ([GeneratedCourseProblem]) -> Void

    @Environment(\.workspaceZoom) private var zoom
    @Environment(\.dismiss) private var dismiss
    @State private var isImporterPresented = false
    @State private var generatedMessage: String?

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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 10 * zoom) {
                VStack(alignment: .leading, spacing: 2 * zoom) {
                    Text("Build a practice set")
                        .zFont(13, weight: .semibold, zoom: zoom)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(generatedMessage ?? "Create three problems grounded in these PDFs.")
                        .zFont(11, zoom: zoom)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                Spacer(minLength: 0)
                Button(store.isGenerating ? "Creating…" : "Create problems") {
                    Task {
                        let problems = await store.generateProblems(count: 3)
                        guard !problems.isEmpty else { return }
                        onGeneratedProblems(problems)
                        generatedMessage = "Added \(problems.count) problems to Problems."
                    }
                }
                .buttonStyle(.plain)
                .zFont(12, weight: .semibold, zoom: zoom)
                .foregroundStyle(store.sources.isEmpty ? AppTheme.tertiaryText : AppTheme.primaryText)
                .disabled(store.sources.isEmpty || store.isGenerating)
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
