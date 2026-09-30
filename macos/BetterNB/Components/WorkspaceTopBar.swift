import SwiftUI

struct WorkspaceTopBar: View {
    let destination: WorkspaceDestination
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        HStack(spacing: 8 * zoom) {
            Text("Calculus I")
                .foregroundStyle(AppTheme.secondaryText)
            Image(systemName: "chevron.right")
                .zFont(11, weight: .bold, zoom: zoom)
                .foregroundStyle(AppTheme.tertiaryText)
            Text(barTitle)
                .foregroundStyle(AppTheme.primaryText)

            Spacer(minLength: 12 * zoom)
        }
        .zFont(15, zoom: zoom)
        .padding(.horizontal, 20 * zoom)
        .frame(height: 44 * zoom)
        .background(AppTheme.canvas)
    }

    private var barTitle: String {
        switch destination {
        case .home: "Today"
        case .practice: "Session"
        default: destination.title
        }
    }
}
