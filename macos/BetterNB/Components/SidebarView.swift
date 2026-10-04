import SwiftUI

struct SidebarView: View {
    @Binding var selection: WorkspaceDestination
    @Environment(\.workspaceZoom) private var zoom
    @EnvironmentObject private var authentication: AuthenticationSession
    @State private var calculusExpanded = true
    @State private var linearAlgebraExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 16 * zoom) {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(WorkspaceDestination.primary) { destination in
                            SidebarRow(
                                title: destination.title,
                                systemImage: destination.systemImage,
                                isSelected: selection == destination,
                                badge: destination == .review ? "3" : nil
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
                                        isNested: true
                                    ) {
                                        selection = destination
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
                .padding(.horizontal, 6 * zoom)
                .padding(.top, 4 * zoom)
                .padding(.bottom, 16 * zoom)
            }
            .scrollIndicators(.hidden)

            accountFooter
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.sidebar)
        .navigationSplitViewColumnWidth(min: 188, ideal: 216, max: 244)
    }

    private var brandHeader: some View {
        HStack(spacing: 8 * zoom) {
            Text("BetterNB")
                .zFont(13, weight: .semibold, zoom: zoom)
                .foregroundStyle(AppTheme.primaryText)

            Spacer(minLength: 0)

            Button {
                selection = .search
            } label: {
                Image(systemName: "magnifyingglass")
                    .zFont(12, weight: .medium, zoom: zoom)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 22 * zoom, height: 22 * zoom)
            }
            .buttonStyle(.plain)
            .help("Search")
        }
        .padding(.leading, 14 * zoom)
        .padding(.trailing, 8 * zoom)
        .padding(.top, 10 * zoom)
        .padding(.bottom, 8 * zoom)
    }

    private var accountFooter: some View {
        Menu {
            Button("Sign Out", role: .destructive) {
                Task { await authentication.signOut() }
            }
        } label: {
            HStack(spacing: 8 * zoom) {
                Circle()
                    .fill(AppTheme.elevatedHover)
                    .frame(width: 20 * zoom, height: 20 * zoom)
                    .overlay {
                        Image(systemName: "person.fill")
                            .zFont(8, weight: .bold, zoom: zoom)
                            .foregroundStyle(AppTheme.primaryText)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text("BetterNB account")
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
        .padding(.leading, 14 * zoom)
        .padding(.trailing, 8 * zoom)
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
                    Image(systemName: "folder")
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
                .padding(.leading, 8 * zoom)
                .padding(.trailing, 6 * zoom)
                .frame(height: 28 * zoom, alignment: .leading)
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
    var isNested = false
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
            .padding(.leading, (isNested ? 24 : 8) * zoom)
            .padding(.trailing, 8 * zoom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 28 * zoom)
            .quietRowBackground(isActive: isSelected || isHovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(title)
    }
}
