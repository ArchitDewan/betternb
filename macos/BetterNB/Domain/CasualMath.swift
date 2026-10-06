import Foundation

enum CasualMath {
    struct Prefix: Equatable, Sendable {
        var node: MathNode
        var consumed: Int
    }

    static func parsePrefix(_ source: String) -> Prefix? {
        var parser = CasualMathParser(source)
        return parser.parsePrefix()
    }
}

private struct CasualMathParser {
    private let characters: [Character]
    private var index = 0

    private static let functionNames: Set<String> = [
        "sin", "cos", "tan", "sec", "csc", "cot", "ln", "log", "exp", "lim",
        "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh", "sqrt",
    ]

    private static let largeOperators: [String: String] = [
        "int": "∫",
        "sum": "∑",
        "prod": "∏",
    ]

    private static let namedSymbols: [String: String] = [
        "pi": "π",
        "theta": "θ",
        "alpha": "α",
        "beta": "β",
        "gamma": "γ",
        "delta": "δ",
        "lambda": "λ",
        "mu": "μ",
        "sigma": "σ",
        "omega": "ω",
        "inf": "∞",
        "infty": "∞",
        "infinity": "∞",
    ]

    init(_ source: String) {
        characters = Array(source)
    }

    mutating func parsePrefix() -> CasualMath.Prefix? {
        if peek()?.isWhitespace == true { return nil }
        if starts(with: "\\[") || starts(with: "\\(") || starts(with: "$$") || starts(with: "\\begin") {
            return nil
        }
        let start = index
        guard let node = parseEquation() else {
            index = start
            return nil
        }
        guard isRich(node), index > start else {
            index = start
            return nil
        }
        return CasualMath.Prefix(node: node, consumed: index)
    }

    mutating func parseEquation() -> MathNode? {
        guard var node = parseSum() else { return nil }
        while true {
            let saved = index
            skipSpaces()
            guard let relation = parseRelation() else {
                index = saved
                break
            }
            skipSpaces()
            if let rhs = parseSum() {
                node = join(node, .symbol(relation), rhs, padded: true)
            } else {
                node = join(node, .symbol(relation), padded: true)
                break
            }
        }
        return node
    }

    mutating func parseSum() -> MathNode? {
        guard var node = parseProduct() else { return nil }
        while true {
            let saved = index
            skipSpaces()
            guard let op = parsePlusMinus() else {
                index = saved
                break
            }
            skipSpaces()
            if let rhs = parseProduct() {
                node = join(node, .symbol(op), rhs, padded: true)
            } else {
                node = join(node, .symbol(op), padded: true)
                break
            }
        }
        return node
    }

    mutating func parseProduct() -> MathNode? {
        guard var node = parseQuotient() else { return nil }
        while true {
            let saved = index
            skipSpaces()
            if skip("*") || skip("·") || skip("×") {
                skipSpaces()
                if let rhs = parseQuotient() {
                    node = join(node, .symbol("·"), rhs, padded: true)
                    continue
                }
                node = join(node, .symbol("·"), padded: true)
                break
            }
            if canImplicitMultiply() {
                if let rhs = parseQuotient() {
                    node = flatten([node, rhs]) ?? node
                    continue
                }
            }
            index = saved
            break
        }
        return node
    }

    mutating func parseQuotient() -> MathNode? {
        guard var node = parsePower() else { return nil }
        while true {
            let saved = index
            skipSpaces()
            guard skip("/") || skip("÷") else {
                index = saved
                break
            }
            skipSpaces()
            if let denominator = parsePower() {
                node = .fraction(unwrapGrouping(node), unwrapGrouping(denominator))
            } else {
                node = join(node, .symbol("/"))
                break
            }
        }
        return node
    }

    mutating func parsePower() -> MathNode? {
        guard var node = parseUnary() else { return nil }
        while true {
            let saved = index
            skipSpaces()
            if skip("^") {
                skipSpaces()
                node = .superscript(node, parseScript() ?? .symbol(""))
                continue
            }
            if skip("_") {
                skipSpaces()
                node = .sub(node, parseScript() ?? .symbol(""))
                continue
            }
            index = saved
            break
        }
        return node
    }

    mutating func parseUnary() -> MathNode? {
        skipSpaces()
        if skip("+") {
            skipSpaces()
            if let value = parsePower() {
                return join(.symbol("+"), value, padded: true)
            }
            return .symbol("+")
        }
        if peek() == "-", !starts(with: "->") {
            skip("-")
            skipSpaces()
            if let value = parsePower() {
                return flatten([.symbol("-"), value])
            }
            return .symbol("-")
        }
        return parseAtom()
    }

