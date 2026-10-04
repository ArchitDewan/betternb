import SwiftUI

struct WorkspaceShellView: View {
    @State private var selection: WorkspaceDestination = .home
    @State private var conversations = WorkspaceConversationStore(
        repository: InMemoryChannelMessageRepository()
    )
    @State private var tutor = TutorSessionStore(client: AppDependencies.makeTutorClient())
    @State private var problemSet = ProblemSetStore()
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            VStack(spacing: 0) {
                WorkspaceTopBar(destination: selection)
                destinationView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.canvas)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(AppTheme.ink)
    }

    @ViewBuilder
    private var destinationView: some View {
        switch selection {
        case .home, .overview:
            CourseWorkspaceView(selection: $selection)
        case .practice:
            PracticeSessionView(tutor: tutor)
        case .problems:
            ProblemSetView(store: problemSet) { item in
                problemSet.markOpened(item.id)
                Task {
                    _ = await tutor.beginProblem(item.prompt)
                    selection = .practice
                }
            }
        case let destination where destination.acceptsMessages:
            ChannelConversationView(destination: destination, conversations: conversations)
        default:
            WorkspacePlaceholderView(destination: selection)
        }
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
