import SwiftUI

private enum ProblemBrowserLocation: Equatable {
    case root
    case inbox
    case folder(UUID)
}

struct ProblemSetView: View {
    let store: ProblemSetStore
    let onWork: (CourseProblem) -> Void

    @Environment(\.workspaceZoom) private var zoom
    @State private var location: ProblemBrowserLocation = .root
    @State private var folderName = ""
    @State private var folderToRename: UUID?
    @State private var isFolderDialogPresented = false
    @State private var problemDraft = ""
    @State private var editingProblemID: UUID?
    @State private var targetGroupID: UUID?
    @State private var isProblemEditorPresented = false

    private let maxWidth: CGFloat = 1_080

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24 * zoom) {
                header
                switch location {
                case .root:
                    folderBrowser
                case .inbox, .folder:
                    folderContents
                }
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18 * zoom) {
            if location != .root {
                HStack(spacing: 6 * zoom) {
                    Button("Problems") { location = .root }
                        .buttonStyle(.plain)
                    Image(systemName: "chevron.right")
                        .zFont(9, zoom: zoom)
                    Text(currentFolderTitle)
                        .foregroundStyle(AppTheme.primaryText)
                }
                .zFont(12, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
            }

            HStack(alignment: .center, spacing: 14 * zoom) {
                VStack(alignment: .leading, spacing: 5 * zoom) {
                    Text(location == .root ? "Problems" : currentFolderTitle)
                        .zFont(27, weight: .semibold, zoom: zoom)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(location == .root
                         ? "Your assignments and practice, organized by folder."
                         : "\(visibleProblems.count) \(visibleProblems.count == 1 ? "question" : "questions")")
                        .zFont(12, zoom: zoom)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer(minLength: 0)
                Menu {
                    Button("New folder", systemImage: "folder.badge.plus") { presentNewFolder() }
                    Button("New problem", systemImage: "plus.square") { presentNewProblem() }
                } label: {
                    Label("New", systemImage: "plus")
                        .zFont(12, weight: .semibold, zoom: zoom)
                        .foregroundStyle(AppTheme.inverseText)
                        .padding(.horizontal, 15 * zoom)
                        .frame(height: 34 * zoom)
                        .background(AppTheme.primaryText, in: Capsule())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var folderBrowser: some View {
        VStack(alignment: .leading, spacing: 14 * zoom) {
            sectionHeading("Folders", count: store.groups.count + 1)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 270 * zoom), spacing: 12 * zoom)], spacing: 12 * zoom) {
                folderTile(title: "Inbox", count: store.items.filter { $0.groupID == nil }.count, id: nil)
                ForEach(store.groups) { group in
                    folderTile(title: group.title, count: store.items.filter { $0.groupID == group.id }.count, id: group.id)
                }
            }
            if store.groups.isEmpty && store.items.isEmpty {
                Text("New problems you enter go to Inbox. Questions saved from a PDF get their own folder automatically.")
                    .zFont(12, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .padding(.top, 6 * zoom)
            }
        }
    }

    private func folderTile(title: String, count: Int, id: UUID?) -> some View {
        HStack(spacing: 11 * zoom) {
            Button {
                location = id.map(ProblemBrowserLocation.folder) ?? .inbox
            } label: {
                HStack(spacing: 11 * zoom) {
                    Image(systemName: id == nil ? "tray.full.fill" : "folder.fill")
                        .zFont(20, zoom: zoom)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 27 * zoom)
                    VStack(alignment: .leading, spacing: 3 * zoom) {
                        Text(title)
                            .zFont(13, weight: .medium, zoom: zoom)
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text("\(count) \(count == 1 ? "question" : "questions")")
                            .zFont(11, zoom: zoom)
                            .foregroundStyle(AppTheme.tertiaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let id {
                Menu {
                    Button("Rename") { presentRenameFolder(id, title: title) }
                    Button("Delete folder (move questions to Inbox)", role: .destructive) {
                        _ = store.removeGroup(id)
                    }
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
        .padding(.horizontal, 16 * zoom)
        .frame(height: 84 * zoom)
        .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 12 * zoom))
        .overlay {
            RoundedRectangle(cornerRadius: 12 * zoom)
                .stroke(AppTheme.stroke, lineWidth: 1)
        }
    }

    private var folderContents: some View {
        VStack(alignment: .leading, spacing: 12 * zoom) {
            sectionHeading("Questions", count: visibleProblems.count)
            if visibleProblems.isEmpty {
                VStack(alignment: .leading, spacing: 10 * zoom) {
                    Image(systemName: "doc.text")
                        .zFont(22, zoom: zoom)
                        .foregroundStyle(AppTheme.tertiaryText)
                    Text("No questions here yet")
                        .zFont(15, weight: .medium, zoom: zoom)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Add a problem with New, or save generated questions from a course PDF.")
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
        VStack(alignment: .leading, spacing: 13 * zoom) {
            TutorMathText(source: item.prompt, fontSize: 14 * zoom)
            if let source = item.sources.first {
                Label("\(source.title) · \(source.section)", systemImage: "doc.text")
                    .zFont(11, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            HStack(spacing: 12 * zoom) {
                Text(item.openedInPractice ? "Opened in Practice" : "Not started")
                    .zFont(11, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
                Spacer(minLength: 0)
                Button("Work in Practice") { onWork(item) }
                    .buttonStyle(.plain)
                    .zFont(12, weight: .medium, zoom: zoom)
                    .foregroundStyle(AppTheme.primaryText)
                Menu {
                    Button("Edit") { presentEditProblem(item) }
                    Menu("Move to") {
                        Button("Inbox") { _ = store.move(item.id, to: nil) }
                        ForEach(store.groups) { group in
                            Button(group.title) { _ = store.move(item.id, to: group.id) }
                        }
                    }
                    Button("Delete problem", role: .destructive) { _ = store.remove(item.id) }
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
        case .root: []
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
        location = targetGroupID.map(ProblemBrowserLocation.folder) ?? .inbox
        isProblemEditorPresented = false
    }
}
