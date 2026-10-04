import Foundation

enum MathFeature: Sendable {
    case fraction
    case boxed
    case superscript
}

enum MathBlock: Equatable, Sendable {
    case paragraph([InlineRun])
    case display(MathNode)
}

enum InlineRun: Equatable, Sendable {
    case text(String)
    case math(MathNode)
    case boxed(MathNode)
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
            return runs.allSatisfy { run in
                if case .text = run { return true }
                return false
            }
        }
    }

    func contains(_ feature: MathFeature) -> Bool {
        blocks.contains { $0.contains(feature) }
    }

    static func parse(_ source: String) -> MathMarkup {
        var parser = MathParser(source)
        return MathMarkup(blocks: parser.parseDocument())
    }
}

private extension MathBlock {
    var accessibleText: String {
        switch self {
        case .paragraph(let runs):
            return runs.map(\.accessibleText).joined()
        case .display(let node):
            return node.accessibleText
        }
    }

    func contains(_ feature: MathFeature) -> Bool {
        switch self {
        case .paragraph(let runs):
            return runs.contains { $0.contains(feature) }
        case .display(let node):
            return node.contains(feature)
        }
    }
}

private extension InlineRun {
    var accessibleText: String {
        switch self {
        case .text(let text):
            return text
        case .math(let node), .boxed(let node):
            return node.accessibleText
        }
    }

    func contains(_ feature: MathFeature) -> Bool {
        switch self {
        case .text:
            return false
        case .boxed(let node):
            return feature == .boxed || node.contains(feature)
        case .math(let node):
            return node.contains(feature)
        }
    }
}

extension MathNode {
    var accessibleText: String {
        switch self {
        case .sequence(let nodes):
            return MathNode.joinAccessible(nodes)
        case .lines(let rows):
            return rows.map(\.accessibleText).filter { !$0.isEmpty }.joined(separator: "\n")
        case .symbol(let text):
            return text
        case .fraction(let numerator, let denominator):
            return "\(numerator.accessibleText)/\(denominator.accessibleText)"
        case .superscript(let base, let exponent):
            return "\(base.accessibleText)^\(exponent.accessibleText)"
        case .sub(let base, let script):
            return "\(base.accessibleText)_\(script.accessibleText)"
        case .sqrt(let inner):
            return "√(\(inner.accessibleText))"
        case .boxed(let inner):
            return inner.accessibleText
        }
    }

    var isMostlyProse: Bool {
        switch self {
        case .sequence(let nodes):
            let words = nodes.filter(\.isWordLike).count
            return words >= 3
        case .lines:
            return false
        case .symbol(let text):
            return text.contains(where: \.isLetter) && text.count > 2
        default:
            return false
        }
    }

    var isWordLike: Bool {
        guard case .symbol(let text) = self else { return false }
        let letters = text.filter(\.isLetter)
        return letters.count >= 2
    }

    static let functionNames: Set<String> = [
        "sin", "cos", "tan", "sec", "csc", "cot", "ln", "log", "exp", "lim",
    ]
    static let binaryOperators: Set<String> = ["+", "·", "×", "÷", "±"]
    static let relations: Set<String> = ["=", "≠", "≤", "≥", "≈", "→", "<", ">"]