    mutating func parseScript() -> MathNode? {
        if peek() == "{" {
            return unwrapGrouping(parseGrouped("{", "}"))
        }
        if peek() == "(" {
            return unwrapGrouping(parseGrouped("(", ")"))
        }
        if peek() == "\\" {
            return parseLatexAtom()
        }
        if let number = parseNumber() {
            return number
        }
        if let ident = parseIdentAtom() {
            return ident
        }
        if let character = peek(), !character.isWhitespace, character != "+" , character != "=", character != ")" {
            advance()
            return .symbol(String(character))
        }
        return nil
    }

    mutating func parseAtom() -> MathNode? {
        skipSpaces()
        if peek() == "\\" {
            return parseLatexAtom()
        }
        if peek() == "(" {
            return parseGrouped("(", ")")
        }
        if peek() == "[" {
            return parseGrouped("[", "]")
        }
        if peek() == "|" {
            return parseAbsoluteValue()
        }
        if let number = parseNumber() {
            return number
        }
        if let ident = parseIdentAtom() {
            return ident
        }
        return nil
    }

    mutating func parseIdentAtom() -> MathNode? {
        let saved = index
        guard let raw = readIdent() else { return nil }
        let key = raw.lowercased()

        if key == "sqrt" {
            skipSpaces()
            if let argument = parseAtom() ?? parsePower() {
                return .sqrt(unwrapGrouping(argument))
            }
            return .symbol("√")
        }
        if let symbol = Self.largeOperators[key] {
            let afterIdent = index
            skipSpaces()
            let followsMath = canImplicitMultiply() || peek() == "_" || peek() == "^"
            index = afterIdent
            if followsMath {
                return .symbol(symbol)
            }
            index = saved
            return nil
        }
        if let symbol = Self.namedSymbols[key] {
            return .symbol(symbol)
        }
        if Self.functionNames.contains(key) {
            return parseFunctionCall(key)
        }
        if raw.contains(where: \.isLetter), identIsMath(raw) {
            return .symbol(raw)
        }
        index = saved
        return nil
    }

    mutating func parseFunctionCall(_ name: String) -> MathNode {
        let saved = index
        skipSpaces()
        if peek() == "(" {
            let argument = parseGrouped("(", ")")
            return flatten([.symbol(name), argument]) ?? .symbol(name)
        }
        if let argument = parsePower() {
            return flatten([.symbol(name), .symbol(" "), argument]) ?? .symbol(name)
        }
        index = saved
        return .symbol(name)
    }

    mutating func parseGrouped(_ open: String, _ close: String) -> MathNode {
        skip(open)
        skipSpaces()
        let inner = parseEquation() ?? .symbol("")
        skipSpaces()
        if skip(close) {
            return flatten([.symbol(open), inner, .symbol(close)]) ?? inner
        }
        return flatten([.symbol(open), inner]) ?? inner
    }

    mutating func parseAbsoluteValue() -> MathNode? {
        skip("|")
        let saved = index
        skipSpaces()
        guard let inner = parseEquation() else {
            index = saved
            return .symbol("|")
        }
        skipSpaces()
        if skip("|") {
            return flatten([.symbol("|"), inner, .symbol("|")])
        }
        index = saved
        return .symbol("|")
    }

    mutating func parseLatexAtom() -> MathNode? {
        guard peek() == "\\" else { return nil }
        let start = index
        advance()
        if let next = peek() {
            if next.isLetter {
                _ = read(while: { $0.isLetter })
            } else {
                advance()
            }
        }
        while peek() == "{" {
            skipBalancedGroup()
        }
        return .symbol(String(characters[start..<index]))
    }

    mutating func skipBalancedGroup() {
        guard skip("{") else { return }
        var depth = 1
        while let character = peek(), depth > 0 {
            if character == "{" { depth += 1 }
            if character == "}" { depth -= 1 }
            advance()
        }
    }

    mutating func parseNumber() -> MathNode? {
        guard let first = peek(), first.isNumber else { return nil }
        var text = read(while: { $0.isNumber })
        if peek() == ".", let next = peek(ahead: 1), next.isNumber {
            text += String(advance()!)
            text += read(while: { $0.isNumber })
        }
        return .symbol(text)
    }

