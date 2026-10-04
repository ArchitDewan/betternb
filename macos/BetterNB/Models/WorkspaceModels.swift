import SwiftUI

enum WorkspaceDestination: String, CaseIterable, Identifiable, Sendable {
    case home
    case search
    case review
    case overview
    case materials
    case notes
    case problems
    case practice
    case flashcards
    case formulaSheet
    case canvas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .search: "Search"
        case .review: "Review"
        case .overview: "Overview"
        case .materials: "Materials"
        case .notes: "Notes"
        case .problems: "Problems"
        case .practice: "Practice"
        case .flashcards: "Flashcards"
        case .formulaSheet: "Formula Sheet"
        case .canvas: "Canvas"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .search: "magnifyingglass"
        case .review: "clock.arrow.circlepath"
        case .overview: "square.grid.2x2"
        case .materials: "books.vertical"
        case .notes: "note.text"
        case .problems: "function"
        case .practice: "target"
        case .flashcards: "rectangle.on.rectangle"
        case .formulaSheet: "sum"
        case .canvas: "square.and.pencil"
        }
    }

    static let primary: [WorkspaceDestination] = [.home, .search, .review]
    static let courseTools: [WorkspaceDestination] = [
        .overview,
        .materials,
        .notes,
        .problems,
        .practice,
        .flashcards,
        .formulaSheet,
        .canvas,
    ]

    var acceptsMessages: Bool {
        switch self {
        case .materials, .notes, .problems, .practice, .flashcards, .formulaSheet, .canvas:
            true
        case .home, .search, .review, .overview:
            false
        }
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
    static let comfortable: CGFloat = 1.1
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
        StudyTool(id: "notes", title: "Lecture notes", detail: "Section 2.3", destination: .notes),
        StudyTool(id: "problems", title: "Problem set 3", detail: "6 of 12", destination: .problems),
        StudyTool(id: "flashcards", title: "Core definitions", detail: "3 due", destination: .flashcards),
        StudyTool(id: "practice", title: "Quick check", detail: "8 min", destination: .practice),
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
            destination: .notes
        ),
        RecentStudyItem(
            id: "one-sided-limits",
            title: "One-sided limits from a graph",
            context: "Practice",
            destination: .practice
        ),
        RecentStudyItem(
            id: "continuity-check",
            title: "Continuity checkpoint",
            context: "Quiz",
            destination: .practice
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

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        attachment: MessageAttachment? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.attachment = attachment
    }

    static let opening: [SessionMessage] = [
        SessionMessage(
            role: .tutor,
            text: "You’ve got the graph. I won’t name the limit. What do the left- and right-hand values look like?"
        ),
    ]
}