    var isWhitespace: Bool {
        if case .symbol(let text) = self { return !text.isEmpty && text.allSatisfy(\.isWhitespace) }
        return false
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

    var isOrdinaryAtom: Bool {
        switch self {
        case .symbol(let text):
            return text.contains(where: { $0.isLetter || $0.isNumber || $0 == "'" })
        case .superscript(let base, _), .sub(let base, _):
            return base.isOrdinaryAtom
        case .fraction, .sqrt:
            return true
        default:
            return false
        }
    }

    var isClosingOrPunctuation: Bool {
        if case .symbol(let text) = self {
            return [")", "]", "}", ",", ".", "!", "?", ";", ":"].contains(text)
        }
        return false
    }

    var needsGapBeforeNext: Bool {
        switch self {
        case .fraction, .sqrt, .boxed:
            return true
        default:
            return isFunctionName
        }
    }

    func applyingReadingSpacing() -> MathNode {
        switch self {
        case .sequence(let nodes):
            return flatten(Self.spaceAtoms(nodes.map { $0.applyingReadingSpacing() })) ?? .symbol("")
        case .lines(let rows):
            return .lines(rows.map { $0.applyingReadingSpacing() })
        case .fraction(let numerator, let denominator):
            return .fraction(numerator.applyingReadingSpacing(), denominator.applyingReadingSpacing())
        case .superscript(let base, let exponent):
            return .superscript(base.applyingReadingSpacing(), exponent.applyingReadingSpacing())
        case .sub(let base, let script):
            return .sub(base.applyingReadingSpacing(), script.applyingReadingSpacing())
        case .sqrt(let inner):
            return .sqrt(inner.applyingReadingSpacing())
        case .boxed(let inner):
            return .boxed(inner.applyingReadingSpacing())
        case .symbol:
            return self
        }
    }

    func brokenAtRelationsIfNeeded() -> MathNode {
        switch self {
        case .boxed(let inner):
            return .boxed(inner.brokenAtRelationsIfNeeded())
        case .sequence(let nodes):
            let rows = Self.readableRows(from: nodes)
            guard rows.count > 1 else { return self }
            return .lines(rows.compactMap(flatten))
        default:
            return self
        }
    }

    private static func readableRows(from nodes: [MathNode]) -> [[MathNode]] {
        let atoms = nodes.filter { !$0.isWhitespace }
        var rows: [[MathNode]] = []
        var current: [MathNode] = []
        let splitRelations = atoms.count >= 10
        for node in nodes {
            if splitRelations, node.isRelation, !current.isEmpty {
                rows.append(current)
                current = [node]
                continue
            }
            current.append(node)
        }
        if !current.isEmpty {
            rows.append(current)
        }
        return rows.flatMap(splitLongSum)
    }

    private static func splitLongSum(_ row: [MathNode]) -> [[MathNode]] {
        let atoms = row.filter { !$0.isWhitespace }
        guard atoms.count >= 12 else { return [row] }
        var rows: [[MathNode]] = []
        var current: [MathNode] = []
        for node in row {
            let currentAtoms = current.filter { !$0.isWhitespace }.count
            let binaryBreak = node.isBinaryOperator || (node.isMinus && !isUnaryMinusContext(current))
            if binaryBreak, currentAtoms >= 3 {
                rows.append(current)
                current = [node]
                continue
            }
            current.append(node)
        }
        if !current.isEmpty {
            rows.append(current)
        }
        return rows.count > 1 ? rows : [row]
    }

    private static func spaceAtoms(_ nodes: [MathNode]) -> [MathNode] {
        var result: [MathNode] = []
        var pendingSpace = false
        for node in nodes {
            if node.isWhitespace {
                pendingSpace = true
                continue
            }
            if node.isRelation {
                appendPadded(&result, node)
                pendingSpace = false
                continue
            }
            if node.isMinus {
                if isUnaryMinusContext(result) {
                    result.append(node)
                } else {
                    appendPadded(&result, node)
                }
                pendingSpace = false
                continue
            }
            if node.isBinaryOperator {
                appendPadded(&result, node)
                pendingSpace = false
                continue
            }
            if let last = lastNonSpace(result) {
                let functionArg = last.isFunctionName && !node.isClosingOrPunctuation
                let functionName = node.isFunctionName && last.isOrdinaryAtom
                let construct = last.needsGapBeforeNext && !node.isClosingOrPunctuation
                let wordGap = last.isWordLike && (node.isWordLike || node.isOrdinaryAtom)
                if pendingSpace || functionArg || functionName || construct || wordGap {
                    result.append(.symbol(" "))
                }
            }
            result.append(node)
            pendingSpace = false
        }
        return result
    }

    private static func appendPadded(_ result: inout [MathNode], _ node: MathNode) {
        if !result.isEmpty { result.append(.symbol(" ")) }
        result.append(node)
        result.append(.symbol(" "))
    }

    private static func lastNonSpace(_ nodes: [MathNode]) -> MathNode? {
        nodes.last { !$0.isWhitespace }
    }

    private static func isUnaryMinusContext(_ nodes: [MathNode]) -> Bool {
        guard let previous = lastNonSpace(nodes) else { return true }
        if previous.isRelation || previous.isBinaryOperator || previous.isMinus {
            return true
        }
        if case .symbol(let text) = previous {
            return ["(", "[", ",", " "].contains(text)
        }
        return false
    }

    func contains(_ feature: MathFeature) -> Bool {
        switch self {
        case .fraction(let numerator, let denominator):
            return feature == .fraction || numerator.contains(feature) || denominator.contains(feature)
        case .boxed(let inner):
            return feature == .boxed || inner.contains(feature)
        case .superscript(let base, let exponent):
            return feature == .superscript || base.contains(feature) || exponent.contains(feature)
        case .sub(let base, let script):
            return base.contains(feature) || script.contains(feature)
        case .sqrt(let inner):
            return inner.contains(feature)
        case .sequence(let nodes), .lines(let nodes):
            return nodes.contains { $0.contains(feature) }
        case .symbol:
            return false
        }
    }

    static func joinAccessible(_ nodes: [MathNode]) -> String {
        var result = ""
        for node in nodes {
            let piece = node.accessibleText
            if piece.isEmpty { continue }
            if piece == " " {
                if !result.hasSuffix(" ") { result += " " }
                continue
            }
            if !result.isEmpty, !result.hasSuffix(" "), needsAccessibleSpace(before: piece, previous: result) {
                result += " "
            }
            result += piece
        }
        return result
    }

    private static func needsAccessibleSpace(before piece: String, previous: String) -> Bool {
        guard let first = piece.first, let last = previous.last else { return false }
        if ",.!?;:)'".contains(first) { return false }
        if first == " " || last == " " { return false }
        return first.isLetter && (last.isLetter || last.isNumber || last == "#")
    }
}

private struct MathParser {
    private let characters: [Character]
    private var index = 0

