import SwiftUI

struct WorkspaceShellView: View {
    @State private var selection: WorkspaceDestination = .study
    @State private var studyRoute: StudyRoute = .desk
    @State private var conversations = WorkspaceConversationStore(
        repository: InMemoryChannelMessageRepository()
    )
    @State private var tutor = TutorSessionStore(client: AppDependencies.makeTutorClient())
    @State private var courseSources = CourseSourceStore(
        courseID: "calculus-1",
        client: AppDependencies.makeCourseStudyClient()
    )
    @State private var problemSet = ProblemSetStore()
    @State private var isSearchPresented = false
    @State private var isSourcesPresented = false
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        GeometryReader { geometry in
            NavigationSplitView {
                SidebarView(selection: $selection)
            } detail: {
                VStack(spacing: 0) {
                    WorkspaceTopBar(destination: selection) {
                        isSearchPresented = true
                    }
                    destinationView
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(AppTheme.canvas)
            }
            .navigationSplitViewStyle(.balanced)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .tint(AppTheme.ink)
        }
        .sheet(isPresented: $isSearchPresented) {
            WorkspaceSearchView { destination in
                selection = destination
                isSearchPresented = false
            }
        }
        .sheet(isPresented: $isSourcesPresented) {
            CourseSourcesView(store: courseSources) { generated in
                generated.reversed().forEach { problem in
                    problemSet.add(problem.prompt, sources: problem.sources)
                }
            }
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch selection {
        case .home:
            WorkspaceHomeView {
                studyRoute = .desk
                selection = .study
            }
        case .study:
            studyView
        case .problems:
            ProblemSetView(store: problemSet) { item in
                problemSet.markOpened(item.id)
                studyRoute = .worksheet
                selection = .study
                Task {
                    _ = await tutor.beginProblem(item.prompt)
                }
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
                tutor: tutor,
                sourceCount: courseSources.sources.count,
                onContinue: { studyRoute = .worksheet },
                onManageSources: { isSourcesPresented = true },
                onAskCourse: askCourse,
                onStartProblem: startProblem
            )
        case .conversation:
            ChannelConversationView(
                destination: .study,
                conversations: conversations,
                onBackToStudy: { studyRoute = .desk }
            )
        case .worksheet:
            PracticeSessionView(tutor: tutor) {
                studyRoute = .desk
            }
        }
    }

    private func askCourse(_ question: String) {
        studyRoute = .conversation
        Task {
            guard await conversations.send(question, in: .study) else { return }
            if let answer = await courseSources.answer(question) {
                conversations.appendTutorReply(answer.answer, sources: answer.sources, in: .study)
            } else {
                conversations.appendTutorReply(
                    courseSources.errorMessage ?? "Add a course PDF so I can answer from your material.",
                    in: .study
                )
            }
        }
    }

    private func startProblem(_ prompt: String, attachment: MessageAttachment?) {
        studyRoute = .worksheet
        Task {
            if let attachment {
                tutor.reset()
                _ = await tutor.submit(prompt, attachment: attachment, intent: .ask)
            } else {
                _ = await tutor.beginProblem(prompt)
            }
        }
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
        VStack(alignment: .leading, spacing: 12 * zoom) {
            Text(destination.title)
                .zFont(28, weight: .semibold, zoom: zoom)
                .foregroundStyle(AppTheme.primaryText)

            Text("This surface is ready for the next design pass.")
                .zFont(20, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: 820 * zoom, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, AppTheme.pagePadding * zoom)
        .padding(.top, 22 * zoom)
        .background(AppTheme.canvas)
    }
}
