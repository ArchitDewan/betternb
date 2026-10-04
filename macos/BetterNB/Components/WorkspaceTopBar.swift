import SwiftUI

struct WorkspaceTopBar: View {
    let destination: WorkspaceDestination
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        HStack(spacing: 8 * zoom) {
            Text(barTitle)
                .foregroundStyle(AppTheme.primaryText)

            Text("Calculus I")
                .zFont(12, zoom: zoom)
                .foregroundStyle(AppTheme.tertiaryText)

            Spacer(minLength: 12 * zoom)
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
        case .home: "Today"
        case .practice: "Session"
        default: destination.title
        }
    }
}
