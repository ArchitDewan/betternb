import Foundation

struct TextbookSummaryIdea: Codable, Equatable, Sendable {
    let heading: String
    let explanation: String
    let sources: [TutorSource]
}

struct GeneratedTextbookSummary: Codable, Equatable, Sendable {
    let overview: String
    let ideas: [TextbookSummaryIdea]
}
