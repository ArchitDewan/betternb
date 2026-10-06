import Foundation

enum MathFeature: Sendable {
    case fraction
    case boxed
    case superscript
}

enum MathBlock: Equatable, Sendable {
    case paragraph([InlineRun])
    case display(String)
}

enum MathRenderItem: Equatable, Sendable {
    case prose(String)
    case inline(String)
    case display(String)
}

enum InlineRun: Equatable, Sendable {
    case text(String)
    case math(String)
    case boxed(String)

    var isText: Bool {
        if case .text = self { return true }
        return false
    }

    var latex: String? {
        switch self {
        case .math(let latex), .boxed(let latex):
            return latex
        case .text:
            return nil
        }
    }
}

indirect enum MathNode: Equatable, Sendable {
    case sequence([MathNode])
    case lines([MathNode])
    case symbol(String)
    case fraction(MathNode, MathNode)
    case superscript(MathNode, MathNode)
    case sub(MathNode, MathNode)
    case sqrt(MathNode)
    case boxed(MathNode)
}

struct MathMarkup: Equatable, Sendable {
    var blocks: [MathBlock]

    var accessibleText: String {
        blocks.map(\.accessibleText).filter { !$0.isEmpty }.joined(separator: "\n")
    }

    var isPlainProse: Bool {
        blocks.allSatisfy { block in
            guard case .paragraph(let runs) = block else { return false }
            return runs.allSatisfy(\.isText)
        }
    }

    func contains(_ feature: MathFeature) -> Bool {
        blocks.contains { block in
            switch block {
            case .display(let latex):
                return Self.matches(feature, in: latex)
            case .paragraph(let runs):
                return runs.contains { run in
                    switch run {
                    case .boxed where feature == .boxed:
                        return true
                    case .boxed(let latex), .math(let latex):
                        return Self.matches(feature, in: latex)
                    case .text:
                        return false
                    }
                }
            }
        }
    }

    private static func matches(_ feature: MathFeature, in latex: String) -> Bool {
        switch feature {
        case .fraction:
            return latex.contains(#"\frac"#)
        case .boxed:
            return latex.contains(#"\boxed"#)
        case .superscript:
            return latex.contains("^")
        }
    }

    var latexChunks: [String] {
        blocks.flatMap { block -> [String] in
            switch block {
            case .display(let latex):
                return [latex]
            case .paragraph(let runs):
                return runs.compactMap(\.latex)
            }
        }
    }

    var renderPlan: [MathRenderItem] {
        LatexCleanup.renderPlan(from: blocks)
    }

    static func parse(_ source: String) -> MathMarkup {
        var parser = MathDocumentParser(source)
        return MathMarkup(blocks: parser.parseDocument()).prepared()
    }

    func prepared() -> MathMarkup {
        MathMarkup(blocks: LatexCleanup.tidy(blocks.flatMap { LatexCleanup.expand($0, depth: 0) }))
    }

    static func livePreview(for source: String) -> MathMarkup? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let markup = parse(trimmed).mathOnly()
        return markup.blocks.isEmpty ? nil : markup
    }

    func mathOnly() -> MathMarkup {
        var extracted: [MathBlock] = []
        for block in blocks {
            switch block {
            case .display(let latex):
                extracted.append(.display(latex))
            case .paragraph(let runs):
                var joined = ""
                func flush() {
                    let trimmed = joined.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        extracted.append(.display(trimmed))
                    }
                    joined = ""
                }
                for run in runs {
                    switch run {
                    case .math(let latex):
                        if !joined.isEmpty { joined += " " }
                        joined += latex
                    case .boxed(let latex):
                        flush()
                        extracted.append(.display(#"\boxed{"# + latex + "}"))
                    case .text(let text):
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            if !joined.isEmpty { joined += " " }
                        } else if trimmed.allSatisfy({ ",;".contains($0) }) {
                            if !joined.isEmpty {
                                joined += trimmed.hasPrefix(",") ? ", " : "; "
                            }
                        } else {
                            flush()
                        }
                    }
                }
                flush()
            }
        }
        return MathMarkup(blocks: extracted)
    }
}

private extension MathBlock {
    var accessibleText: String {
        switch self {
        case .paragraph(let runs):
            return runs.map(\.accessibleText).joined()
        case .display(let latex):
            return latex
        }
    }
}

private extension InlineRun {
    var accessibleText: String {
        switch self {
        case .text(let text):
            return text
        case .math(let latex), .boxed(let latex):
            return latex
        }
    }
}

extension MathNode {
    static let largeOperatorSymbols: Set<String> = ["∫", "∬", "∭", "∮", "∑", "∏"]

    static let functionNames: Set<String> = [
        "sin", "cos", "tan", "sec", "csc", "cot", "ln", "log", "exp", "lim",
        "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh",
    ]

    static let binaryOperators: Set<String> = ["+", "·", "×", "÷", "±"]
    static let relations: Set<String> = ["=", "≠", "≤", "≥", "≈", "→", "<", ">"]

