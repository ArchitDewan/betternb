import Foundation
import Observation

enum StudyThreadKind: Equatable {
    case practice
    case courseQuestion
}

struct StudyThreadSummary: Identifiable {
    let id: UUID
    let title: String
    let kind: StudyThreadKind
}

private enum StudyThreadContent {
    case practice(TutorSessionStore)
    case courseQuestion(WorkspaceConversationStore)

    var kind: StudyThreadKind {
        switch self {
        case .practice: .practice
        case .courseQuestion: .courseQuestion
        }
    }
}

private struct StudyThread {
    let id: UUID
    let title: String
    let content: StudyThreadContent

    var summary: StudyThreadSummary {
        StudyThreadSummary(id: id, title: title, kind: content.kind)
    }
}

@MainActor
@Observable
final class StudyThreadStore {
    private var threads: [StudyThread] = []
    private(set) var activeID: UUID?

    var recent: [StudyThreadSummary] {
        Array(all.prefix(3))
    }

    var all: [StudyThreadSummary] {
        threads.reversed().map(\.summary)
    }

    var activeTutor: TutorSessionStore? {
        guard let active = activeThread else { return nil }
        if case .practice(let tutor) = active.content { return tutor }
        return nil
    }

    var activeConversations: WorkspaceConversationStore? {
        guard let active = activeThread else { return nil }
        if case .courseQuestion(let conversations) = active.content { return conversations }
        return nil
    }

    var activeTitle: String? { activeThread?.title }

    @discardableResult
    func startPractice(prompt: String, tutor: TutorSessionStore) -> UUID {
        insert(title: StudyThreadTitle.forPrompt(prompt, kind: .practice), content: .practice(tutor))
    }

    @discardableResult
    func startCourse(question: String, conversations: WorkspaceConversationStore) -> UUID {
        insert(title: StudyThreadTitle.forPrompt(question, kind: .courseQuestion), content: .courseQuestion(conversations))
    }

    @discardableResult
    func activate(_ id: UUID) -> StudyThreadKind? {
        guard let index = threads.firstIndex(where: { $0.id == id }) else { return nil }
        activeID = id
        return threads[index].content.kind
    }

    func showDesk() {
        activeID = nil
    }

    private var activeThread: StudyThread? {
        threads.first { $0.id == activeID }
    }

    private func insert(title: String, content: StudyThreadContent) -> UUID {
        let id = UUID()
        threads.append(StudyThread(id: id, title: title, content: content))
        activeID = id
        return id
    }
}

enum StudyThreadTitle {
    static func forPrompt(_ prompt: String, kind: StudyThreadKind) -> String {
        let source = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            return kind == .practice ? "Untitled problem" : "Untitled question"
        }
        if source.localizedCaseInsensitiveCompare("Image problem") == .orderedSame {
            return "Problem from image"
        }

        let lower = source.lowercased()
        if let match = firstMatch(#"\b(first|second|third|fourth|fifth|sixth|\d+(?:st|nd|rd|th)) roots? of ([^,.?]+)"#, in: source) {
            let ordinal = match[1].capitalized
            let operand = match[2].trimmingCharacters(in: .whitespacesAndNewlines)
            if operand.count <= 12 && !operand.contains("\\") {
                return "\(ordinal) roots of \(readable(operand))"
            }
            return "\(ordinal) roots of a complex number"
        }
        if (lower.contains(#"\lim"#) || lower.contains("limit"))
            && (lower.contains("complex") || lower.contains("conjugate") || lower.contains(#"\overline"#)) {
            if lower.contains(#"z\to0"#) || lower.contains("z→0") || lower.contains("z → 0") {
                return "Complex limit at z → 0"
            }
        }
        if let match = firstMatch(#"image of ([a-z]) under ([a-z])\s*=\s*([a-z])\^(\d+)"#, in: source) {
            return "Image of \(match[1].uppercased()) under \(match[2]) = \(readable(match[3] + "^" + match[4]))"
        }

        var title = readable(source)
        title = title.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = title.first, first.isLowercase {
            title.replaceSubrange(title.startIndex...title.startIndex, with: String(first).uppercased())
        }
        guard !title.isEmpty else {
            return kind == .practice ? "Untitled problem" : "Untitled question"
        }
        guard title.count > 48 else { return title }
        let prefix = String(title.prefix(47))
        let wholeWords = prefix.split(separator: " ").dropLast().joined(separator: " ")
        return String((wholeWords.isEmpty ? prefix : wholeWords).prefix(47)) + "…"
    }

    private static func readable(_ text: String) -> String {
        text.replacingOccurrences(of: #"\("#, with: "")
            .replacingOccurrences(of: #"\)"#, with: "")
            .replacingOccurrences(of: #"\["#, with: "")
            .replacingOccurrences(of: #"\]"#, with: "")
            .replacingOccurrences(of: "^2", with: "²")
            .replacingOccurrences(of: "^3", with: "³")
            .replacingOccurrences(of: "*", with: "×")
            .replacingOccurrences(of: #"\to"#, with: "→")
            .replacingOccurrences(of: #"\pi"#, with: "π")
            .replacingOccurrences(of: #"\theta"#, with: "θ")
            .replacingOccurrences(of: #"\sqrt"#, with: "√")
            .replacingOccurrences(of: #"\[a-zA-Z]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
    }

    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (0..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
    }
}
