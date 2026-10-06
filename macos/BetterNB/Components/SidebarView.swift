import SwiftUI

struct SidebarView: View {
    @Binding var selection: WorkspaceDestination
    @EnvironmentObject private var authentication: AuthenticationSession
    @State private var calculusExpanded = true
    @State private var linearAlgebraExpanded = false
    @State private var studyToolsExpanded = false
    private let zoom: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 18 * zoom) {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(WorkspaceDestination.primary) { destination in
                            SidebarRow(
                                title: destination.title,
                                systemImage: destination.systemImage,
                                isSelected: selection == destination
                            ) {
                                selection = destination
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4 * zoom) {
                        Text("Courses")
                            .zFont(11, weight: .medium, zoom: zoom)
                            .foregroundStyle(AppTheme.tertiaryText)
                            .padding(.leading, 8 * zoom)
                            .padding(.bottom, 2 * zoom)

                        CourseDisclosure(
                            title: "Calculus I",
                            detail: "MATH 137",
                            isExpanded: $calculusExpanded
                        ) {
                            VStack(alignment: .leading, spacing: 1) {
                                ForEach(WorkspaceDestination.courseTools) { destination in
                                    SidebarRow(
                                        title: destination.title,
                                        systemImage: destination.systemImage,
                                        isSelected: selection == destination,
                                        indentationLevel: 1
                                    ) {
                                        selection = destination
                                    }
                                }

                                CourseDisclosure(
                                    title: "Study tools",
                                    detail: "Generated from your work",
                                    systemImage: "square.grid.2x2",
                                    indentationLevel: 1,
                                    isExpanded: $studyToolsExpanded
                                ) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        ForEach(WorkspaceDestination.studyTools) { destination in
                                            SidebarRow(
                                                title: destination.title,
                                                systemImage: destination.systemImage,
                                                isSelected: selection == destination,
                                                indentationLevel: 2
                                            ) {
                                                selection = destination
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        CourseDisclosure(
                            title: "Linear Algebra",
                            detail: "MATH 136",
                            isExpanded: $linearAlgebraExpanded
                        ) {
                            Text("Coming next")
                                .zFont(12, zoom: zoom)
                                .foregroundStyle(AppTheme.tertiaryText)
                                .padding(.leading, 28 * zoom)
                                .padding(.vertical, 4 * zoom)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8 * zoom)
                .padding(.top, 8 * zoom)
                .padding(.bottom, 16 * zoom)
            }
            .scrollIndicators(.hidden)

            accountFooter
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.sidebar)
        .environment(\.workspaceZoom, 1)
        .navigationSplitViewColumnWidth(min: 208, ideal: 220, max: 240)
    }

    private var brandHeader: some View {
        HStack(spacing: 8 * zoom) {
            Text("Lemma")
                .zFont(13, weight: .medium, zoom: zoom)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14 * zoom)
        .frame(height: 44 * zoom)
    }

    private var accountFooter: some View {
        Menu {
            Button("Sign Out", role: .destructive) {
                Task { await authentication.signOut() }
            }
        } label: {
            HStack(spacing: 8 * zoom) {
                Circle()
                    .fill(AppTheme.elevated)
                    .frame(width: 20 * zoom, height: 20 * zoom)
                    .overlay {
                        Image(systemName: "person.fill")
                            .zFont(8, weight: .bold, zoom: zoom)
                            .foregroundStyle(AppTheme.primaryText)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Lemma account")
                        .zFont(12, zoom: zoom)
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                    if case .offlineAuthenticated = authentication.state {
                        Text("Offline")
                            .zFont(9, weight: .medium, zoom: zoom)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                }

                Spacer(minLength: 0)
                Image(systemName: "ellipsis")
                    .zFont(10, weight: .medium, zoom: zoom)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 14 * zoom)
        .padding(.vertical, 10 * zoom)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.stroke)
                .frame(height: 1)
        }
    }
}

private struct CourseDisclosure<Content: View>: View {
    let title: String
    let detail: String
    var systemImage = "folder"
    var indentationLevel = 0
    @Binding var isExpanded: Bool
    @Environment(\.workspaceZoom) private var zoom
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8 * zoom) {
                    Image(systemName: systemImage)
                        .zFont(12, zoom: zoom)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 16 * zoom, alignment: .leading)

                    Text(title)
                        .zFont(13, zoom: zoom)
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .zFont(8, weight: .bold, zoom: zoom)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.leading, CGFloat(8 + 16 * indentationLevel) * zoom)
                .padding(.trailing, 6 * zoom)
                .frame(height: 30 * zoom, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("\(title) · \(detail)")

            if isExpanded {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SidebarRow: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    var indentationLevel = 0
    var badge: String?
    let action: () -> Void

    @Environment(\.workspaceZoom) private var zoom
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8 * zoom) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .zFont(12, zoom: zoom)
                        .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
                        .frame(width: 16 * zoom, alignment: .leading)
                }

                Text(title)
                    .zFont(13, zoom: zoom)
                    .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let badge {
                    Text(badge)
                        .zFont(11, zoom: zoom)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
            .padding(.leading, CGFloat(8 + 16 * indentationLevel) * zoom)
            .padding(.trailing, 8 * zoom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 30 * zoom)
            .background {
                RoundedRectangle(cornerRadius: 7 * zoom, style: .continuous)
                    .fill(rowBackground)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(title)
    }

    private var rowBackground: Color {
        if isSelected {
            AppTheme.selection
        } else if isHovering {
            Color.white.opacity(0.05)
        } else {
            .clear
        }
    }
}