    init(_ source: String) {
        characters = Array(source)
    }

    mutating func parseDocument() -> [MathBlock] {
        var blocks: [MathBlock] = []
        var runs: [InlineRun] = []

        func flushParagraph() {
            guard !runs.isEmpty else { return }
            blocks.append(.paragraph(runs))
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
                blocks.append(.display(display))
                continue
            }
            if starts(with: #"\boxed"#) {
                skip(#"\boxed"#)
                runs.append(.boxed(parseGroup()))
                continue
            }
            if let math = parseDelimitedInline() ?? parseUndelimitedMath() {
                runs.append(.math(math))
                continue
            }
            let prose = consumeProse()
            if !prose.isEmpty {
                runs.append(.text(prose))
            } else {
                if let character = advance() {
                    runs.append(.text(String(character)))
                }
            }
        }
        flushParagraph()
        return blocks
    }

    mutating func parseDisplay() -> MathNode? {
        if skip(#"\["#) {
            let node = parseMath(until: #"\]"#)
            skip(#"\]"#)
            skipAdjacentNewlines()
            return node.brokenAtRelationsIfNeeded()
        }
        if starts(with: "$$") {
            skip("$$")
            let node = parseMath(until: "$$")
            skip("$$")
            skipAdjacentNewlines()
            return node.brokenAtRelationsIfNeeded()
        }
        if let environment = parseBeginEnvironment() {
            skipAdjacentNewlines()
            return environment
        }
        return nil
    }

    mutating func parseBeginEnvironment() -> MathNode? {
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
        let rows = body.components(separatedBy: "\\\\").map { row in
            row.replacingOccurrences(of: "&", with: " ")
        }
        let nodes = rows.compactMap { row -> MathNode? in
            let trimmed = row.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            var inner = MathParser(trimmed)
            return inner.parseMath(until: nil)
        }
        if nodes.count > 1 {
            return .lines(nodes)
        }
        return nodes.first ?? .symbol("")
    }

    mutating func parseDelimitedInline() -> MathNode? {
        if skip(#"\("#) {
            let node = parseMath(until: #"\)"#)
            skip(#"\)"#)
            return node
        }
        if peek() == "$", !starts(with: "$$") {
            skip("$")
            let node = parseMath(until: "$")
            skip("$")
            return node
        }
        return nil
    }

    mutating func parseUndelimitedMath() -> MathNode? {
        guard peek() == "\\" else { return nil }
        var nodes: [MathNode] = []
        while !isAtEnd {
            skipMathWhitespace()
            guard let next = peek() else { break }
            if next == "\\" || next == "^" || next == "_" || next == "{" {
                guard let atom = parseAtom() else { break }
                nodes.append(attachScripts(to: atom))
                continue
            }
            if !nodes.isEmpty, isMathOrdinary(next) || "()[]".contains(next) {
                guard let atom = parseAtom() else { break }
                nodes.append(attachScripts(to: atom))
                continue
            }
            break
        }
        return flatten(nodes)?.applyingReadingSpacing()
    }

    mutating func parseMath(until terminator: String?) -> MathNode {
        var nodes: [MathNode] = []
        while !isAtEnd {
            let hadSpace = skipMathWhitespace()
            if let terminator, starts(with: terminator) { break }
            if terminator == nil, peek() == "}" { break }
            if starts(with: #"\\"#), !starts(with: #"\]"#), !starts(with: #"\\("#) {
                skip(#"\\"#)
                nodes.append(.symbol(" "))
                continue
            }
            guard let atom = parseAtom() else { break }
            if hadSpace, !nodes.isEmpty {
                nodes.append(.symbol(" "))
            }
            nodes.append(attachScripts(to: atom))
        }
        return (flatten(nodes) ?? .symbol("")).applyingReadingSpacing()
    }

    mutating func parseAtom() -> MathNode? {
        skipMathWhitespace()
        if starts(with: #"\begin{"#) {
            return parseBeginEnvironment()
        }
        if skip(#"\frac"#) || skip(#"\dfrac"#) || skip(#"\tfrac"#) {
            return .fraction(parseGroup(), parseGroup())
        }
        if skip(#"\sqrt"#) {
            return .sqrt(parseGroup())
        }
        if skip(#"\boxed"#) {
            return .boxed(parseGroup())
        }
        if skip(#"\left"#) || skip(#"\right"#) || skip(#"\displaystyle"#) || skip(#"\textstyle"#) {
            return parseAtom()
        }
        if skip(#"\mathrm"#) || skip(#"\text"#) || skip(#"\mathbf"#) || skip(#"\mathit"#) {
            return parseGroup()
        }
        if let symbol = parseCommandSymbol() {
            return symbol
        }
        if peek() == "{" {
            return parseGroup()
        }
        if let next = peek(), isMathOrdinary(next) {
            return .symbol(read(while: isMathOrdinary))
        }
        if let next = peek(), "()[]|=+-*/,<>!#?:;,".contains(next) {
            advance()
            return .symbol(String(next))
        }
        if skip("\\"), let next = peek() {
            if next.isLetter {
                return .symbol(read(while: { $0.isLetter }))
            }
            advance()
            return .symbol(String(next))
        }
        return nil
    }

    mutating func parseCommandSymbol() -> MathNode? {
        let mappings: [(String, String)] = [
            (#"\cdot"#, "·"),
            (#"\times"#, "×"),
            (#"\div"#, "÷"),
            (#"\pm"#, "±"),
            (#"\leq"#, "≤"),
            (#"\geq"#, "≥"),
            (#"\neq"#, "≠"),
            (#"\approx"#, "≈"),
            (#"\infty"#, "∞"),
            (#"\partial"#, "∂"),
            (#"\rightarrow"#, "→"),
            (#"\to"#, "→"),
            (#"\pi"#, "π"),
            (#"\theta"#, "θ"),
            (#"\alpha"#, "α"),
            (#"\beta"#, "β"),
            (#"\quad"#, " "),
            (#"\qquad"#, "  "),
            (#"\,"#, " "),
            (#"\;"#, " "),
            (#"\:"#, " "),
            (#"\ "#, " "),
            (#"\sin"#, "sin"),
            (#"\cos"#, "cos"),
            (#"\tan"#, "tan"),
            (#"\sec"#, "sec"),
            (#"\csc"#, "csc"),
            (#"\cot"#, "cot"),
            (#"\ln"#, "ln"),
            (#"\log"#, "log"),
            (#"\exp"#, "exp"),
            (#"\lim"#, "lim"),
        ]
        for (command, symbol) in mappings where skip(command) {
            return .symbol(symbol)
        }
        return nil
    }

    mutating func attachScripts(to base: MathNode) -> MathNode {
        var node = base
        while !isAtEnd {
            if skip("^") {
                node = .superscript(node, parseScript())
            } else if skip("_") {
                node = .sub(node, parseScript())
            } else {
                break
            }
        }
        return node
    }

    mutating func parseScript() -> MathNode {
        if peek() == "{" {
            return parseGroup()
        }
        if peek() == "\\" {
            return parseAtom() ?? .symbol("")
        }
        if let character = advance() {
            return .symbol(String(character))
        }
        return .symbol("")
    }

    mutating func parseGroup() -> MathNode {
        guard skip("{") else { return parseAtom() ?? .symbol("") }
        let inner = parseMath(until: "}")
        skip("}")
        return inner
    }

    mutating func consumeProse() -> String {
        var collected: [Character] = []
        while let character = peek() {
            if character == "\\" || character == "$" { break }
            if character == "\n", starts(with: "\n\n") { break }
            collected.append(character)
            index += 1
        }
        return String(collected)
    }

    mutating func skipAdjacentNewlines() {
        while peek() == "\n" { advance() }
    }

    @discardableResult
    mutating func skipMathWhitespace() -> Bool {
        let start = index
        while let character = peek(), character.isWhitespace { advance() }
        return index > start
    }

    var isAtEnd: Bool { index >= characters.count }

    func peek() -> Character? {
        guard index < characters.count else { return nil }
        return characters[index]
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

private func isMathOrdinary(_ character: Character) -> Bool {
    character.isLetter || character.isNumber || character == "'" || character == "."
}

private func flatten(_ nodes: [MathNode]) -> MathNode? {
    if nodes.isEmpty { return nil }
    if nodes.count == 1 { return nodes[0] }
    return .sequence(nodes)
}
