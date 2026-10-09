import Foundation
import Observation

struct GeneratedTextbookFlashcard: Codable, Equatable, Sendable {
    let front: String
    let back: String
    let sources: [TutorSource]
}

struct GeneratedFlashcardsEnvelope: Codable, Equatable, Sendable {
    let cards: [GeneratedTextbookFlashcard]
}

enum FlashcardGrade: Sendable {
    case again, known
}

@MainActor
@Observable
final class TextbookFlashcardStore {
    var requestedCount = 5
    private(set) var cards: [GeneratedTextbookFlashcard] = []
    private(set) var currentIndex = 0
    private(set) var isRevealed = false
    private(set) var grades: [Int: FlashcardGrade] = [:]

    var canGrade: Bool { !cards.isEmpty && isRevealed }
    var reviewedCount: Int { grades.count }
    var knownCount: Int { grades.values.filter { $0 == .known }.count }
    var isComplete: Bool { !cards.isEmpty && grades.count == cards.count }

    func load(_ generated: [GeneratedTextbookFlashcard]) {
        cards = generated
        currentIndex = 0
        isRevealed = false
        grades = [:]
    }

    func reveal() {
        guard cards.indices.contains(currentIndex) else { return }
        isRevealed = true
    }

    func flip() {
        guard cards.indices.contains(currentIndex) else { return }
        isRevealed.toggle()
    }

    func mark(_ grade: FlashcardGrade) {
        guard canGrade else { return }
        grades[currentIndex] = grade
        if currentIndex < cards.count - 1 {
            currentIndex += 1
            isRevealed = grades[currentIndex] != nil
        }
    }

    func previous() { show(currentIndex - 1) }
    func next() { show(currentIndex + 1) }
    func showCard(_ index: Int) { show(index) }

    func reset() {
        cards = []
        currentIndex = 0
        isRevealed = false
        grades = [:]
    }

    func restart() {
        currentIndex = 0
        isRevealed = false
        grades = [:]
    }

    private func show(_ index: Int) {
        guard cards.indices.contains(index) else { return }
        currentIndex = index
        isRevealed = grades[index] != nil
    }
}
