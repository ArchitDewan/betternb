import SwiftUI

struct CourseWorkspaceView: View {
    @Binding var selection: WorkspaceDestination
    var onContinuePractice: () -> Void = {}
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26 * zoom) {
                header
                problemStage
                workspaceStrip
                recentWork
            }
            .frame(maxWidth: 820 * zoom, alignment: .leading)
            .padding(.horizontal, AppTheme.pagePadding * zoom)
            .padding(.top, 22 * zoom)
            .padding(.bottom, 40 * zoom)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.canvas)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6 * zoom) {
            HStack(spacing: 8 * zoom) {
                Text("Calculus I")
                    .foregroundStyle(AppTheme.secondaryText)
                Text("·")
                    .foregroundStyle(AppTheme.tertiaryText)
                Text("Week 4")
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .zFont(15, weight: .semibold, zoom: zoom)

            Text("Limits & Continuity")
                .zFont(28, weight: .semibold, zoom: zoom)
                .foregroundStyle(AppTheme.primaryText)
        }
    }

    private var problemStage: some View {
        VStack(alignment: .leading, spacing: 16 * zoom) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 28 * zoom) {
                    problemCopy
                    LimitSketch()
                        .opacity(0.95)
                }
                VStack(alignment: .leading, spacing: 16 * zoom) {
                    problemCopy
                    LimitSketch()
                        .opacity(0.95)
                }
            }

            Text("You stopped at the graph. Next: check the left- and right-hand values before deciding the limit exists.")
                .zFont(17, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: 14 * zoom) {
                Button {
                    onContinuePractice()
                } label: {
                    Text("Continue")
                        .zFont(15, weight: .semibold, zoom: zoom)
                        .foregroundStyle(AppTheme.inverseText)
                        .padding(.horizontal, 16 * zoom)
                        .frame(height: 36 * zoom)
                        .background(AppTheme.primaryText, in: RoundedRectangle(cornerRadius: 9 * zoom, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Open the current practice session")

                Text("4 of 8  ·  about 12 minutes")
                    .zFont(15, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
        }
        .padding(22 * zoom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        }
    }

    private var problemCopy: some View {
        VStack(alignment: .leading, spacing: 8 * zoom) {
            Text("Problem 4")
                .zFont(12, weight: .semibold, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)

            Text("limₓ→₂ f(x)")
                .zFont(52, weight: .medium, design: .serif, zoom: zoom)
                .foregroundStyle(AppTheme.primaryText)
                .minimumScaleFactor(0.55)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var workspaceStrip: some View {
        HStack(spacing: 18 * zoom) {
            ForEach(StudyTool.calculusTools) { tool in
                Button {
                    selection = tool.destination
                } label: {
                    VStack(alignment: .leading, spacing: 3 * zoom) {
                        Text(tool.title)
                            .zFont(15, weight: .medium, zoom: zoom)
                            .foregroundStyle(AppTheme.primaryText)
                        Text(tool.detail)
                            .zFont(12, zoom: zoom)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open \(tool.title)")
            }
        }
    }

    private var recentWork: some View {
        VStack(alignment: .leading, spacing: 8 * zoom) {
            Text("Still on your desk")
                .zFont(12, weight: .semibold, zoom: zoom)
                .foregroundStyle(AppTheme.tertiaryText)

            ForEach(Array(RecentStudyItem.calculusItems.prefix(2))) { item in
                Button {
                    selection = item.destination
                } label: {
                    HStack(spacing: 8 * zoom) {
                        Text(item.title)
                            .zFont(17, zoom: zoom)
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                        Text(item.context)
                            .zFont(15, zoom: zoom)
                            .foregroundStyle(AppTheme.tertiaryText)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4 * zoom)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(item.title)
            }
        }
    }
}
