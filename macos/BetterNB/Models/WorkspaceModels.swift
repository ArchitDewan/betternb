import SwiftUI

enum WorkspaceDestination: String, CaseIterable, Identifiable, Sendable {
    case home
    case review
    case study
    case library
    case problems
    case flashcards
    case formulaSheet
    case canvas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .review: "Review"
        case .study: "Study"
        case .library: "Library"
        case .problems: "Problems"
        case .flashcards: "Flashcards"
        case .formulaSheet: "Formula Sheet"
        case .canvas: "Canvas"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .review: "clock.arrow.circlepath"
        case .study: "sparkles"
        case .library: "books.vertical"
        case .problems: "function"
        case .flashcards: "rectangle.on.rectangle"
        case .formulaSheet: "sum"
        case .canvas: "square.and.pencil"
        }
    }

    static let primary: [WorkspaceDestination] = [.home, .review]
    static let courseTools: [WorkspaceDestination] = [
        .study,
        .problems,
    ]
    static let studyTools: [WorkspaceDestination] = [
        .flashcards,
        .formulaSheet,
        .canvas,
    ]

    var acceptsMessages: Bool {
        self == .study
    }
}

enum StudyRoute: Equatable, Sendable {
    case desk
    case conversation
    case worksheet
}

enum StudyDeskInputProposal: Equatable, Sendable {
    case askCourse
    case startProblem
    case choose
}

enum StudyDeskInputRouter {
    static func route(
        for text: String,
        attachment: MessageAttachment? = nil
    ) -> StudyDeskInputProposal? {
        switch proposal(for: text, attachment: attachment) {
        case .startProblem:
            return .startProblem
        case .askCourse, .choose:
            return .askCourse
        case nil:
            return nil
        }
    }

    static func proposal(
        for text: String,
        attachment: MessageAttachment? = nil
    ) -> StudyDeskInputProposal? {
        if attachment != nil {
            return .startProblem
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowered = trimmed.lowercased()
        let problemPrefixes = [
            "calculate ", "determine ", "differentiate ", "evaluate ", "find ",
            "integrate ", "prove ", "simplify ", "solve ",
        ]
        let arithmeticExpression = #"^-?\d+(?:\.\d+)?\s*[+*/^-]\s*-?\d+(?:\.\d+)?$"#
        if problemPrefixes.contains(where: lowered.hasPrefix)
            || trimmed.range(of: arithmeticExpression, options: .regularExpression) != nil
            || TutorMessageKind.looksLikeMathStep(trimmed) {
            return .startProblem
        }

        let questionPrefixes = [
            "can ", "could ", "explain ", "help ", "how ", "what ", "when ",
            "where ", "which ", "why ", "would ",
        ]
        if trimmed.contains("?") || questionPrefixes.contains(where: lowered.hasPrefix) {
            return .askCourse
        }

        return .choose
    }
}

enum WorkspaceLayout {
    static let minimumWindowSize = CGSize(width: 1_040, height: 680)
    static let defaultWindowSize = CGSize(width: 1_420, height: 900)

    static var launchWindowSize: CGSize {
        ProcessInfo.processInfo.environment["BETTERNB_WINDOW"] == "min"
            ? minimumWindowSize
            : defaultWindowSize
    }
}

enum WorkspaceZoom {
    static let comfortable: CGFloat = 1.0
    static let minimum: CGFloat = 1.0
    static let maximum: CGFloat = 1.8
    static let step: CGFloat = 0.1

    static func clamped(_ value: CGFloat) -> CGFloat {
        let snapped = (value * 10).rounded() / 10
        return min(maximum, max(minimum, snapped))
    }
}

struct StudyTool: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let destination: WorkspaceDestination

    static let calculusTools: [StudyTool] = [
        StudyTool(id: "notes", title: "Lecture notes", detail: "Section 2.3", destination: .library),
        StudyTool(id: "problems", title: "Problem set 3", detail: "6 of 12", destination: .problems),
        StudyTool(id: "flashcards", title: "Core definitions", detail: "3 due", destination: .flashcards),
        StudyTool(id: "practice", title: "Quick check", detail: "8 min", destination: .study),
    ]
}

struct RecentStudyItem: Identifiable, Equatable {
    let id: String
    let title: String
    let context: String
    let destination: WorkspaceDestination

    static let calculusItems: [RecentStudyItem] = [
        RecentStudyItem(
            id: "limit-laws",
            title: "Limit laws and direct substitution",
            context: "Notes",
            destination: .library
        ),
        RecentStudyItem(
            id: "one-sided-limits",
            title: "One-sided limits from a graph",
            context: "Practice",
            destination: .study
        ),
        RecentStudyItem(
            id: "continuity-check",
            title: "Continuity checkpoint",
            context: "Quiz",
            destination: .study
        ),
    ]
}

struct SessionMessage: Identifiable, Equatable, Sendable {
    enum Role: Sendable {
        case tutor
        case student
    }

    let id: UUID
    let role: Role
    let text: String
    let attachment: MessageAttachment?
    let sources: [TutorSource]

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        attachment: MessageAttachment? = nil,
        sources: [TutorSource] = []
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.attachment = attachment
        self.sources = sources
    }
}
