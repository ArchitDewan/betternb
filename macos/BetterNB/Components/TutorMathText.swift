import AppKit
import SwiftMath
import SwiftUI

enum TutorMathSection: Equatable {
    case flow([TutorMathFlowToken])
    case display(String)
}

enum TutorMathFlowToken: Equatable {
    case word(String)
    case space
    case math(String)
}

enum TutorMathLayoutPlan {
    static func sections(for items: [MathRenderItem]) -> [TutorMathSection] {
        var result: [TutorMathSection] = []
        var flow: [MathRenderItem] = []
        func flush() {
            if !flow.isEmpty {
                result.append(.flow(flowTokens(flow)))
                flow = []
            }
        }
        for item in items {
            switch item {
            case .display(let latex) where LatexCleanup.isStructuralDisplay(latex):
                flush()
                result.append(.display(latex))
            case .display(let latex):
                flow.append(contentsOf: inlinePieces(latex))
            case .prose, .inline:
                flow.append(item)
            }
        }
        flush()
        return result
    }

    static func flowTokens(_ items: [MathRenderItem]) -> [TutorMathFlowToken] {
        var tokens: [TutorMathFlowToken] = []
        for item in items {
            switch item {
            case .prose(let text):
                for piece in wordTokens(text) {
                    if piece.allSatisfy(\.isWhitespace) {
                        appendSpace(to: &tokens)
                    } else {
                        appendWord(piece, to: &tokens)
                    }
                }
            case .inline(let latex):
                if let previous = tokens.last, needsSpace(between: previous, and: .math(latex)) {
                    appendSpace(to: &tokens)
                }
                tokens.append(.math(latex))
            case .display:
                break
            }
        }
        return tokens
    }

    static func accessibleText(for items: [MathRenderItem]) -> String {
        sections(for: items).map { section in
            switch section {
            case .flow(let tokens):
                return tokens.map { token in
                    switch token {
                    case .word(let text): text
                    case .space: " "
                    case .math(let latex): latex
                    }
                }.joined()
            case .display(let latex):
                return latex
            }
        }.joined(separator: "\n")
    }

    private static let closingPunctuation = CharacterSet(charactersIn: ".,;:!?)]}’”")
    private static let openingPunctuation = CharacterSet(charactersIn: "([{‘“")

    private static func appendWord(_ word: String, to tokens: inout [TutorMathFlowToken]) {
        let token = TutorMathFlowToken.word(word)
        if let previous = tokens.last, needsSpace(between: previous, and: token) {
            appendSpace(to: &tokens)
        }
        tokens.append(token)
    }

    private static func appendSpace(to tokens: inout [TutorMathFlowToken]) {
        guard !tokens.isEmpty, tokens.last != .space else { return }
        tokens.append(.space)
    }

    private static func needsSpace(
        between previous: TutorMathFlowToken,
        and next: TutorMathFlowToken
    ) -> Bool {
        if previous == .space || next == .space { return false }
        guard let previousCharacter = trailingCharacter(of: previous),
              let nextCharacter = leadingCharacter(of: next) else {
            return false
        }
        if character(nextCharacter, belongsTo: closingPunctuation) { return false }
        if character(previousCharacter, belongsTo: openingPunctuation) { return false }
        return true
    }

    private static func leadingCharacter(of token: TutorMathFlowToken) -> Character? {
        switch token {
        case .word(let text): text.first
        case .math: "x"
        case .space: nil
        }
    }

    private static func trailingCharacter(of token: TutorMathFlowToken) -> Character? {
        switch token {
        case .word(let text): text.last
        case .math: "x"
        case .space: nil
        }
    }

    private static func character(_ character: Character, belongsTo set: CharacterSet) -> Bool {
        character.unicodeScalars.allSatisfy(set.contains)
    }

    private static func inlinePieces(_ latex: String) -> [MathRenderItem] {
        LatexCleanup.intents(for: latex).map { piece in
            switch piece {
            case .prose(let text):
                return .prose(text)
            case .math(let math):
                return .inline(math)
            }
        }
    }

    private static func wordTokens(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for character in text {
            if character.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(character))
            } else {
                if shouldInsertSentenceSpace(before: character, current: current) {
                    tokens.append(current)
                    tokens.append(" ")
                    current = ""
                }
                current.append(character)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }

    private static func shouldInsertSentenceSpace(before next: Character, current: String) -> Bool {
        guard next.isUppercase, let last = current.last, ".!?".contains(last) else {
            return false
        }
        return current.count == 1 || current.filter(\.isLetter).count >= 2
    }
}

struct TutorMathText: View {
    let markup: MathMarkup
    var fontSize: CGFloat = 15
    var weight: Font.Weight = .regular
    var design: Font.Design = .default
    var color: Color = AppTheme.primaryText
    var compact: Bool = false

    init(
        source: String,
        fontSize: CGFloat = 15,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        color: Color = AppTheme.primaryText,
        compact: Bool = false
    ) {
        self.markup = MathMarkup.parse(source)
        self.fontSize = fontSize
        self.weight = weight
        self.design = design
        self.color = color
        self.compact = compact
    }

