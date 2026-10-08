import SwiftUI

struct WorkspaceShellView: View {
    @State private var selection: WorkspaceDestination = .study
    @State private var studyRoute: StudyRoute = .desk
    @State private var threads = StudyThreadStore()
    @State private var courseSources = CourseSourceStore(
        courseID: "calculus-1",
        client: AppDependencies.makeCourseStudyClient()
    )
    @State private var textbookScratchpad = TextbookScratchpadStore()
    @State private var problemSet = ProblemSetStore()
    @State private var isSearchPresented = false
    @State private var isSourcesPresented = false
    @State private var isAllThreadsPresented = false
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        GeometryReader { geometry in
            NavigationSplitView {
                SidebarView(
                    selection: $selection,
                    recentThreads: threads.recent,
                    totalThreadCount: threads.all.count,
                    activeThreadID: studyRoute == .desk ? nil : threads.activeID,
                    onOpenStudyDesk: showStudyDesk,
                    onOpenThread: openThread,
                    onShowAllThreads: { isAllThreadsPresented = true }
                )
            } detail: {
                VStack(spacing: 0) {
                    WorkspaceTopBar(destination: selection) {
                        isSearchPresented = true
                    }
                    destinationView
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .lemmaGlass(material: .underWindowBackground)
            }
            .navigationSplitViewStyle(.balanced)
            .toolbarBackground(.hidden, for: .windowToolbar)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .tint(LemmaColors.accent)
        }
        .sheet(isPresented: $isSearchPresented) {
            WorkspaceSearchView { destination in
                if destination == .study {
                    showStudyDesk()
                } else {
                    selection = destination
                }
                isSearchPresented = false
            }
        }
        .sheet(isPresented: $isSourcesPresented) {
            CourseSourcesView(store: courseSources) { selected in
                problemSet.addGenerated(selected)
            }
        }
        .sheet(isPresented: $isAllThreadsPresented) {
            AllStudyThreadsView(threads: threads.all) { id in
                openThread(id)
                isAllThreadsPresented = false
            }
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch selection {
        case .home:
            WorkspaceHomeView {
                showStudyDesk()
            }
        case .study:
            studyView
        case .textbook:
            TextbookWorkspaceView(sources: courseSources, scratchpad: textbookScratchpad) {
                isSourcesPresented = true
            }
        case .problems:
            ProblemSetView(store: problemSet) { item in
                problemSet.markOpened(item.id)
                startProblem(item.prompt, attachment: nil)
            }
        default:
            WorkspacePlaceholderView(destination: selection)
        }
    }

    @ViewBuilder
    private var studyView: some View {
        switch studyRoute {
        case .desk:
            StudyDeskView(
                sourceCount: courseSources.sources.count,
                problemCount: problemSet.items.count,
                recentThreads: threads.recent,
                totalThreadCount: threads.all.count,
                onManageSources: { isSourcesPresented = true },
                onOpenProblems: { selection = .problems },
                onOpenReview: { selection = .review },
                onOpenFormulaSheet: { selection = .formulaSheet },
                onOpenThread: openThread,
                onShowAllThreads: { isAllThreadsPresented = true },
                onAskCourse: askCourse,
                onStartProblem: startProblem
            )
        case .conversation:
            if let conversations = threads.activeConversations {
                ChannelConversationView(
                    destination: .study,
                    conversations: conversations,
                    topicTitle: threads.activeTitle ?? "A calculus idea",
                    onBackToStudy: showStudyDesk,
                    onAskCourse: { question in
                        await sendCourseQuestion(question, in: conversations)
                    }
                )
                .id(threads.activeID)
            }
        case .worksheet:
            if let tutor = threads.activeTutor {
                PracticeSessionView(tutor: tutor) {
                    showStudyDesk()
                }
                .id(threads.activeID)
            }
        }
    }

    private func askCourse(_ question: String) {
        let conversations = WorkspaceConversationStore(repository: InMemoryChannelMessageRepository())
        threads.startCourse(question: question, conversations: conversations)
        studyRoute = .conversation
        selection = .study
        Task {
            _ = await sendCourseQuestion(question, in: conversations)
        }
    }

    private func sendCourseQuestion(_ question: String, in conversations: WorkspaceConversationStore) async -> Bool {
        guard await conversations.send(question, in: .study) else { return false }
        if let answer = await courseSources.answer(question) {
            conversations.appendTutorReply(answer.answer, sources: answer.sources, in: .study)
        } else {
            conversations.appendTutorReply(
                courseSources.errorMessage ?? "Add a course PDF so I can answer from your material.",
                in: .study
            )
        }
        return true
    }

    private func startProblem(_ prompt: String, attachment: MessageAttachment?) {
        let tutor = TutorSessionStore(client: AppDependencies.makeTutorClient())
        threads.startPractice(prompt: prompt.isEmpty ? "Image problem" : prompt, tutor: tutor)
        studyRoute = .worksheet
        selection = .study
        Task {
            if let attachment {
                _ = await tutor.submit(prompt, attachment: attachment, intent: .ask)
            } else {
                _ = await tutor.beginProblem(prompt)
            }
        }
    }

    private func openThread(_ id: UUID) {
        guard let kind = threads.activate(id) else { return }
        studyRoute = kind == .practice ? .worksheet : .conversation
        selection = .study
    }

    private func showStudyDesk() {
        threads.showDesk()
        studyRoute = .desk
        selection = .study
    }
}

private struct AllStudyThreadsView: View {
    let threads: [StudyThreadSummary]
    let onSelect: (UUID) -> Void
    @Environment(\.workspaceZoom) private var zoom
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14 * zoom) {
            HStack {
                Text("All study threads")
                    .zFont(18, weight: .semibold, zoom: zoom)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Button("Close", action: dismiss.callAsFunction)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4 * zoom) {
                    ForEach(threads) { thread in
                        Button {
                            onSelect(thread.id)
                        } label: {
                            Label(thread.title, systemImage: "bubble.left")
                                .zFont(13, zoom: zoom)
                                .foregroundStyle(AppTheme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10 * zoom)
                                .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 8 * zoom))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20 * zoom)
        .frame(width: 420 * zoom, height: 420 * zoom)
        .background(AppTheme.panel)
    }
}

