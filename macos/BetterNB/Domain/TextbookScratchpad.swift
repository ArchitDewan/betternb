import Foundation
import Observation

struct TextbookPin: Identifiable, Equatable {
    let id: UUID
    let sourceID: String
    let title: String
    let page: Int
    let text: String
    var isIncluded: Bool
}

struct TextbookQuote: Equatable {
    let sourceID: String
    let title: String
    let page: Int
    let text: String
}

struct TextbookExchange: Identifiable, Equatable {
    let id: UUID
    let question: String
    let attachment: MessageAttachment?
    var answer: GroundedCourseAnswer?
    var errorMessage: String?

    var isPending: Bool { answer == nil && errorMessage == nil }
}

@MainActor
@Observable
final class TextbookScratchpadStore {
    var question = ""
    var attachment: MessageAttachment?
    private(set) var activeQuote: TextbookQuote?
    private(set) var pins: [TextbookPin] = []
    private(set) var exchanges: [TextbookExchange] = []

    func submitQuestion() -> (id: UUID, prompt: String, attachment: MessageAttachment?)? {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let submittedAttachment = attachment
        guard !trimmed.isEmpty || submittedAttachment != nil else { return nil }
        let visibleQuestion = trimmed.isEmpty ? "What is in this image?" : trimmed
        let prompt = questionWithContext(visibleQuestion)
        let id = UUID()
        exchanges.append(TextbookExchange(id: id, question: visibleQuestion,
                                          attachment: submittedAttachment, answer: nil, errorMessage: nil))
        question = ""
        attachment = nil
        clearQuote()
        return (id, prompt, submittedAttachment)
    }

    func completeQuestion(_ id: UUID, answer: GroundedCourseAnswer) {
        guard let index = exchanges.firstIndex(where: { $0.id == id }) else { return }
        exchanges[index].answer = answer
    }

    func failQuestion(_ id: UUID, message: String) {
        guard let index = exchanges.firstIndex(where: { $0.id == id }) else { return }
        exchanges[index].errorMessage = message
    }

    func pin(sourceID: String, title: String, page: Int, text: String) {
        let excerpt = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1200))
        guard !excerpt.isEmpty,
              !pins.contains(where: { $0.sourceID == sourceID && $0.page == page && $0.text == excerpt })
        else { return }
        pins.append(TextbookPin(id: UUID(), sourceID: sourceID, title: title, page: page, text: excerpt, isIncluded: false))
    }

    func toggleIncluded(_ id: UUID) {
        guard let index = pins.firstIndex(where: { $0.id == id }) else { return }
        pins[index].isIncluded.toggle()
    }

    func remove(_ id: UUID) {
        pins.removeAll { $0.id == id }
    }

    func quote(sourceID: String, title: String, page: Int, text: String) {
        let excerpt = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1200))
        guard !excerpt.isEmpty else { return }
        activeQuote = TextbookQuote(sourceID: sourceID, title: title, page: page, text: excerpt)
    }

    func clearQuote() {
        activeQuote = nil
    }

    func finishQuestion() {
        clearQuote()
    }

    func questionWithContext(_ question: String) -> String {
        var excerpts: [TextbookQuote] = []
        if let activeQuote { excerpts.append(activeQuote) }
        for pin in pins where pin.isIncluded {
            let excerpt = TextbookQuote(sourceID: pin.sourceID, title: pin.title, page: pin.page, text: pin.text)
            if !excerpts.contains(excerpt) { excerpts.append(excerpt) }
        }
        guard !excerpts.isEmpty else { return question }
        let context = excerpts.map { "\($0.title), page \($0.page): \($0.text)" }.joined(separator: "\n\n")
        return "\(question)\n\nSource excerpts:\n\(context)"
    }
}
