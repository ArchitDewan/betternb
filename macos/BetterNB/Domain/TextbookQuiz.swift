import Foundation
import Observation

enum QuizDifficulty: String, CaseIterable, Identifiable, Sendable {
    case easy, standard, challenging

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct TextbookQuizQuestion: Codable, Equatable, Sendable {
    let prompt: String
    let options: [String]
    let correctIndex: Int
    let explanation: String

    enum CodingKeys: String, CodingKey {
        case prompt, options, explanation
        case correctIndex = "correct_index"
    }
}

struct GeneratedTextbookQuiz: Codable, Equatable, Sendable {
    let questions: [TextbookQuizQuestion]
    let sources: [TutorSource]
}

@MainActor
@Observable
final class TextbookQuizStore {
    var difficulty: QuizDifficulty = .standard
    var questionCount = 5
    var revealAfterSelection = true

    private(set) var quiz: GeneratedTextbookQuiz?
    private(set) var selectedAnswers: [Int: Int] = [:]
    private(set) var isFinished = false
    private(set) var revealsImmediately = true

    var canFinish: Bool {
        guard let quiz, !isFinished else { return false }
        return selectedAnswers.count == quiz.questions.count
    }

    var score: Int {
        guard let quiz else { return 0 }
        return quiz.questions.enumerated().filter { index, question in
            selectedAnswers[index] == question.correctIndex
        }.count
    }

    func load(_ generated: GeneratedTextbookQuiz) {
        quiz = generated
        selectedAnswers = [:]
        isFinished = false
        revealsImmediately = revealAfterSelection
    }

    func select(question index: Int, option: Int) {
        guard let quiz, quiz.questions.indices.contains(index),
              quiz.questions[index].options.indices.contains(option),
              !isFinished,
              !(revealsImmediately && selectedAnswers[index] != nil)
        else { return }
        selectedAnswers[index] = option
    }

    func isRevealed(_ index: Int) -> Bool {
        isFinished || (revealsImmediately && selectedAnswers[index] != nil)
    }

    func finish() {
        guard canFinish else { return }
        isFinished = true
    }

    func reset() {
        quiz = nil
        selectedAnswers = [:]
        isFinished = false
    }
}
