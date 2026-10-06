import SwiftUI

struct WorkspaceTopBar: View {
    let destination: WorkspaceDestination
    var onSearch: () -> Void = {}
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        HStack(spacing: 8 * zoom) {
            Text(barTitle)
                .foregroundStyle(AppTheme.primaryText)

            Text("Calculus I")
                .zFont(12, zoom: zoom)
                .foregroundStyle(AppTheme.tertiaryText)

            Spacer(minLength: 12 * zoom)

            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .zFont(12, weight: .medium, zoom: zoom)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 28 * zoom, height: 28 * zoom)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)
            .accessibilityLabel("Search workspace")
            .help("Search workspace (⌘K)")
        }
        .zFont(13, weight: .medium, zoom: zoom)
        .padding(.horizontal, 20 * zoom)
        .frame(height: 44 * zoom)
        .background(AppTheme.canvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.stroke)
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
