import SwiftUI

struct ReviewToolTile: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let action: () -> Void
    @Environment(\.workspaceZoom) private var zoom
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ReviewIcon(symbol: symbol, tint: tint)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(LemmaTypography.ui(zoom).weight(.semibold)).foregroundStyle(LemmaColors.textPrimary)
                    Text(detail).font(LemmaTypography.caption(zoom)).foregroundStyle(LemmaColors.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.system(size: 10 * zoom, weight: .medium)).foregroundStyle(tint)
            }.padding(14).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading).reviewSurface(tint: tint)
        }.buttonStyle(.plain)
    }
}

struct ReviewIcon: View {
    let symbol: String
    let tint: Color
    var body: some View {
        Image(systemName: symbol).font(.system(size: 18, weight: .medium)).foregroundStyle(tint)
            .frame(width: 42, height: 42).background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 11))
    }
}

struct ReviewStatusMenu: View {
    @Binding var status: ReviewStatus
    @Environment(\.workspaceZoom) private var zoom
    private var tint: Color {
        switch status { case .notStarted: LemmaColors.textTertiary; case .inProgress: LemmaColors.toolQuiz; case .reviewed: LemmaColors.toolSummary }
    }
    var body: some View {
        Menu {
            ForEach(ReviewStatus.allCases) { value in Button(value.rawValue) { status = value } }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 5, height: 5)
                Text(status.rawValue).font(LemmaTypography.caption(zoom))
                Image(systemName: "chevron.down").font(.system(size: 8))
            }.foregroundStyle(tint).padding(.horizontal, 10).padding(.vertical, 7)
                .background(tint.opacity(0.09), in: Capsule())
        }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Topic status: " + status.rawValue)
    }
}

extension View {
    func reviewSurface(tint: Color = LemmaColors.textTertiary) -> some View {
        background(LemmaColors.hoverWash, in: RoundedRectangle(cornerRadius: LemmaRadius.card))
            .overlay(RoundedRectangle(cornerRadius: LemmaRadius.card).stroke(tint.opacity(0.16), lineWidth: 1))
    }
}
