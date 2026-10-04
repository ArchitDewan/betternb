import SwiftUI

struct TutorMathText: View {
    let source: String
    var fontSize: CGFloat = 15
    var weight: Font.Weight = .regular
    var design: Font.Design = .default
    var color: Color = AppTheme.primaryText

    var body: some View {
        let markup = MathMarkup.parse(source)
        VStack(alignment: .leading, spacing: fontSize * 0.9) {
            ForEach(Array(markup.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(markup.accessibleText)
    }

    @ViewBuilder
    private func blockView(_ block: MathBlock) -> some View {
        switch block {
        case .paragraph(let runs) where runs.allSatisfy(\.isText):
            proseText(runs.textContent)
        case .paragraph(let runs):
            wrappingItems(flowItems(from: runs))
        case .display(let node) where node.isMostlyProse:
            wrappingItems(items(from: node))
                .padding(.vertical, fontSize * 0.2)
        case .display(let node):
            MathNodeView(
                node: node,
                fontSize: fontSize * 1.22,
                weight: weight,
                design: .serif,
                color: color
            )
            .frame(
                maxWidth: .infinity,
                alignment: {
                    if case .lines = node { return .leading }
                    return .center
                }()
            )
            .padding(.vertical, fontSize * 0.7)
            .padding(.horizontal, fontSize * 0.15)
        }
    }

    private func proseText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: weight, design: design))
            .lineSpacing(fontSize * 0.28)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    private func wrappingItems(_ items: [MathFlowItem]) -> some View {
        MathFlowLayout(hSpacing: 0, vSpacing: fontSize * 0.55) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                flowView(item)
            }
        }
    }

    @ViewBuilder
    private func flowView(_ item: MathFlowItem) -> some View {
        switch item {
        case .word(let text):
            Text(text)
                .font(.system(size: fontSize, weight: weight, design: design))
                .textSelection(.enabled)
        case .space:
            Color.clear
                .frame(width: max(8, fontSize * 0.42), height: 1)
        case .math(let node):
            MathNodeView(node: node, fontSize: fontSize, weight: weight, design: .serif, color: color)
        }
    }

    private func flowItems(from runs: [InlineRun]) -> [MathFlowItem] {
        runs.flatMap { run -> [MathFlowItem] in
            switch run {
            case .text(let text):
                return spacedWords(in: text)
            case .math(let node), .boxed(let node):
                return items(from: node)
            }
        }
    }

    private func items(from node: MathNode) -> [MathFlowItem] {
        switch node {
        case .sequence(let nodes):
            return nodes.flatMap { items(from: $0) }
        case .lines(let rows):
            return Array(rows.enumerated().flatMap { index, row -> [MathFlowItem] in
                var rowItems = items(from: row)
                if index < rows.count - 1 {
                    rowItems.append(.space)
                }
                return rowItems
            })
        case .symbol(let text) where text == " ":
            return [.space]
        case .symbol(let text) where text.contains(where: \.isWhitespace):
            return spacedWords(in: text)
        case .symbol(let text) where text.filter(\.isLetter).count >= 2 && !["sin", "cos", "tan", "sec", "csc", "cot", "ln", "log", "exp", "lim"].contains(text):
            return spacedWords(in: text)
        default:
            return [.math(node)]
        }
    }

    private func spacedWords(in text: String) -> [MathFlowItem] {
        var items: [MathFlowItem] = []
        let pieces = text.split(separator: " ", omittingEmptySubsequences: false)
        for (index, piece) in pieces.enumerated() {
            if !piece.isEmpty {
                items.append(.word(String(piece)))
            }
            if index < pieces.count - 1 {
                items.append(.space)
            }
        }
        return items
    }
}

private enum MathFlowItem {
    case word(String)
    case space
    case math(MathNode)
}

private extension InlineRun {
    var isText: Bool {
        if case .text = self { return true }
        return false
    }
}

private extension Array where Element == InlineRun {
    var textContent: String {
        compactMap { run in
            if case .text(let text) = run { return text }
            return nil
        }.joined()
    }
}

private struct MathNodeView: View {
    let node: MathNode
    var fontSize: CGFloat
    var weight: Font.Weight
    var design: Font.Design
    var color: Color

