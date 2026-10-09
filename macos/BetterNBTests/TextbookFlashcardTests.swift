import Foundation
import Testing
@testable import BetterNB

@Suite("Textbook flashcards")
struct TextbookFlashcardTests {
    @Test @MainActor
    func reviewRequiresRevealAndTracksGradesAcrossNavigation() {
        let store = TextbookFlashcardStore()
        store.load([
            GeneratedTextbookFlashcard(front: "Product rule?", back: "Differentiate each factor.", sources: []),
            GeneratedTextbookFlashcard(front: "Chain rule?", back: "Differentiate the outer function.", sources: []),
        ])

        #expect(!store.canGrade)
        store.mark(.known)
        #expect(store.reviewedCount == 0)
        store.reveal()
        #expect(store.canGrade)
        store.mark(.known)
        #expect(store.currentIndex == 1)
        #expect(store.knownCount == 1)
        store.reveal()
        store.mark(.again)
        #expect(store.isComplete)
        #expect(store.reviewedCount == 2)
        store.previous()
        #expect(store.currentIndex == 0)
        #expect(store.isRevealed)
        store.flip()
        #expect(!store.isRevealed)
        store.flip()
        #expect(store.isRevealed)
        store.showCard(1)
        #expect(store.currentIndex == 1)
        store.reset()
        #expect(store.cards.isEmpty)
    }
}
