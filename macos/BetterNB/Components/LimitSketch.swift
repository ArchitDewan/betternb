import SwiftUI

struct LimitSketch: View {
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 10 * zoom
            let origin = CGPoint(x: inset, y: size.height - inset)
            let maxX = size.width - inset
            let maxY = inset

            var axes = Path()
            axes.move(to: CGPoint(x: origin.x, y: maxY))
            axes.addLine(to: origin)
            axes.addLine(to: CGPoint(x: maxX, y: origin.y))
            context.stroke(axes, with: .color(AppTheme.tertiaryText), lineWidth: zoom)

            let x2 = origin.x + (maxX - origin.x) * 0.58
            let leftY = origin.y - (origin.y - maxY) * 0.62
            let rightY = origin.y - (origin.y - maxY) * 0.28

            var left = Path()
            left.move(to: CGPoint(x: origin.x + 8 * zoom, y: origin.y - 18 * zoom))
            left.addQuadCurve(
                to: CGPoint(x: x2 - 7 * zoom, y: leftY),
                control: CGPoint(x: origin.x + 50 * zoom, y: origin.y - 70 * zoom)
            )
            context.stroke(left, with: .color(AppTheme.chalk), style: StrokeStyle(lineWidth: 2 * zoom, lineCap: .round))

            var right = Path()
            right.move(to: CGPoint(x: x2 + 7 * zoom, y: rightY))
            right.addQuadCurve(
                to: CGPoint(x: maxX - 6 * zoom, y: origin.y - 36 * zoom),
                control: CGPoint(x: x2 + 48 * zoom, y: origin.y - 8 * zoom)
            )
            context.stroke(right, with: .color(AppTheme.ink), style: StrokeStyle(lineWidth: 2 * zoom, lineCap: .round))

            let hole = 10 * zoom
            let open = CGRect(x: x2 - hole / 2, y: leftY - hole / 2, width: hole, height: hole)
            context.stroke(Path(ellipseIn: open), with: .color(AppTheme.chalk), lineWidth: 1.6 * zoom)
        }
        .frame(width: 196 * zoom, height: 118 * zoom)
        .accessibilityLabel("Graph of f of x approaching 2 from both sides")
    }
}