    var body: some View {
        switch node {
        case .symbol(let text) where text.allSatisfy(\.isWhitespace):
            Color.clear
                .frame(width: max(8, fontSize * (text.count > 1 ? 0.7 : 0.4)), height: 1)
        case .symbol(let text):
            Text(text)
                .font(.system(size: fontSize, weight: weight, design: design))
                .padding(.horizontal, symbolPadding(for: text))
                .textSelection(.enabled)
        case .sequence(let nodes):
            MathFlowLayout(hSpacing: 0, vSpacing: fontSize * 0.5) {
                ForEach(Array(spaced(nodes).enumerated()), id: \.offset) { _, child in
                    MathNodeView(node: child, fontSize: fontSize, weight: weight, design: design, color: color)
                }
            }
        case .lines(let rows):
            VStack(alignment: .leading, spacing: fontSize * 0.62) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    MathNodeView(node: row, fontSize: fontSize, weight: weight, design: design, color: color)
                }
            }
        case .fraction(let numerator, let denominator):
            VStack(spacing: fontSize * 0.22) {
                MathNodeView(node: numerator, fontSize: fontSize * 0.82, weight: weight, design: design, color: color)
                Rectangle()
                    .fill(color)
                    .frame(height: 1.1)
                MathNodeView(node: denominator, fontSize: fontSize * 0.82, weight: weight, design: design, color: color)
            }
            .padding(.horizontal, fontSize * 0.22)
            .fixedSize()
        case .superscript(let base, let exponent):
            HStack(alignment: .top, spacing: fontSize * 0.04) {
                MathNodeView(node: base, fontSize: fontSize, weight: weight, design: design, color: color)
                MathNodeView(node: exponent, fontSize: fontSize * 0.62, weight: weight, design: design, color: color)
                    .offset(y: -fontSize * 0.28)
                    .padding(.trailing, fontSize * 0.06)
            }
        case .sub(let base, let script):
            HStack(alignment: .bottom, spacing: fontSize * 0.04) {
                MathNodeView(node: base, fontSize: fontSize, weight: weight, design: design, color: color)
                MathNodeView(node: script, fontSize: fontSize * 0.62, weight: weight, design: design, color: color)
                    .offset(y: fontSize * 0.1)
            }
        case .sqrt(let inner):
            HStack(alignment: .center, spacing: fontSize * 0.12) {
                Text("√")
                    .font(.system(size: fontSize * 1.05, weight: weight, design: design))
                MathNodeView(node: inner, fontSize: fontSize, weight: weight, design: design, color: color)
                    .padding(.top, 3)
                    .padding(.horizontal, fontSize * 0.08)
                    .overlay(alignment: .top) {
                        Rectangle().fill(color).frame(height: 1.1)
                    }
            }
            .padding(.trailing, fontSize * 0.16)
        case .boxed(let inner):
            MathNodeView(node: inner, fontSize: fontSize, weight: weight, design: design, color: color)
                .padding(.horizontal, fontSize * 0.85)
                .padding(.vertical, fontSize * 0.55)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(color.opacity(0.85), lineWidth: 1.1)
                }
        }
    }

    private func symbolPadding(for text: String) -> CGFloat {
        if MathNode.relations.contains(text) { return fontSize * 0.16 }
        if MathNode.binaryOperators.contains(text) { return fontSize * 0.1 }
        if MathNode.functionNames.contains(text) { return fontSize * 0.04 }
        return 0
    }

    private func spaced(_ nodes: [MathNode]) -> [MathNode] {
        var result: [MathNode] = []
        for node in nodes {
            if case .symbol(" ") = node {
                result.append(node)
                continue
            }
            if let last = result.last, last.isWordLike, node.isWordLike {
                result.append(.symbol(" "))
            }
            result.append(node)
        }
        return result
    }
}

private struct MathFlowLayout: Layout {
    var hSpacing: CGFloat = 0
    var vSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(in: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(in: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, arrangement.frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(in width: CGFloat?, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = width ?? .greatestFiniteMagnitude
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var rowStart = 0

        func alignCurrentRow() {
            for index in rowStart..<frames.count {
                var frame = frames[index]
                frame.origin.y = y + (rowHeight - frame.height) / 2
                frames[index] = frame
            }
        }

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                alignCurrentRow()
                x = 0
                y += rowHeight + vSpacing
                rowHeight = 0
                rowStart = frames.count
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            rowHeight = max(rowHeight, size.height)
            x += size.width + hSpacing
        }
        alignCurrentRow()
        let measuredWidth = frames.map(\.maxX).max() ?? 0
        let measuredHeight = frames.map(\.maxY).max() ?? 0
        return (CGSize(width: measuredWidth, height: measuredHeight), frames)
    }
}
