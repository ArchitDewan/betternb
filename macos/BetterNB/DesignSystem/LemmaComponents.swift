import SwiftUI

struct LemmaSectionHeader: View {
    let title: String
    var detail: String? = nil
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12 * zoom) {
            Text(title)
                .font(LemmaTypography.sectionTitle(zoom))
                .foregroundStyle(LemmaColors.textPrimary)
            if let detail {
                Text(detail)
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.textTertiary)
            }
            Spacer(minLength: 0)
        }
    }
}

struct LemmaStudyAction: View {
    let title: String
    var detail = ""
    let symbol: String
    let action: () -> Void
    @Environment(\.workspaceZoom) private var zoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 6 * zoom) {
                Image(systemName: symbol)
                    .font(.system(size: 12 * zoom, weight: .medium))
                    .foregroundStyle(isHovering ? LemmaColors.textSecondary : LemmaColors.textTertiary)
                    .frame(width: 14 * zoom)
                Text(title)
                    .font(LemmaTypography.ui(zoom))
                    .foregroundStyle(isHovering ? LemmaColors.textPrimary : LemmaColors.textSecondary)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11 * zoom))
                        .foregroundStyle(LemmaColors.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8 * zoom)
            .frame(height: 28 * zoom)
            .background(
                isHovering ? LemmaColors.surfaceHover : Color.clear,
                in: RoundedRectangle(cornerRadius: 6 * zoom, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isHovering)
        .accessibilityLabel(detail.isEmpty ? title : "\(title), \(detail)")
    }
}

struct LemmaEquationBlock: View {
    let source: String
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        TutorMathText(source: source, fontSize: 20 * zoom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20 * zoom)
            .padding(.vertical, 18 * zoom)
            .background(LemmaColors.accentMuted.opacity(0.55),
                        in: RoundedRectangle(cornerRadius: LemmaRadius.control * zoom))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2 * zoom)
                    .fill(LemmaColors.accent)
                    .frame(width: 3 * zoom)
                    .padding(.vertical, 12 * zoom)
            }
    }
}

struct LemmaKnowledgeMotif: View {
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12 * zoom)
                .fill(LemmaColors.accentMuted.opacity(0.65))
                .frame(width: 150 * zoom, height: 112 * zoom)
                .rotationEffect(.degrees(-7))
                .offset(x: -10 * zoom, y: 4 * zoom)
            RoundedRectangle(cornerRadius: 12 * zoom)
                .fill(LemmaColors.surfaceElevated)
                .overlay {
                    RoundedRectangle(cornerRadius: 12 * zoom)
                        .stroke(LemmaColors.border, lineWidth: 1)
                }
                .frame(width: 150 * zoom, height: 112 * zoom)
                .rotationEffect(.degrees(4))
                .offset(x: 7 * zoom, y: -4 * zoom)
            VStack(alignment: .leading, spacing: 9 * zoom) {
                Text("IDEA 01")
                    .font(.system(size: 10 * zoom, weight: .semibold, design: .monospaced))
                    .foregroundStyle(LemmaColors.accent)
                Text("∫ u dv = uv − ∫ v du")
                    .font(.system(size: 13 * zoom, weight: .medium, design: .serif))
                    .foregroundStyle(LemmaColors.textPrimary)
                    .lineLimit(2)
            }
            .frame(width: 125 * zoom, alignment: .leading)
            .rotationEffect(.degrees(4))
            .offset(x: 7 * zoom, y: -4 * zoom)
        }
        .frame(width: 190 * zoom, height: 142 * zoom)
        .accessibilityHidden(true)
    }
}
