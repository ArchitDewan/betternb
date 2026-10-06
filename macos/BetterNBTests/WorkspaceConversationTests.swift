import Foundation
import Testing
@testable import BetterNB

struct WorkspaceConversationTests {
    @Test
    func studyConversationDoesNotInventAnOpeningContext() async throws {
        let repository = InMemoryChannelMessageRepository()

        #expect(try await repository.messages(in: .study).isEmpty)
    }

    @Test
    func onlyStudyAcceptsMessages() {
        #expect(WorkspaceDestination.allCases.filter(\.acceptsMessages) == [.study])
    }

    @Test
    func sendTrimsTextAndRejectsBlankInput() async throws {
        let repository = InMemoryChannelMessageRepository(messagesByChannel: [:])

        let message = try await repository.send(text: "  Compare both sides  \n", in: .study)
        #expect(message.text == "Compare both sides")
        await #expect(throws: ChannelMessageError.emptyMessage) {
            try await repository.send(text: " \n\t ", in: .study)
        }
        let messages = try await repository.messages(in: .study)
        #expect(messages.map(\.text) == ["Compare both sides"])
    }

    @Test
    func nonStudyDestinationsRejectConversationMessages() async throws {
        let repository = InMemoryChannelMessageRepository(messagesByChannel: [:])

        await #expect(throws: ChannelMessageError.unsupportedDestination) {
            try await repository.send(text: "Explain this definition", in: .library)
        }
        await #expect(throws: ChannelMessageError.unsupportedDestination) {
            try await repository.messages(in: .problems)
        }
    }

    @Test @MainActor
    func sentMessagesRemainVisibleAfterNavigatingToAnotherChannel() async {
        let repository = InMemoryChannelMessageRepository(messagesByChannel: [:])
        let conversations = WorkspaceConversationStore(repository: repository)

        await conversations.load(.study)
        #expect(await conversations.send("Keep this message", in: .study))

        await conversations.load(.library)
        await conversations.load(.study)

        #expect(conversations.messages(in: .study).map(\.text) == ["Keep this message"])
        #expect(conversations.messages(in: .library).isEmpty)
    }

    @Test
    func attachmentCanBeSentWithOrWithoutText() async throws {
        let repository = InMemoryChannelMessageRepository(messagesByChannel: [:])
        let attachment = try MessageAttachment(
            filename: "limit-graph.png",
            mediaType: "image/png",
            data: Data([0x89, 0x50, 0x4E, 0x47])
        )

        let message = try await repository.send(text: "", attachment: attachment, in: .study)

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