    mutating func parseRelation() -> String? {
        if skip("==") || skip("=") { return "=" }
        if skip("!=") || skip("=/=") { return "≠" }
        if skip("<=") || skip("≤") { return "≤" }
        if skip(">=") || skip("≥") { return "≥" }
        if skip("->") || skip("=>") { return "→" }
        if skip("<") { return "<" }
        if skip(">") { return ">" }
        return nil
    }

    mutating func parsePlusMinus() -> String? {
        if skip("+") { return "+" }
        if starts(with: "->") { return nil }
        if skip("-") { return "-" }
        return nil
    }

    func canImplicitMultiply() -> Bool {
        guard let character = peek() else { return false }
        if character == "(" || character == "[" || character == "|" || character == "\\" { return true }
        if character.isNumber { return true }
        if character.isLetter {
            let ident = peekIdent()
            return identIsMath(ident) || Self.functionNames.contains(ident.lowercased())
                || Self.namedSymbols[ident.lowercased()] != nil
                || Self.largeOperators[ident.lowercased()] != nil
        }
        return false
    }

    func identIsMath(_ ident: String) -> Bool {
        let letters = ident.filter(\.isLetter)
        if letters.count == 1 { return true }
        if letters.count == 2, letters.first?.lowercased() == "d" { return true }
        return Self.functionNames.contains(ident.lowercased())
            || Self.namedSymbols[ident.lowercased()] != nil
            || Self.largeOperators[ident.lowercased()] != nil
    }

    func isRich(_ node: MathNode) -> Bool {
        switch node {
        case .fraction, .sqrt, .boxed, .superscript, .sub:
            return true
        case .sequence(let nodes), .lines(let nodes):
            if nodes.contains(where: isRich) { return true }
            if nodes.contains(where: { $0.isBinaryOperator || $0.isRelation || $0.isMinus }) { return true }
            if nodes.contains(where: { $0.isFunctionName || $0.largeOperatorLimits != nil }) { return true }
            if nodes.contains(where: { if case .symbol("(") = $0 { return true }; return false }) { return true }
            return hasTightNumberAndIdent(nodes)
        case .symbol(let text):
            return MathNode.largeOperatorSymbols.contains(text) || ["π", "∞"].contains(text)
        }
    }

    func hasTightNumberAndIdent(_ nodes: [MathNode]) -> Bool {
        for (left, right) in zip(nodes, nodes.dropFirst()) {
            if isNumeric(left), isIdentLike(right) { return true }
        }
        return false
    }

    func isNumeric(_ node: MathNode) -> Bool {
        if case .symbol(let text) = node {
            return text.contains(where: \.isNumber) && !text.contains(where: \.isLetter)
        }
        return false
    }

    func isIdentLike(_ node: MathNode) -> Bool {
        switch node {
        case .symbol(let text):
            return text.contains(where: \.isLetter)
        case .superscript(let base, _), .sub(let base, _):
            return isIdentLike(base)
        default:
            return false
        }
    }

    func unwrapGrouping(_ node: MathNode) -> MathNode {
        guard case .sequence(let nodes) = node, nodes.count >= 3,
              case .symbol(let open) = nodes.first,
              case .symbol(let close) = nodes.last,
              (open == "(" && close == ")")
                || (open == "{" && close == "}")
                || (open == "[" && close == "]")
        else { return node }
        return flatten(Array(nodes.dropFirst().dropLast())) ?? node
    }

    func join(_ nodes: MathNode..., padded: Bool = false) -> MathNode {
        let pieces: [MathNode]
        if padded {
            pieces = nodes.enumerated().flatMap { index, node -> [MathNode] in
                index == 0 ? [node] : [.symbol(" "), node]
            }
        } else {
            pieces = Array(nodes)
        }
        return flatten(pieces) ?? nodes[0]
    }

    mutating func readIdent() -> String? {
        guard let first = peek(), first.isLetter else { return nil }
        var text = read(while: { $0.isLetter })
        text += read(while: { $0 == "'" })
        return text.isEmpty ? nil : text
    }

    func peekIdent() -> String {
        var offset = index
        var collected: [Character] = []
        while offset < characters.count, characters[offset].isLetter {
            collected.append(characters[offset])
            offset += 1
        }
        while offset < characters.count, characters[offset] == "'" {
            collected.append(characters[offset])
            offset += 1
        }
        return String(collected)
    }

    mutating func skipSpaces() {
        while peek()?.isWhitespace == true { advance() }
    }

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
}
