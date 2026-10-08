import Foundation
import Testing
@testable import BetterNB

struct TextbookScratchpadTests {
    @Test @MainActor
    func pinsDeduplicateAndOnlySelectedPinsEnterQuestions() {
        let scratchpad = TextbookScratchpadStore()
        scratchpad.pin(sourceID: "one", title: "Lecture.pdf", page: 3, text: "  f(x) = x²  ")
        scratchpad.pin(sourceID: "one", title: "Lecture.pdf", page: 3, text: "f(x) = x²")

        #expect(scratchpad.pins.count == 1)
        #expect(scratchpad.questionWithContext("What is the derivative?") == "What is the derivative?")

        scratchpad.toggleIncluded(scratchpad.pins[0].id)
        #expect(scratchpad.questionWithContext("What is the derivative?").contains("Lecture.pdf, page 3: f(x) = x²"))
    }

    @Test @MainActor
    func quotedSelectionIsRemovableAndOnlySentWithTheNextQuestion() {
        let scratchpad = TextbookScratchpadStore()
        scratchpad.quote(sourceID: "one", title: "Lecture.pdf", page: 7, text: "  ∫ x² dx  ")

        #expect(scratchpad.activeQuote?.text == "∫ x² dx")
        #expect(scratchpad.questionWithContext("How do I integrate this?")
            .contains("Lecture.pdf, page 7: ∫ x² dx"))

        scratchpad.finishQuestion()
        #expect(scratchpad.activeQuote == nil)
        #expect(scratchpad.questionWithContext("How do I integrate this?") == "How do I integrate this?")

        scratchpad.quote(sourceID: "one", title: "Lecture.pdf", page: 7, text: "∫ x² dx")
        scratchpad.clearQuote()
        #expect(scratchpad.activeQuote == nil)
    }
}
