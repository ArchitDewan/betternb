import Foundation
import Testing
@testable import BetterNB

struct TextbookScratchpadTests {
    @Test @MainActor
    func imageOnlyQuestionKeepsAttachmentInPendingExchange() throws {
        let scratchpad = TextbookScratchpadStore()
        let image = try MessageAttachment(filename: "diagram.png", mediaType: "image/png", data: Data([1, 2, 3]))
        scratchpad.attachment = image

        let submitted = scratchpad.submitQuestion()

        #expect(submitted?.attachment == image)
        #expect(submitted?.prompt == "What is in this image?")
        #expect(scratchpad.exchanges.first?.attachment == image)
        #expect(scratchpad.attachment == nil)
    }

    @Test @MainActor
    func submittedQuestionAppearsPendingBeforeAnAnswerArrives() {
        let scratchpad = TextbookScratchpadStore()
        scratchpad.question = "  What does this mean?  "
        scratchpad.quote(sourceID: "one", title: "Lecture.pdf", page: 7, text: "f(x) = x²")

        let submitted = scratchpad.submitQuestion()

        #expect(submitted?.prompt.contains("Lecture.pdf, page 7: f(x) = x²") == true)
        #expect(scratchpad.exchanges.count == 1)
        #expect(scratchpad.exchanges[0].question == "What does this mean?")
        #expect(scratchpad.exchanges[0].quote?.text == "f(x) = x²")
        #expect(scratchpad.exchanges[0].quote?.page == 7)
        #expect(scratchpad.exchanges[0].isPending)
        #expect(scratchpad.question.isEmpty)
        #expect(scratchpad.activeQuote == nil)

        let answer = GroundedCourseAnswer(answer: "It is a parabola.", sources: [])
        scratchpad.completeQuestion(submitted!.id, answer: answer)
        #expect(scratchpad.exchanges[0].answer == answer)
        #expect(!scratchpad.exchanges[0].isPending)
    }

    @Test @MainActor
    func failedQuestionRemainsVisible() {
        let scratchpad = TextbookScratchpadStore()
        scratchpad.question = "Explain this page"
        let submitted = scratchpad.submitQuestion()!

        scratchpad.failQuestion(submitted.id, message: "Couldn’t reach the tutor.")

        #expect(scratchpad.exchanges[0].question == "Explain this page")
        #expect(scratchpad.exchanges[0].errorMessage == "Couldn’t reach the tutor.")
        #expect(!scratchpad.exchanges[0].isPending)
    }

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