    var largeOperatorLimits: (symbol: String, lower: MathNode?, upper: MathNode?)? {
        switch self {
        case .symbol(let text) where Self.largeOperatorSymbols.contains(text):
            return (text, nil as MathNode?, nil as MathNode?)
        case .sub(let base, let lower):
            guard let inner = base.largeOperatorLimits else { return nil }
            return (inner.symbol, lower, inner.upper)
        case .superscript(let base, let upper):
            guard let inner = base.largeOperatorLimits else { return nil }
            return (inner.symbol, inner.lower, upper)
        default:
            return nil
        }
    }

    var isRelation: Bool {
        if case .symbol(let text) = self { return Self.relations.contains(text) }
        return false
    }

    var isBinaryOperator: Bool {
        if case .symbol(let text) = self { return Self.binaryOperators.contains(text) }
        return false
    }

    var isMinus: Bool {
        if case .symbol(let text) = self { return text == "-" }
        return false
    }

    var isFunctionName: Bool {
        switch self {
        case .symbol(let text):
            return Self.functionNames.contains(text)
        case .superscript(let base, _), .sub(let base, _):
            return base.isFunctionName
        default:
            return false
        }
    }

    var latex: String {
        switch self {
        case .sequence(let nodes):
            return nodes.map(\.latex).joined()
        case .lines(let rows):
            return rows.map(\.latex).joined(separator: #" \\ "#)
        case .symbol(let text):
            return Self.latexSymbol(text)
        case .fraction(let numerator, let denominator):
            return #"\frac{"# + numerator.latex + "}{" + denominator.latex + "}"
        case .superscript(let base, let exponent):
            return "{" + base.latex + "}^{" + exponent.latex + "}"
        case .sub(let base, let script):
            return "{" + base.latex + "}_{" + script.latex + "}"
        case .sqrt(let inner):
            return #"\sqrt{"# + inner.latex + "}"
        case .boxed(let inner):
            return #"\boxed{"# + inner.latex + "}"
        }
    }

    private static func latexSymbol(_ text: String) -> String {
        if text.hasPrefix("\\") { return text }
        if functionNames.contains(text) { return "\\" + text + " " }
        let mapped: [String: String] = [
            "∫": #"\int "#,
            "∬": #"\iint "#,
            "∭": #"\iiint "#,
            "∮": #"\oint "#,
            "∑": #"\sum "#,
            "∏": #"\prod "#,
            "·": #"\cdot "#,
            "×": #"\times "#,
            "÷": #"\div "#,
            "±": #"\pm "#,
            "≠": #"\neq "#,
            "≤": #"\leq "#,
            "≥": #"\geq "#,
            "≈": #"\approx "#,
            "→": #"\rightarrow "#,
            "∞": #"\infty "#,
            "∂": #"\partial "#,
            "∇": #"\nabla "#,
            "π": #"\pi "#,
            "θ": #"\theta "#,
            "α": #"\alpha "#,
            "β": #"\beta "#,
            "γ": #"\gamma "#,
            "δ": #"\delta "#,
            "ε": #"\epsilon "#,
            "λ": #"\lambda "#,
            "μ": #"\mu "#,
            "σ": #"\sigma "#,
            "φ": #"\phi "#,
            "ψ": #"\psi "#,
            "ω": #"\omega "#,
            "√": #"\sqrt"#,
        ]
        return mapped[text] ?? text
    }
}

enum LatexCleanup {
    static let mathWords: Set<String> = [
        "sin", "cos", "tan", "sec", "csc", "cot", "ln", "log", "exp", "lim",
        "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh", "inf", "min", "max",
        "det", "dim", "ker", "mod", "arg", "deg", "gcd", "lcm", "sup",
    ]

    static let mathCommands: Set<String> = [
        "int", "iint", "iiint", "oint", "frac", "dfrac", "tfrac", "sum", "prod",
        "sqrt", "sin", "cos", "tan", "sec", "csc", "cot", "ln", "log", "exp", "lim",
        "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh", "pi", "theta", "alpha",
        "beta", "gamma", "delta", "lambda", "mu", "sigma", "omega", "infty", "cdot",
        "times", "div", "pm", "neq", "leq", "geq", "left", "right", "overline",
        "mathrm", "mathbf", "partial", "infty", "cdot",
    ]

    static func prepare(_ latex: String) -> String {
        var result = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        result = hoistIntegralOutOfFraction(result)
        result = slashAfterIntegralToFrac(result)
        result = braceBareScripts(result)
        return result
    }

    static func braceBareScripts(_ latex: String) -> String {
        latex.replacingOccurrences(
            of: #"([_^])(?!\{)([+\-]?\\[a-zA-Z]+|[+\-]?[A-Za-z0-9]+|[+\-])"#,
            with: "$1{$2}",
            options: .regularExpression
        )
    }

