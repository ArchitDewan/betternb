import SwiftUI

struct ProblemSetView: View {
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * zoom) {
            HStack(spacing: 12 * zoom) {
                Text("Problems").font(LemmaTypography.pageTitle(zoom))
                FeatureInProgressBadge()
            }
            Text("We're rebuilding this space. Check back later.")
                .font(LemmaTypography.ui(zoom))
                .foregroundStyle(LemmaColors.textSecondary)
            Spacer()
        }
        .padding(LemmaSpacing.page * zoom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
