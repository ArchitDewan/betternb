import SwiftUI
import UniformTypeIdentifiers

private enum ProblemBrowserLocation: Equatable {
    case root
    case inbox
    case folder(UUID)
}

struct ProblemSetView: View {
    let store: ProblemSetStore
    let sources: CourseSourceStore
    let onWork: (CourseProblem) -> Void
    let onNewAttempt: (CourseProblem) -> Void
    let latestAttempt: (UUID) -> ProblemAttemptSummary?
    let onMarkDone: (CourseProblem, UUID, Bool) -> Void

    @Environment(\.workspaceZoom) private var zoom
    @State private var location: ProblemBrowserLocation = .root
    @State private var folderName = ""
    @State private var folderToRename: UUID?
    @State private var isFolderDialogPresented = false
    @State private var problemDraft = ""
    @State private var editingProblemID: UUID?
    @State private var targetGroupID: UUID?
    @State private var isProblemEditorPresented = false
    @State private var isImporterPresented = false
    @State private var isReviewPresented = false
    @State private var isExtracting = false
    @State private var isGenerating = false
    @State private var selectedSourceID: String?
    @State private var review = GeneratedProblemReviewStore()
    @State private var reviewTitle = "Review questions"
    @State private var statusMessage: String?

    private let maxWidth: CGFloat = 1_080

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24 * zoom) {
                header
                worksheetSection
                folderContents
            }
            .frame(maxWidth: maxWidth * zoom, alignment: .leading)
            .padding(.horizontal, 28 * zoom)
            .padding(.top, 24 * zoom)
            .padding(.bottom, 50 * zoom)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .alert(folderToRename == nil ? "New folder" : "Rename folder", isPresented: $isFolderDialogPresented) {
            TextField("Folder name", text: $folderName)
            Button("Cancel", role: .cancel) { folderToRename = nil }
            Button(folderToRename == nil ? "Create" : "Save") { saveFolder() }
        } message: {
            Text("Keep related questions together in this notebook.")
        }
        .sheet(isPresented: $isProblemEditorPresented) {
            problemEditor
        }
        .sheet(isPresented: $isReviewPresented) { reviewSheet }
        .task {
            await sources.refresh()
            if selectedSourceID == nil { selectedSourceID = sources.sources.first?.id }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.pdf, .png, .jpeg, UTType(filenameExtension: "heic")!],
            allowsMultipleSelection: true
        ) { result in
            guard case let .success(urls) = result, !urls.isEmpty else { return }
            Task {
                do {
                    let attachment = try await Task.detached {
                        try MessageAttachment.importingWorksheetFiles(urls)
                    }.value
                    if let source = await sources.importWorksheet(attachment) {
                        selectedSourceID = source.id
                        statusMessage = source.unreadablePages.isEmpty
                            ? "\(source.filename) is ready. Import its questions or generate new ones."
                            : "\(source.filename) imported, but pages \(source.unreadablePages.map(String.init).joined(separator: ", ")) could not be read. Check those pages before saving questions."
                    }
                } catch {
                    statusMessage = "That worksheet couldn’t be opened. Choose a PDF or image under the size limit."
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18 * zoom) {
            HStack(alignment: .center, spacing: 14 * zoom) {
                VStack(alignment: .leading, spacing: 5 * zoom) {
                    Text("Problems")
                        .zFont(27, weight: .semibold, zoom: zoom)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Build a set from worksheets, then work through it in Practice.")
                        .zFont(12, zoom: zoom)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer(minLength: 0)
                Button { presentNewProblem() } label: {
                    Label("Add problem", systemImage: "plus")
                        .zFont(12, weight: .semibold, zoom: zoom)
                        .foregroundStyle(AppTheme.inverseText)
                        .padding(.horizontal, 15 * zoom)
                        .frame(height: 34 * zoom)
                        .background(AppTheme.primaryText, in: Capsule())
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var worksheetSection: some View {
        return VStack(alignment: .leading, spacing: 13 * zoom) {
            HStack {
                Text("From a worksheet")
                    .zFont(14, weight: .semibold, zoom: zoom)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Button { isImporterPresented = true } label: {
                    Label("Upload worksheet", systemImage: "square.and.arrow.up")
                }
                .disabled(sources.isImporting)
            }
            VStack(alignment: .leading, spacing: 14 * zoom) {
                if sources.sources.isEmpty {
                    Text("Upload a PDF or photo to import its questions or create new practice problems.")
                        .zFont(12, zoom: zoom)
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(AppTheme.secondaryText)
                        Picker("Worksheet", selection: $selectedSourceID) {
                            ForEach(sources.sources) { source in
                                Text(source.filename).tag(Optional(source.id))
                            }
                        }
                        .pickerStyle(.menu)
                        Spacer()
                        if let selected = sources.sources.first(where: { $0.id == selectedSourceID }) {
                            Text("\(selected.pageCount) \(selected.pageCount == 1 ? "page" : "pages")")
                                .zFont(11, zoom: zoom)
                                .foregroundStyle(AppTheme.tertiaryText)
                        }
                    }
                    HStack(spacing: 10 * zoom) {
                        Button(isExtracting ? "Reading questions…" : "Import questions") { importQuestions() }
                            .disabled(selectedSourceID == nil || isExtracting || isGenerating)
                        Button(isGenerating ? "Generating…" : "Generate new problems") { generateProblems() }
                            .disabled(selectedSourceID == nil || isExtracting || isGenerating)
                    }
                    Text("Import keeps the worksheet’s questions. Generate creates new questions using similar methods.")
                        .zFont(11, zoom: zoom)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                if let message = sources.errorMessage ?? statusMessage {
                    Text(message)
                        .zFont(11, zoom: zoom)
                        .foregroundStyle(sources.errorMessage == nil ? AppTheme.secondaryText : AppTheme.critical)
                }
            }
            .padding(19 * zoom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 12 * zoom))
            .overlay { RoundedRectangle(cornerRadius: 12 * zoom).stroke(AppTheme.stroke, lineWidth: 1) }
        }
    }

    private var reviewSheet: some View {
        VStack(alignment: .leading, spacing: 16 * zoom) {
            HStack {
                VStack(alignment: .leading, spacing: 4 * zoom) {
                    Text(reviewTitle).zFont(19, weight: .semibold, zoom: zoom)
                    Text("Check the math and wording before saving.")
                        .zFont(12, zoom: zoom).foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Button("Close") { isReviewPresented = false }
            }
            ScrollView {
                LazyVStack(spacing: 10 * zoom) {
                    ForEach(review.drafts) { draft in
                        VStack(alignment: .leading, spacing: 8 * zoom) {
                            Toggle("Save this problem", isOn: Binding(
                                get: { review.drafts.first { $0.id == draft.id }?.isSelected ?? false },
                                set: { _ in review.toggleSelection(draft.id) }
                            ))
                            if draft.prompt.localizedCaseInsensitiveContains("[unclear]") {
                                Label("Unclear transcription · check the worksheet", systemImage: "exclamationmark.triangle")
                                    .zFont(11, zoom: zoom)
                                    .foregroundStyle(AppTheme.critical)
                            }
                            TextEditor(text: Binding(
                                get: { review.drafts.first { $0.id == draft.id }?.prompt ?? "" },
                                set: { review.updatePrompt(draft.id, to: $0) }
                            ))
                            .font(.system(size: 13 * zoom))
                            .frame(height: 85 * zoom)
                            .scrollContentBackground(.hidden)
                            TutorMathText(source: draft.prompt, fontSize: 12 * zoom)
                            if let source = draft.sources.first {
                                Text("\(source.title) · \(source.section)")
                                    .zFont(10, zoom: zoom).foregroundStyle(AppTheme.tertiaryText)
                            }
                        }
                        .padding(13 * zoom)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 9 * zoom))
                    }
                }
            }
            HStack {
                Button("Discard") { review.discard(); isReviewPresented = false }
                Spacer()
                Button("Save selected") {
                    let count = review.saveSelected(into: store)
                    statusMessage = "Saved \(count) \(count == 1 ? "problem" : "problems") to your set."
                    isReviewPresented = false
                }
                .disabled(review.selectedProblems.isEmpty)
            }
        }
        .padding(22 * zoom)
        .frame(width: 620 * zoom, height: 600 * zoom)
        .background(AppTheme.panel)
    }

    private var folderContents: some View {
        VStack(alignment: .leading, spacing: 12 * zoom) {
            HStack {
                sectionHeading("Saved problems", count: visibleProblems.count)
                Spacer()
                Menu {
                    Button("All problems") { location = .root }
                    Button("Inbox") { location = .inbox }
                    ForEach(store.groups) { group in
                        Button(group.title) { location = .folder(group.id) }
                    }
                    Divider()
                    Button("New folder") { presentNewFolder() }
                    if case .folder(let id) = location {
                        Button("Rename folder") {
                            presentRenameFolder(id, title: currentFolderTitle)
                        }
                        Button("Delete folder · move to Inbox", role: .destructive) {
                            _ = store.removeGroup(id)
                            location = .root
                        }
                    }
                } label: {
                    Label(location == .root ? "All" : currentFolderTitle,
                          systemImage: "line.3.horizontal.decrease")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            if visibleProblems.isEmpty {
                VStack(alignment: .leading, spacing: 10 * zoom) {
                    Image(systemName: "doc.text")
                        .zFont(22, zoom: zoom)
                        .foregroundStyle(AppTheme.tertiaryText)
                    Text("No questions here yet")
                        .zFont(15, weight: .medium, zoom: zoom)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Add a problem, or turn a worksheet into questions you can practice.")
                        .zFont(12, zoom: zoom)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22 * zoom)
                .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 12 * zoom))
            } else {
                ForEach(visibleProblems) { item in
                    problemCard(item)
                }
            }
        }
    }

    private func sectionHeading(_ title: String, count: Int) -> some View {
        HStack(spacing: 8 * zoom) {
            Text(title)
                .zFont(12, weight: .semibold, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
            Text("\(count)")
                .zFont(11, zoom: zoom)
                .foregroundStyle(AppTheme.tertiaryText)
        }
    }

    private func problemCard(_ item: CourseProblem) -> some View {
        let attempt = latestAttempt(item.id)
        let isDone = attempt != nil && item.doneAttemptID == attempt?.id
        return VStack(alignment: .leading, spacing: 13 * zoom) {
            TutorMathText(source: item.prompt, fontSize: 14 * zoom)
            if let source = item.sources.first {
                Label("\(source.title) · \(source.section)", systemImage: "doc.text")
                    .zFont(11, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            HStack(spacing: 12 * zoom) {
                Text(isDone ? "Done" : (attempt == nil ? "Not started" : "In progress"))
                    .zFont(11, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
                if attempt?.solutionRevealed == true {
                    Text("Reveal used")
                        .zFont(11, zoom: zoom)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                Spacer(minLength: 0)
                Button(attempt == nil ? "Work in Practice" : "Resume Practice") { onWork(item) }
                    .buttonStyle(.plain)
                    .zFont(12, weight: .medium, zoom: zoom)
                    .foregroundStyle(AppTheme.primaryText)
                Menu {
                    Button("Edit") { presentEditProblem(item) }
                    Button("New attempt") { onNewAttempt(item) }
                    if let attempt {
                        Button(isDone ? "Mark in progress" : "Mark done") {
                            onMarkDone(item, attempt.id, !isDone)
                        }
                    }
                    Menu("Move to") {
                        Button("Inbox") { _ = store.move(item.id, to: nil) }
                        ForEach(store.groups) { group in
                            Button(group.title) { _ = store.move(item.id, to: group.id) }
                        }
                    }
                    Button("Remove from Problems", role: .destructive) { _ = store.remove(item.id) }
                } label: {
                    Image(systemName: "ellipsis")
                        .zFont(12, zoom: zoom)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 22 * zoom, height: 26 * zoom)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(16 * zoom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 12 * zoom))
        .overlay {
            RoundedRectangle(cornerRadius: 12 * zoom)
                .stroke(AppTheme.stroke, lineWidth: 1)
        }
    }

    private var problemEditor: some View {
        VStack(alignment: .leading, spacing: 16 * zoom) {
            HStack {
                Text(editingProblemID == nil ? "New problem" : "Edit problem")
                    .zFont(19, weight: .semibold, zoom: zoom)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Button("Cancel") { isProblemEditorPresented = false }
                    .buttonStyle(.plain)
                    .zFont(12, zoom: zoom)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Text("Problem statement")
                .zFont(11, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
            TextEditor(text: $problemDraft)
                .font(.system(size: 14 * zoom))
                .foregroundStyle(AppTheme.primaryText)
                .scrollContentBackground(.hidden)
                .padding(8 * zoom)
                .frame(height: 115 * zoom)
                .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 9 * zoom))
            if !problemDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Preview")
                    .zFont(11, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
                ScrollView {
                    TutorMathText(source: problemDraft, fontSize: 13 * zoom)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 100 * zoom)
            }
            Picker("Folder", selection: $targetGroupID) {
                Text("Inbox").tag(Optional<UUID>.none)
                ForEach(store.groups) { group in
                    Text(group.title).tag(Optional(group.id))
                }
            }
            .pickerStyle(.menu)
            HStack {
                Spacer()
                Button(editingProblemID == nil ? "Add problem" : "Save changes") { saveProblem() }
                    .disabled(problemDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22 * zoom)
        .frame(width: 520 * zoom)
        .background(AppTheme.panel)
    }

    private var visibleProblems: [CourseProblem] {
        switch location {
        case .root: store.items
        case .inbox: store.items.filter { $0.groupID == nil }
        case .folder(let id): store.items.filter { $0.groupID == id }
        }
    }

    private var currentFolderTitle: String {
        switch location {
        case .root: "Problems"
        case .inbox: "Inbox"
        case .folder(let id): store.groups.first(where: { $0.id == id })?.title ?? "Folder"
        }
    }

    private func presentNewFolder() {
        folderName = ""
        folderToRename = nil
        isFolderDialogPresented = true
    }

    private func presentRenameFolder(_ id: UUID, title: String) {
        folderName = title
        folderToRename = id
        isFolderDialogPresented = true
    }

    private func saveFolder() {
        if let folderToRename {
            _ = store.renameGroup(folderToRename, to: folderName)
        } else if let created = store.addGroup(folderName) {
            location = .folder(created.id)
        }
        folderToRename = nil
    }

    private func presentNewProblem() {
        editingProblemID = nil
        problemDraft = ""
        switch location {
        case .folder(let id): targetGroupID = id
        case .root, .inbox: targetGroupID = nil
        }
        isProblemEditorPresented = true
    }

    private func presentEditProblem(_ item: CourseProblem) {
        editingProblemID = item.id
        problemDraft = item.prompt
        targetGroupID = item.groupID
        isProblemEditorPresented = true
    }

    private func saveProblem() {
        if let editingProblemID {
            guard store.update(editingProblemID, prompt: problemDraft),
                  store.move(editingProblemID, to: targetGroupID) else { return }
        } else {
            guard store.add(problemDraft, groupID: targetGroupID) != nil else { return }
        }
        location = .root
        isProblemEditorPresented = false
    }

    private func importQuestions() {
        guard let selectedSourceID else { return }
        isExtracting = true
        Task {
            let problems = await sources.extractProblems(sourceID: selectedSourceID)
            isExtracting = false
            if problems.isEmpty {
                statusMessage = "No questions were found. You can add them manually."
            } else {
                reviewTitle = "Import worksheet questions"
                review.load(problems)
                isReviewPresented = true
            }
        }
    }

    private func generateProblems() {
        guard let selectedSourceID else { return }
        isGenerating = true
        Task {
            let problems = await sources.generateProblems(sourceID: selectedSourceID, count: 3)
            isGenerating = false
            if problems.isEmpty {
                statusMessage = "No new problems were generated. Try again or add one manually."
            } else {
                reviewTitle = "Review new problems"
                review.load(problems)
                isReviewPresented = true
            }
        }
    }
}