private struct WorkspaceSearchView: View {
    let onSelect: (WorkspaceDestination) -> Void
    @Environment(\.workspaceZoom) private var zoom
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [WorkspaceDestination] {
        let destinations = WorkspaceDestination.primary
            + WorkspaceDestination.courseTools
            + WorkspaceDestination.studyTools
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return destinations }
        return destinations.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14 * zoom) {
            HStack {
                Text("Go to")
                    .zFont(17, weight: .semibold, zoom: zoom)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer(minLength: 0)
                Button("Close", action: dismiss.callAsFunction)
                    .buttonStyle(.plain)
                    .zFont(12, zoom: zoom)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            TextField("Search workspace", text: $query)
                .textFieldStyle(.plain)
                .zFont(15, zoom: zoom)
                .padding(10 * zoom)
                .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 9 * zoom))

            ScrollView {
                VStack(alignment: .leading, spacing: 2 * zoom) {
                    ForEach(results) { destination in
                        Button {
                            onSelect(destination)
                        } label: {
                            Label(destination.title, systemImage: destination.systemImage)
                                .zFont(13, zoom: zoom)
                                .foregroundStyle(AppTheme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10 * zoom)
                                .frame(height: 34 * zoom)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(18 * zoom)
        .frame(width: 420 * zoom, height: 420 * zoom, alignment: .topLeading)
        .background(AppTheme.panel)
    }
}

private struct WorkspacePlaceholderView: View {
    let destination: WorkspaceDestination
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        VStack(alignment: .leading, spacing: 22 * zoom) {
            Text("Study tool")
                .font(LemmaTypography.caption(zoom))
                .foregroundStyle(LemmaColors.textTertiary)
            Text(destination.title)
                .font(LemmaTypography.pageTitle(zoom))
                .foregroundStyle(LemmaColors.textPrimary)
            Text("This part of your learning workspace is coming soon.")
                .font(LemmaTypography.body(zoom))
                .foregroundStyle(LemmaColors.textSecondary)
            LemmaKnowledgeMotif()
                .padding(.top, 12 * zoom)
        }
        .frame(maxWidth: 820 * zoom, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, AppTheme.pagePadding * zoom)
        .padding(.top, 44 * zoom)
        .background(Color.clear)
    }
}