    init(
        markup: MathMarkup,
        fontSize: CGFloat = 15,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        color: Color = AppTheme.primaryText,
        compact: Bool = false
    ) {
        self.markup = markup
        self.fontSize = fontSize
        self.weight = weight
        self.design = design
        self.color = color
        self.compact = compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: fontSize * 0.7) {
            ForEach(Array(TutorMathLayoutPlan.sections(for: markup.renderPlan).enumerated()), id: \.offset) { _, section in
                switch section {
                case .flow(let tokens):
                    flowView(tokens)
                case .display(let latex):
                    swiftMath(latex, display: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, compact ? 0 : fontSize * 0.3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(readableLabel(markup))
    }

    @ViewBuilder
    private func flowView(_ tokens: [TutorMathFlowToken]) -> some View {
        InlineMathFlow(lineSpacing: fontSize * 0.28) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                switch token {
                case .word(let text):
                    Text(text)
                        .font(.system(size: fontSize, weight: weight, design: design))
                        .foregroundStyle(color)
                        .tracking(0.2)
                        .fixedSize(horizontal: true, vertical: true)
                case .space:
                    Text(" ")
                        .font(.system(size: fontSize, weight: weight, design: design))
                        .fixedSize(horizontal: true, vertical: true)
                case .math(let latex):
                    swiftMath(latex, display: false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func swiftMath(_ latex: String, display: Bool) -> some View {
        let sanitized = LatexCleanup.sanitizeForRenderer(latex)
        if Self.canRender(sanitized) {
            SwiftMathView(
                latex: sanitized,
                fontSize: display ? fontSize * 1.18 : fontSize,
                color: color,
                display: display
            )
        } else {
            Text(LatexCleanup.fallbackText(sanitized))
                .font(.system(size: fontSize, weight: weight, design: design))
                .foregroundStyle(color)
                .fixedSize(horizontal: true, vertical: true)
        }
    }

    private static func canRender(_ latex: String) -> Bool {
        var error: NSError?
        _ = MTMathListBuilder.build(fromString: latex, error: &error)
        return error == nil
    }

    private func readableLabel(_ markup: MathMarkup) -> String {
        TutorMathLayoutPlan.accessibleText(for: markup.renderPlan)
            .replacingOccurrences(of: #"\\[a-zA-Z]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[{}^_]", with: "", options: .regularExpression)
    }
}

private struct SwiftMathView: NSViewRepresentable {
    var latex: String
    var fontSize: CGFloat
    var color: Color
    var display: Bool

    func makeNSView(context: Context) -> MTMathUILabel {
        let view = MTMathUILabel()
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        return view
    }

    func updateNSView(_ view: MTMathUILabel, context: Context) {
        apply(to: view)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: MTMathUILabel, context: Context) -> CGSize? {
        apply(to: nsView)
        let fitting = nsView.fittingSize
        var width = max(fitting.width, 1)
        var height = max(fitting.height, fontSize * 1.4)
        if let maxWidth = proposal.width, maxWidth.isFinite, maxWidth > 0, width > maxWidth {
            let scale = max(0.55, maxWidth / width)
            nsView.fontSize = fontSize * scale
            let scaled = nsView.fittingSize
            width = min(maxWidth, max(scaled.width, 1))
            height = max(scaled.height, fontSize * 1.2)
        }
        return CGSize(width: width, height: height)
    }

    private func apply(to view: MTMathUILabel) {
        view.displayErrorInline = false
        view.fontSize = fontSize
        view.textAlignment = .left
        view.labelMode = display ? .display : .text
        view.textColor = NSColor(color)
        let hug: NSLayoutConstraint.Priority = display ? .defaultLow : .required
        view.setContentHuggingPriority(hug, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.latex = latex
        if view.error != nil {
            view.latex = ""
        }
        view.needsLayout = true
    }
}

private struct InlineMathFlow: Layout {
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for size in sizes {
            if x > 0, maxWidth.isFinite, x + size.width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            lineHeight = max(lineHeight, size.height)
            x += size.width
            usedWidth = max(usedWidth, x)
        }
        let width = maxWidth.isFinite && maxWidth > 0 ? maxWidth : usedWidth
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var lineStart = 0
        var x = bounds.minX
        var y = bounds.minY

        func flush(_ end: Int) {
            let height = sizes[lineStart..<end].map(\.height).max() ?? 0
            var cursor = bounds.minX
            for index in lineStart..<end {
                let size = sizes[index]
                subviews[index].place(
                    at: CGPoint(x: cursor, y: y + (height - size.height) * 0.5),
                    proposal: ProposedViewSize(size)
                )
                cursor += size.width
            }
            y += height + lineSpacing
            lineStart = end
        }

        for (index, size) in sizes.enumerated() {
            if index > lineStart, x + size.width > bounds.maxX {
                flush(index)
                x = bounds.minX
            }
            x += size.width
        }
        if lineStart < subviews.count {
            let height = sizes[lineStart...].map(\.height).max() ?? 0
            var cursor = bounds.minX
            for index in lineStart..<subviews.count {
                let size = sizes[index]
                subviews[index].place(
                    at: CGPoint(x: cursor, y: y + (height - size.height) * 0.5),
                    proposal: ProposedViewSize(size)
                )
                cursor += size.width
            }
        }
    }
}
