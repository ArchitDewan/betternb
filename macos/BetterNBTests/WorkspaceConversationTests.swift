import Foundation
import Testing
@testable import BetterNB

struct WorkspaceConversationTests {
    @Test
    func onlyCourseConversationSurfacesAcceptMessages() {
        let expected: Set<WorkspaceDestination> = [
            .materials,
            .notes,
            .problems,
            .practice,
            .flashcards,
            .formulaSheet,
            .canvas,
        ]

        #expect(Set(WorkspaceDestination.allCases.filter(\.acceptsMessages)) == expected)
    }

    @Test
    func sendTrimsTextAndRejectsBlankInput() async throws {
        let repository = InMemoryChannelMessageRepository(messagesByChannel: [:])

        let message = try await repository.send(text: "  Compare both sides  \n", in: .problems)
        #expect(message.text == "Compare both sides")
        await #expect(throws: ChannelMessageError.emptyMessage) {
            try await repository.send(text: " \n\t ", in: .problems)
        }
        let messages = try await repository.messages(in: .problems)
        #expect(messages.map(\.text) == ["Compare both sides"])
    }

    @Test
    func conversationsRemainIsolatedByDestination() async throws {
        let repository = InMemoryChannelMessageRepository(messagesByChannel: [:])

        _ = try await repository.send(text: "Explain this definition", in: .notes)
        _ = try await repository.send(text: "Connect these ideas", in: .canvas)

        let notes = try await repository.messages(in: .notes)
        let canvas = try await repository.messages(in: .canvas)
        #expect(notes.map(\.text) == ["Explain this definition"])
        #expect(canvas.map(\.text) == ["Connect these ideas"])
        await #expect(throws: ChannelMessageError.unsupportedDestination) {
            try await repository.messages(in: .overview)
        }
    }

    @Test @MainActor
    func sentMessagesRemainVisibleAfterNavigatingToAnotherChannel() async {
        let repository = InMemoryChannelMessageRepository(messagesByChannel: [:])
        let conversations = WorkspaceConversationStore(repository: repository)

        await conversations.load(.notes)
        #expect(await conversations.send("Keep this message", in: .notes))

        await conversations.load(.problems)
        await conversations.load(.notes)

        #expect(conversations.messages(in: .notes).map(\.text) == ["Keep this message"])
        #expect(conversations.messages(in: .problems).isEmpty)
    }

    @Test
    func attachmentCanBeSentWithOrWithoutText() async throws {
        let repository = InMemoryChannelMessageRepository(messagesByChannel: [:])
        let attachment = try MessageAttachment(
            filename: "limit-graph.png",
            mediaType: "image/png",
            data: Data([0x89, 0x50, 0x4E, 0x47])
        )

        let message = try await repository.send(text: "", attachment: attachment, in: .notes)

        #expect(message.text.isEmpty)
        #expect(message.attachment?.filename == "limit-graph.png")
        #expect(message.attachment?.mediaType == "image/png")
    }

    @Test
    func attachmentValidationRejectsUnsupportedAndOversizedFiles() {
        #expect(throws: ChannelMessageError.unsupportedAttachment) {
            try MessageAttachment(
                filename: "notes.txt",
                mediaType: "text/plain",
                data: Data("hello".utf8)
            )
        }

        #expect(throws: ChannelMessageError.attachmentTooLarge) {
            try MessageAttachment(
                filename: "book.pdf",
                mediaType: "application/pdf",
                data: Data(repeating: 0, count: MessageAttachment.maximumBytes + 1)
            )
        }
    }
}
