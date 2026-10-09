import Foundation
import Testing
@testable import BetterNB

struct TextbookQuizTests {
    private let sample = GeneratedTextbookQuiz(
        questions: [
            TextbookQuizQuestion(prompt: "What is 2 + 2?", options: ["3", "4", "5", "6"],
                                 correctIndex: 1, explanation: "Two and two make four."),
            TextbookQuizQuestion(prompt: "What is 3 + 3?", options: ["5", "6", "7", "8"],
                                 correctIndex: 1, explanation: "Three and three make six.")
        ],
        sources: []
    )

    @Test @MainActor
    func immediateRevealLocksEachAnswerAndScoresAtFinish() {
        let quiz = TextbookQuizStore()
        quiz.revealAfterSelection = true
        quiz.load(sample)

        quiz.select(question: 0, option: 0)
        #expect(quiz.isRevealed(0))
        quiz.select(question: 0, option: 1)
        #expect(quiz.selectedAnswers[0] == 0)
        #expect(!quiz.canFinish)

        quiz.select(question: 1, option: 1)
        #expect(quiz.canFinish)
        quiz.finish()
        #expect(quiz.score == 1)
    }

    @Test @MainActor
    func deferredRevealAllowsChangingChoicesUntilFinish() {
        let quiz = TextbookQuizStore()
        quiz.revealAfterSelection = false
        quiz.load(sample)

        quiz.select(question: 0, option: 0)
        #expect(!quiz.isRevealed(0))
        quiz.select(question: 0, option: 1)
        #expect(quiz.selectedAnswers[0] == 1)
        quiz.select(question: 1, option: 1)
        quiz.finish()

        #expect(quiz.isRevealed(0))
        #expect(quiz.score == 2)
        quiz.select(question: 0, option: 0)
        #expect(quiz.selectedAnswers[0] == 1)
    }
}