    static func sanitizeForRenderer(_ latex: String) -> String {
        prepare(latex)
            .replacingOccurrences(of: "→", with: #"\rightarrow "#)
            .replacingOccurrences(of: "∞", with: #"\infty "#)
            .replacingOccurrences(of: "⁻", with: "^{-}")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
    }

    static func fallbackText(_ latex: String) -> String {
        let readable = sanitizeForRenderer(latex)
            .replacingOccurrences(of: #"\\int"#, with: "∫")
            .replacingOccurrences(of: #"\\sum"#, with: "∑")
            .replacingOccurrences(of: #"\\lim"#, with: "lim")
            .replacingOccurrences(of: #"\\infty"#, with: "∞")
            .replacingOccurrences(of: #"\\rightarrow"#, with: "→")
            .replacingOccurrences(of: #"\\to\b"#, with: "→", options: .regularExpression)
            .replacingOccurrences(of: #"\\frac\{([^{}]+)\}\{([^{}]+)\}"#, with: "($1)/($2)", options: .regularExpression)
        return readableInline(readable)
    }

    static func tidy(_ blocks: [MathBlock]) -> [MathBlock] {
        var result: [MathBlock] = []
        var pending: [InlineRun] = []

        func flush() {
            let coalesced = coalesce(pending).filter { run in
                if case .text(let text) = run {
                    return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                return true
            }
            if !coalesced.isEmpty {
                result.append(.paragraph(coalesced))
            }
            pending = []
        }

        let hasProse = blocks.contains { block in
            guard case .paragraph(let runs) = block else { return false }
            return runs.contains { run in
                if case .text(let text) = run {
                    return text.contains(where: \.isLetter)
                }
                return false
            }
        }

        for block in blocks {
            switch block {
            case .paragraph(let runs):
                pending.append(contentsOf: runs)
            case .display(let latex) where hasProse && !isStructuralDisplay(latex):
                pending.append(.math(prepare(latex)))
            case .display(let latex):
                flush()
                result.append(.display(prepare(latex)))
            }
        }
        flush()
        return result
    }

    static func isStructuralDisplay(_ latex: String) -> Bool {
        latex.contains(#"\begin"#) || latex.contains("\\\\")
    }

    static func renderPlan(from blocks: [MathBlock]) -> [MathRenderItem] {
        var items: [MathRenderItem] = []
        for block in blocks {
            switch block {
            case .display(let latex):
                items.append(.display(latex))
            case .paragraph(let runs):
                for run in runs {
                    switch run {
                    case .text(let text) where !text.isEmpty:
                        items.append(.prose(text))
                    case .text:
                        break
                    case .math(let latex):
                        items.append(.inline(latex))
                    case .boxed(let latex):
                        items.append(.inline(#"\boxed{"# + latex + "}"))
                    }
                }
            }
        }
        return items
    }

    static func expand(_ block: MathBlock, depth: Int) -> [MathBlock] {
        switch block {
        case .display(let latex):
            let cleaned = prepare(latex)
            if depth < 2, hasEnglishSentence(cleaned) {
                var parser = MathDocumentParser(cleaned)
                return parser.parseDocument(promoteLone: false).flatMap { expand($0, depth: depth + 1) }
            }
            return [.display(cleaned)]
        case .paragraph(let runs):
            var expanded: [InlineRun] = []
            var blocks: [MathBlock] = []
            func flushRuns() {
                let coalesced = coalesce(expanded).filter { run in
                    if case .text(let text) = run {
                        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }
                    return true
                }
                if !coalesced.isEmpty {
                    blocks.append(.paragraph(coalesced))
                }
                expanded = []
            }
            for run in runs {
                switch run {
                case .text:
                    expanded.append(run)
                case .math(let latex):
                    let cleaned = prepare(latex)
                    if depth < 2, hasEnglishSentence(cleaned) {
                        var parser = MathDocumentParser(cleaned)
                        for inner in parser.parseDocument(promoteLone: false).flatMap({ expand($0, depth: depth + 1) }) {
                            switch inner {
                            case .paragraph(let innerRuns):
                                expanded.append(contentsOf: innerRuns)
                            case .display:
                                flushRuns()
                                blocks.append(inner)
                            }
                        }
                    } else {
                        expanded.append(.math(cleaned))
                    }
                case .boxed(let latex):
                    let cleaned = prepare(latex)
                    if hasEnglishSentence(cleaned) {
                        expanded.append(.text(readableInline(cleaned)))
                    } else {
                        expanded.append(.boxed(cleaned))
                    }
                }
            }
            flushRuns()
            return blocks
        }
    }

    static func isDisplayGrade(_ latex: String) -> Bool {
        latex.contains(#"\int"#) || latex.contains(#"\sum"#) || latex.contains(#"\prod"#)
            || latex.contains(#"\lim"#) || latex.contains(#"\begin"#) || latex.contains(#"\boxed"#)
    }

    static func isEquation(_ latex: String) -> Bool {
        latex.contains("=")
    }

    static func isDisplayEquation(_ latex: String) -> Bool {
        guard isEquation(latex) else { return false }
        if isDisplayGrade(latex) || latex.contains(#"\frac"#) || latex.contains("^") {
            return true
        }
        return latex.contains("(") && latex.contains(")") && (latex.contains("+") || latex.contains(#"\sin"#))
    }

    static func isSentenceMath(_ latex: String) -> Bool {
        let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        if isDisplayGrade(trimmed) || trimmed.contains(#"\frac"#) { return false }
        if trimmed.contains("="), trimmed.contains("^"), trimmed.contains(#"\sin"#) || trimmed.contains(#"\cos"#) {
            return false
        }
        return true
    }

    enum RenderIntent: Equatable, Sendable {
        case math(String)
        case prose(String)
    }

    static func isPureMath(_ latex: String) -> Bool {
        let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if englishWordCount(trimmed) > 0 { return false }
        return isDisplayGrade(trimmed) || containsMathCommand(trimmed) || trimmed.contains("\\")
            || trimmed.contains("^") || trimmed.contains("_")
    }

    static func intents(for latex: String) -> [RenderIntent] {
        let peeled = peelEnglish(latex)
        var pieces: [RenderIntent] = []
        if let leading = peeled.leading?.trimmingCharacters(in: .whitespacesAndNewlines), !leading.isEmpty {
            pieces.append(.prose(leading))
        }
        let math = peeled.math.trimmingCharacters(in: .whitespacesAndNewlines)
        if !math.isEmpty {
            if isPureMath(math) || isDisplayGrade(math) || containsMathCommand(math) {
                pieces.append(.math(prepare(math)))
            } else if englishWordCount(math) >= 2 || hasEnglishSentence(math) {
                pieces.append(.prose(readableInline(math)))
            } else {
                pieces.append(.math(prepare(math)))
            }
        }
        if let trailing = peeled.trailing?.trimmingCharacters(in: .whitespacesAndNewlines), !trailing.isEmpty {
            pieces.append(.prose(trailing))
        }
        return pieces
    }

    static func readableInline(_ latex: String) -> String {
        latex
            .replacingOccurrences(of: #"\\pi"#, with: "π")
            .replacingOccurrences(of: #"\\theta"#, with: "θ")
            .replacingOccurrences(of: #"\\([a-zA-Z]+)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\^\{?2\}?"#, with: "²", options: .regularExpression)
            .replacingOccurrences(of: #"\^\{?3\}?"#, with: "³", options: .regularExpression)
            .replacingOccurrences(of: "[{}]", with: "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    static func englishWordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).map(String.init).filter(isEnglishWord).count
    }

    static func hasEnglishSentence(_ text: String) -> Bool {
        let words = stripLatexCommands(text)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter(isEnglishWord)
        if words.count >= 3 { return true }
        return isMostlyEnglish(text)
    }

    static func peelEnglish(_ latex: String) -> (leading: String?, math: String, trailing: String?) {
        var rest = latex
        var leading: String?
        if let slash = rest.firstIndex(of: "\\") {
            let before = String(rest[..<slash]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !before.isEmpty, isMostlyEnglish(before) {
                leading = before
                rest = String(rest[slash...])
            }
        } else if isMostlyEnglish(rest), !containsMathCommand(rest) {
            return (rest, "", nil)
        }
        if let split = rest.range(of: #"(?<=dx|\\,dx|\.)\s+(?=[A-Z])"#, options: .regularExpression) {
            let math = String(rest[..<split.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let trailing = String(rest[split.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if isMostlyEnglish(trailing) {
                return (leading, math, trailing)
            }
        }
        if let period = rest.range(of: ". "), isMostlyEnglish(String(rest[period.upperBound...])) {
            return (
                leading,
                String(rest[..<period.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines),
                String(rest[period.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return (leading, rest.trimmingCharacters(in: .whitespacesAndNewlines), nil)
    }

    static func isMostlyEnglish(_ text: String) -> Bool {
        if containsMathCommand(text) { return false }
        if text.contains("^") || text.contains("_") || text.contains(#"\frac"#) {
            return false
        }
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        return words.filter(isEnglishWord).count >= 2
    }

    static func containsMathCommand(_ text: String) -> Bool {
        text.contains(#"\int"#) || text.contains(#"\frac"#) || text.contains(#"\sum"#)
            || text.contains(#"\sqrt"#) || text.contains(#"\lim"#) || text.contains(#"\prod"#)
    }

    static func stripLatexCommands(_ text: String) -> String {
        text.replacingOccurrences(of: #"\\text\{([^}]*)\}"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\\[a-zA-Z]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "[{}]", with: "", options: .regularExpression)
    }

    static func coalesce(_ runs: [InlineRun]) -> [InlineRun] {
        var result: [InlineRun] = []
        for run in runs {
            if case .text(let text) = run, case .text(let last) = result.last {
                result[result.count - 1] = .text(last + text)
            } else {
                result.append(run)
            }
        }
        return result
    }

    static func hoistIntegralOutOfFraction(_ latex: String) -> String {
        guard let frac = range(of: #"\frac"#, in: latex) else { return latex }
        guard frac.upperBound < latex.endIndex, latex[frac.upperBound] == "{" else { return latex }
        guard let numClose = matchingBrace(in: latex, open: frac.upperBound) else { return latex }
        let numOpen = frac.upperBound
        let numerator = String(latex[latex.index(after: numOpen)..<numClose])
            .trimmingCharacters(in: .whitespaces)
        guard numerator.hasPrefix(#"\int"#) else { return latex }
        let afterNum = latex.index(after: numClose)
        guard afterNum < latex.endIndex, latex[afterNum] == "{" else { return latex }
        guard let denClose = matchingBrace(in: latex, open: afterNum) else { return latex }
        let denominator = String(latex[latex.index(after: afterNum)..<denClose])
        let (integral, integrand) = splitIntegral(numerator)
        guard !integrand.isEmpty else { return latex }
        let rewritten = integral + #"\frac{"# + integrand + "}{" + denominator + "}"
        let prefix = String(latex[..<frac.lowerBound])
        let suffix = String(latex[latex.index(after: denClose)...])
        return prefix + rewritten + suffix
    }

    static func slashAfterIntegralToFrac(_ latex: String) -> String {
        guard latex.contains(#"\int"#), latex.contains("/"), !latex.contains(#"\frac"#) else {
            return latex
        }
        guard let intRange = range(of: #"\int"#, in: latex) else { return latex }
        var cursor = intRange.upperBound
        while cursor < latex.endIndex {
            if latex[cursor] == "_" || latex[cursor] == "^" {
                cursor = latex.index(after: cursor)
                if cursor < latex.endIndex, latex[cursor] == "{" {
                    guard let close = matchingBrace(in: latex, open: cursor) else { break }
                    cursor = latex.index(after: close)
                    continue
                }
                if cursor < latex.endIndex { cursor = latex.index(after: cursor) }
                continue
            }
            break
        }
        let afterLimits = cursor
        guard let slash = latex[afterLimits...].firstIndex(of: "/") else { return latex }
        let numerator = latex[afterLimits..<slash].trimmingCharacters(in: .whitespaces)
        var rest = latex[latex.index(after: slash)...]
        var differential = ""
        if let dx = rest.range(of: #"\mathrm{d}"#) ?? rest.range(of: #"\,dx"#) ?? rest.range(of: "dx") {
            differential = String(rest[dx.lowerBound...])
            rest = rest[..<dx.lowerBound]
        }
        let denominator = rest.trimmingCharacters(in: .whitespaces)
        guard !numerator.isEmpty, !denominator.isEmpty else { return latex }
        let prefix = String(latex[..<afterLimits])
        return prefix + #"\frac{"# + numerator + "}{" + denominator + "}" + differential
    }

    static func isEnglishWord(_ word: String) -> Bool {
        if word.contains("\\") || word.contains("{") || word.contains("}")
            || word.contains("^") || word.contains("_") {
            return false
        }
        let letters = word.filter(\.isLetter)
        guard letters.count >= 3 else { return false }
        return !mathWords.contains(word.lowercased()) && !mathWords.contains(letters.lowercased())
    }

    static func splitIntegral(_ numerator: String) -> (String, String) {
        var index = numerator.index(numerator.startIndex, offsetBy: 4) // after \int
        func skipScript() {
            guard index < numerator.endIndex, numerator[index] == "_" || numerator[index] == "^" else { return }
            index = numerator.index(after: index)
            guard index < numerator.endIndex else { return }
            if numerator[index] == "{" {
                if let close = matchingBrace(in: numerator, open: index) {
                    index = numerator.index(after: close)
                }
            } else {
                index = numerator.index(after: index)
            }
        }
        skipScript()
        skipScript()
        let integral = String(numerator[..<index]).trimmingCharacters(in: .whitespaces)
        let integrand = String(numerator[index...]).trimmingCharacters(in: .whitespaces)
        return (integral, integrand)
    }

    static func range(of needle: String, in source: String) -> Range<String.Index>? {
        source.range(of: needle)
    }

    static func matchingBrace(in source: String, open: String.Index) -> String.Index? {
        guard source[open] == "{" else { return nil }
        var depth = 0
        var index = open
        while index < source.endIndex {
            let character = source[index]
            if character == "\\" {
                index = source.index(after: index)
                if index < source.endIndex {
                    index = source.index(after: index)
                }
                continue
            }
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 { return index }
            }
            index = source.index(after: index)
        }
        return nil
    }
}

func flatten(_ nodes: [MathNode]) -> MathNode? {
    if nodes.isEmpty { return nil }
    if nodes.count == 1 { return nodes[0] }
    return .sequence(nodes)
}

private struct MathDocumentParser {
    private let characters: [Character]
    private var index = 0

    init(_ source: String) {
        characters = Array(source)
    }

    mutating func parseDocument(promoteLone: Bool = true) -> [MathBlock] {
        var blocks: [MathBlock] = []
        var runs: [InlineRun] = []

        func flushParagraph() {
            guard !runs.isEmpty else { return }
            blocks.append(.paragraph(coalesce(liftCasual(in: runs))))
            runs = []
        }

        while !isAtEnd {
            if starts(with: "\n\n") {
                skip("\n\n")
                flushParagraph()
                continue
            }
            if let display = parseDisplay() {
                flushParagraph()
                for line in display {
                    if LatexCleanup.hasEnglishSentence(line) {
                        var inner = MathDocumentParser(line)
                        blocks.append(contentsOf: inner.parseDocument(promoteLone: false))
                    } else {
                        blocks.append(.display(line))
                    }
                }
                continue
            }
            if let text = parseTextCommand() {
                runs.append(.text(text))
                continue
            }
            if let boxed = parseBoxed() {
                runs.append(.boxed(boxed))
                continue
            }
            if let inline = parseInline() {
                if LatexCleanup.hasEnglishSentence(inline) {
                    var inner = MathDocumentParser(inline)
                    for block in inner.parseDocument(promoteLone: false) {
                        switch block {
                        case .paragraph(let innerRuns):
                            runs.append(contentsOf: innerRuns)
                        case .display(let latex):
                            flushParagraph()
                            blocks.append(.display(latex))
                        }
                    }
                } else {
                    runs.append(.math(inline))
                }
                continue
            }
            if peek() == "\\", isBareLatexAhead(), let fragment = parseLatexFragment() {
                runs.append(.math(fragment))
                continue
            }
            let prose = consumeProseUntilMath()
            if !prose.isEmpty {
                runs.append(.text(prose))
            } else if let character = advance() {
                runs.append(.text(String(character)))
            }
        }
        flushParagraph()
        return promoteLone ? promoteLoneMath(blocks) : blocks
    }

    mutating func parseDisplay() -> [String]? {
        let start = index
        if skip(#"\["#) {
            let body = read(until: #"\]"#)
            if skip(#"\]"#) {
                skipAdjacentNewlines()
                return normalizeDisplay(body)
            }
            index = start
            return nil
        }
        if starts(with: "$$") {
            skip("$$")
            let body = read(until: "$$")
            if skip("$$") {
                skipAdjacentNewlines()
                return normalizeDisplay(body)
            }
            index = start
            return nil
        }
        if let environment = parseEnvironment() {
            skipAdjacentNewlines()
            return environment
        }
        return nil
    }

    mutating func parseEnvironment() -> [String]? {
        guard starts(with: #"\begin{"#) else { return nil }
        let start = index
        skip(#"\begin{"#)
        let name = read(while: { $0 != "}" })
        guard skip("}") else {
            index = start
            return nil
        }
        let terminator = "\\end{\(name)}"
        let body = read(until: terminator)
        skip(terminator)
        return normalizeDisplay("\\begin{\(name)}\(body)\\end{\(name)}")
    }

    mutating func parseInline() -> String? {
        let start = index
        if skip(#"\("#) {
            let body = read(until: #"\)"#)
            if skip(#"\)"#) {
                return body.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            index = start
            return nil
        }
        if peek() == "$", !starts(with: "$$") {
            skip("$")
            let body = read(until: "$")
            if skip("$") {
                return body.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            index = start
            return nil
        }
        return nil
    }

    mutating func parseTextCommand() -> String? {
        guard starts(with: #"\text"#) else { return nil }
        skip(#"\text"#)
        return readBalancedGroup()
    }

    mutating func parseBoxed() -> String? {
        guard starts(with: #"\boxed"#) else { return nil }
        skip(#"\boxed"#)
        return readBalancedGroup()
    }

    func isBareLatexAhead() -> Bool {
        guard peek() == "\\" else { return false }
        if starts(with: #"\["#) || starts(with: #"\("#) || starts(with: #"\begin"#)
            || starts(with: #"\boxed"#) || starts(with: #"\text"#) || starts(with: #"\end"#) {
            return false
        }
        var offset = index + 1
        var letters: [Character] = []
        while offset < characters.count, characters[offset].isLetter {
            letters.append(characters[offset])
            offset += 1
        }
        let command = String(letters)
        if command.isEmpty { return false }
        if LatexCleanup.mathCommands.contains(command) { return true }
        return offset < characters.count && characters[offset] == "{"
    }

    func shouldSplitProseForBareLatex() -> Bool {
        if isDisplayGradeCommandAhead() { return true }
        return !previousNonSpaceIsMathOperand()
    }

    func isDisplayGradeCommandAhead() -> Bool {
        var offset = index + 1
        var letters: [Character] = []
        while offset < characters.count, characters[offset].isLetter {
            letters.append(characters[offset])
            offset += 1
        }
        switch String(letters) {
        case "int", "iint", "iiint", "oint", "sum", "prod", "lim", "frac", "dfrac", "tfrac":
            return true
        default:
            return false
        }
    }

    func previousNonSpaceIsMathOperand() -> Bool {
        var location = index
        while location > 0 {
            location -= 1
            let character = characters[location]
            if character.isWhitespace { continue }
            return character.isNumber || character.isLetter || ")]}".contains(character)
        }
        return false
    }

    mutating func consumeProseUntilMath() -> String {
        let start = index
        while let character = peek() {
            if character == "\n", starts(with: "\n\n") { break }
            if starts(with: #"\["#) || starts(with: "$$") || starts(with: #"\begin"#)
                || starts(with: #"\("#) || starts(with: #"\boxed"#) || starts(with: #"\text"#) {
                break
            }
            if character == "$" { break }
            if character == "\\", isBareLatexAhead(), shouldSplitProseForBareLatex() { break }
            advance()
        }
        return String(characters[start..<index])
    }

    func liftCasual(in runs: [InlineRun]) -> [InlineRun] {
        var lifted: [InlineRun] = []
        for run in runs {
            guard case .text(let text) = run else {
                lifted.append(run)
                continue
            }
            lifted.append(contentsOf: liftCasual(in: text))
        }
        return lifted
    }

    func liftCasual(in text: String) -> [InlineRun] {
        var runs: [InlineRun] = []
        var prose = ""
        var rest = text
        while !rest.isEmpty {
            if rest.first?.isWhitespace == true {
                let whitespace = rest.prefix(while: \.isWhitespace)
                prose += whitespace
                rest.removeFirst(whitespace.count)
                continue
            }
            if let prefix = CasualMath.parsePrefix(rest) {
                if !prose.isEmpty {
                    runs.append(.text(prose))
                    prose = ""
                }
                let latex = prefix.node.latex.trimmingCharacters(in: .whitespaces)
                if !latex.isEmpty {
                    runs.append(.math(latex))
                }
                rest.removeFirst(prefix.consumed)
                continue
            }
            if rest.first?.isLetter == true {
                let word = rest.prefix(while: { $0.isLetter || $0 == "'" })
                prose += word
                rest.removeFirst(word.count)
            } else {
                prose.append(rest.removeFirst())
            }
        }
        if !prose.isEmpty {
            runs.append(.text(prose))
        }
        return runs
    }

    mutating func parseLatexFragment() -> String? {
        guard peek() == "\\" else { return nil }
        if starts(with: #"\["#) || starts(with: #"\("#) || starts(with: #"\begin"#) || starts(with: #"\boxed"#) {
            return nil
        }
        let start = index
        consumeLatexMath()
        let raw = String(characters[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? nil : raw
    }

    mutating func parseCasual() -> String? {
        let remaining = String(characters[index...])
        guard let prefix = CasualMath.parsePrefix(remaining) else { return nil }
        index += prefix.consumed
        let latex = prefix.node.latex.trimmingCharacters(in: .whitespaces)
        return latex.isEmpty ? nil : latex
    }

    mutating func consumeLatexMath() {
        var depth = 0
        while let character = peek() {
            if character == "\\" {
                advance()
                if let next = peek() {
                    if next.isLetter {
                        _ = read(while: { $0.isLetter })
                    } else {
                        advance()
                    }
                }
                continue
            }
            if character == "{" {
                depth += 1
                advance()
                continue
            }
            if character == "}" {
                if depth == 0 { break }
                depth -= 1
                advance()
                continue
            }
            if depth > 0 {
                advance()
                continue
            }
            if character == "." {
                if peek(ahead: 1)?.isNumber == true {
                    advance()
                    continue
                }
                break
            }
            if "^_".contains(character) || character.isNumber || character == "'"
                || "()+-*/=<>!,|[]'".contains(character) {
                advance()
                continue
            }
            if character.isWhitespace {
                let saved = index
                while peek()?.isWhitespace == true { advance() }
                if let next = peek(),
                   next == "\\" || next == "{" || next == "^" || next == "_"
                    || next.isNumber || "+-*/=<>".contains(next) || isMathIdentAhead() {
                    continue
                }
                index = saved
                break
            }
            if character.isLetter {
                if isMathIdentAhead() {
                    _ = read(while: { $0.isLetter || $0 == "'" })
                    continue
                }
                break
            }
            break
        }
    }

    func isMathIdentAhead() -> Bool {
        var offset = index
        var letters: [Character] = []
        while offset < characters.count, characters[offset].isLetter {
            letters.append(characters[offset])
            offset += 1
        }
        let ident = String(letters)
        if ident.isEmpty { return false }
        if MathNode.functionNames.contains(ident) { return true }
        if ident.count >= 3 { return false }
        if ident.count == 2 {
            return ident.first?.lowercased() == "d"
        }
        if offset < characters.count {
            let next = characters[offset]
            if "^_{'(".contains(next) || next.isNumber { return true }
            if next.isWhitespace {
                var cursor = offset
                while cursor < characters.count, characters[cursor].isWhitespace {
                    cursor += 1
                }
                var word: [Character] = []
                while cursor < characters.count, characters[cursor].isLetter {
                    word.append(characters[cursor])
                    cursor += 1
                }
                if LatexCleanup.isEnglishWord(String(word)) {
                    return false
                }
            }
        }
        return true
    }

    func normalizeDisplay(_ raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let body = unwrapEnvironment(trimmed, names: ["align", "aligned", "align*", "eqnarray"]) {
            return body
                .components(separatedBy: "\\\\")
                .map { $0.replacingOccurrences(of: "&", with: " ") }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return [trimmed].filter { !$0.isEmpty }
    }

    func unwrapEnvironment(_ source: String, names: [String]) -> String? {
        for name in names {
            let open = "\\begin{\(name)}"
            let close = "\\end{\(name)}"
            guard source.hasPrefix(open), source.hasSuffix(close) else { continue }
            let start = source.index(source.startIndex, offsetBy: open.count)
            let end = source.index(source.endIndex, offsetBy: -close.count)
            return String(source[start..<end])
        }
        if source.contains("\\begin{aligned}") {
            return unwrapEnvironment(
                source
                    .replacingOccurrences(of: "\\begin{aligned}", with: "\\begin{aligned}")
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                names: ["aligned"]
            )
        }
        let wrapped = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if wrapped.contains("\\begin{aligned}") {
            guard let open = wrapped.range(of: "\\begin{aligned}"),
                  let close = wrapped.range(of: "\\end{aligned}")
            else { return nil }
            return String(wrapped[open.upperBound..<close.lowerBound])
        }
        return nil
    }

    mutating func readBalancedGroup() -> String? {
        skipSpaces()
        guard skip("{") else { return nil }
        let start = index
        var depth = 1
        while let character = peek(), depth > 0 {
            if character == "{" { depth += 1 }
            if character == "}" { depth -= 1 }
            advance()
        }
        let end = max(start, index - 1)
        return String(characters[start..<end])
    }

    mutating func consumeProseToken() -> String {
        guard let character = peek() else { return "" }
        if character == "\\" || character == "$" { return "" }
        if character == "\n" {
            if starts(with: "\n\n") { return "" }
            advance()
            return "\n"
        }
        if character.isWhitespace {
            return read(while: { $0.isWhitespace && $0 != "\n" })
        }
        if character.isLetter {
            return read(while: { $0.isLetter || $0 == "'" })
        }
        if character.isNumber {
            return read(while: { $0.isNumber || $0 == "." })
        }
        advance()
        return String(character)
    }

    func promoteLoneMath(_ blocks: [MathBlock]) -> [MathBlock] {
        guard blocks.count == 1, case .paragraph(let runs) = blocks[0] else { return blocks }
        let meaningful = runs.filter { run in
            if case .text(let text) = run {
                return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return true
        }
        guard meaningful.count == 1, meaningful[0].latex != nil else {
            return [.paragraph(coalesce(runs))]
        }
        if case .boxed(let boxed) = meaningful[0] {
            return [.display(#"\boxed{"# + boxed + "}")]
        }
        return [.paragraph(coalesce(runs))]
    }

    func coalesce(_ runs: [InlineRun]) -> [InlineRun] {
        var result: [InlineRun] = []
        for run in runs {
            if case .text(let text) = run, case .text(let last) = result.last {
                result[result.count - 1] = .text(last + text)
            } else {
                result.append(run)
            }
        }
        return result
    }

    mutating func skipTrailingSentencePeriod() {
        guard peek() == "." else { return }
        let next = peek(ahead: 1)
        if next == nil || next?.isWhitespace == true || next?.isUppercase == true {
            advance()
        }
    }

    mutating func skipAdjacentNewlines() {
        while peek() == "\n" { advance() }
    }

    mutating func skipSpaces() {
        while peek()?.isWhitespace == true { advance() }
    }

    var isAtEnd: Bool { index >= characters.count }

    func peek() -> Character? {
        guard index < characters.count else { return nil }
        return characters[index]
    }

    func peek(ahead offset: Int) -> Character? {
        let location = index + offset
        guard location < characters.count else { return nil }
        return characters[location]
    }

    func starts(with prefix: String) -> Bool {
        let needle = Array(prefix)
        guard index + needle.count <= characters.count else { return false }
        return Array(characters[index..<(index + needle.count)]) == needle
    }

    @discardableResult
    mutating func skip(_ prefix: String) -> Bool {
        guard starts(with: prefix) else { return false }
        index += prefix.count
        return true
    }

    @discardableResult
    mutating func advance() -> Character? {
        guard let character = peek() else { return nil }
        index += 1
        return character
    }

    mutating func read(while predicate: (Character) -> Bool) -> String {
        var collected: [Character] = []
        while let character = peek(), predicate(character) {
            collected.append(character)
            index += 1
        }
        return String(collected)
    }

    mutating func read(until terminator: String) -> String {
        var collected: [Character] = []
        while !isAtEnd, !starts(with: terminator) {
            collected.append(advance()!)
        }
        return String(collected)
    }
}
