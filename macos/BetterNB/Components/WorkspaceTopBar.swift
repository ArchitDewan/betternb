import SwiftUI

struct WorkspaceTopBar: View {
    let destination: WorkspaceDestination
    let courseTitle: String
    var onSearch: () -> Void = {}
    @Environment(\.workspaceZoom) private var zoom
    @State private var isSearchHovering = false

    var body: some View {
        HStack(spacing: 8 * zoom) {
            Text(barTitle)
                .font(.system(size: 13 * zoom, weight: .medium))
                .foregroundStyle(LemmaColors.textPrimary)

            if destination != .home && destination != .review {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8 * zoom, weight: .semibold))
                    .foregroundStyle(LemmaColors.textTertiary)
                Text(courseTitle)
                    .font(.system(size: 12 * zoom))
                    .foregroundStyle(LemmaColors.textTertiary)
            }

            Spacer(minLength: 12 * zoom)

            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .zFont(12, weight: .medium, zoom: zoom)
                    .foregroundStyle(isSearchHovering ? LemmaColors.textPrimary : LemmaColors.textSecondary)
                    .frame(width: 28 * zoom, height: 28 * zoom)
                    .background(
                        isSearchHovering ? LemmaColors.surfaceHover : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6 * zoom, style: .continuous)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isSearchHovering = $0 }
            .keyboardShortcut("k", modifiers: .command)
            .accessibilityLabel("Search workspace")
            .help("Search workspace (⌘K)")
        }
        .padding(.horizontal, 20 * zoom)
        .frame(height: 40 * zoom)
        .background(Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(LemmaColors.hairline)
                .frame(height: 1)
        }
    }

    private var barTitle: String {
        switch destination {
        case .home: "Home"
        default: destination.title
        }
    }
}
