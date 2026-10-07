import Foundation
import Observation
import UniformTypeIdentifiers

struct MessageAttachment: Identifiable, Equatable, Sendable {
    static let maximumBytes = 10 * 1_024 * 1_024
    static let supportedMediaTypes = ["image/png", "image/jpeg", "application/pdf"]

    let id: UUID
    let filename: String
    let mediaType: String
    let data: Data

    var byteCount: Int { data.count }

    init(
        id: UUID = UUID(),
        filename: String,
        mediaType: String,
        data: Data
    ) throws {
        guard Self.supportedMediaTypes.contains(mediaType) else {
            throw ChannelMessageError.unsupportedAttachment
        }
        guard data.count <= Self.maximumBytes else {
            throw ChannelMessageError.attachmentTooLarge
        }

        self.id = id
        self.filename = filename
        self.mediaType = mediaType
        self.data = data
    }

    static func importing(_ url: URL) throws -> MessageAttachment {
        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let values = try url.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey])
        if let fileSize = values.fileSize, fileSize > maximumBytes {
            throw ChannelMessageError.attachmentTooLarge
        }

        guard let contentType = values.contentType,
              let mediaType = supportedMediaType(for: contentType) else {
            throw ChannelMessageError.unsupportedAttachment
        }

        return try MessageAttachment(
            filename: url.lastPathComponent,
            mediaType: mediaType,
            data: Data(contentsOf: url, options: .mappedIfSafe)
        )
    }

    private static func supportedMediaType(for contentType: UTType) -> String? {
        if contentType.conforms(to: .png) {
            "image/png"
        } else if contentType.conforms(to: .jpeg) {
            "image/jpeg"
        } else if contentType.conforms(to: .pdf) {
            "application/pdf"
        } else {
            nil
        }
    }
}

enum ChannelMessageError: Error, Equatable {
    case unsupportedDestination
    case emptyMessage
    case unsupportedAttachment
    case attachmentTooLarge
}

protocol ChannelMessageRepository: Sendable {
    func messages(in channel: WorkspaceDestination) async throws -> [SessionMessage]
    func send(
        text: String,
        attachment: MessageAttachment?,
        in channel: WorkspaceDestination
    ) async throws -> SessionMessage
}

extension ChannelMessageRepository {
    func send(text: String, in channel: WorkspaceDestination) async throws -> SessionMessage {
        try await send(text: text, attachment: nil, in: channel)
    }
}

actor InMemoryChannelMessageRepository: ChannelMessageRepository {
    private var messagesByChannel: [WorkspaceDestination: [SessionMessage]]

    init(messagesByChannel: [WorkspaceDestination: [SessionMessage]] = [:]) {
        self.messagesByChannel = messagesByChannel
    }

    func messages(in channel: WorkspaceDestination) throws -> [SessionMessage] {
        guard channel.acceptsMessages else {
            throw ChannelMessageError.unsupportedDestination
        }
        return messagesByChannel[channel, default: []]
    }

    func send(
        text: String,
        attachment: MessageAttachment?,
        in channel: WorkspaceDestination
    ) throws -> SessionMessage {
        guard channel.acceptsMessages else {
            throw ChannelMessageError.unsupportedDestination
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty || attachment != nil else {
            throw ChannelMessageError.emptyMessage
        }

        let message = SessionMessage(
            role: .student,
            text: trimmedText,
            attachment: attachment
        )
        messagesByChannel[channel, default: []].append(message)
        return message
    }
}

@MainActor
@Observable
final class WorkspaceConversationStore {
    private let repository: any ChannelMessageRepository
    var composerDraft = ""
    var composerAttachment: MessageAttachment?
    private var loadedChannels: Set<WorkspaceDestination> = []
    private(set) var messagesByChannel: [WorkspaceDestination: [SessionMessage]] = [:]
    private(set) var sendingChannels: Set<WorkspaceDestination> = []
    private(set) var errorsByChannel: [WorkspaceDestination: String] = [:]

    init(repository: any ChannelMessageRepository) {
        self.repository = repository
    }

    func messages(in channel: WorkspaceDestination) -> [SessionMessage] {
        messagesByChannel[channel, default: []]
    }

    func load(_ channel: WorkspaceDestination) async {
        guard channel.acceptsMessages, !loadedChannels.contains(channel) else { return }

        do {
            let loadedMessages = try await repository.messages(in: channel)
            let loadedIDs = Set(loadedMessages.map(\.id))
            let messagesAddedWhileLoading = messagesByChannel[channel, default: []]
                .filter { !loadedIDs.contains($0.id) }
            messagesByChannel[channel] = loadedMessages + messagesAddedWhileLoading
            loadedChannels.insert(channel)
            errorsByChannel[channel] = nil
        } catch {
            errorsByChannel[channel] = "Messages couldn’t be loaded. Try again."
        }
    }

    @discardableResult
    func send(
        _ text: String,
        attachment: MessageAttachment? = nil,
        in channel: WorkspaceDestination
    ) async -> Bool {
        guard channel.acceptsMessages else { return false }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty || attachment != nil else { return false }

        await load(channel)
        guard !sendingChannels.contains(channel) else { return false }
        sendingChannels.insert(channel)
        defer { sendingChannels.remove(channel) }

        do {
            let message = try await repository.send(
                text: trimmedText,
                attachment: attachment,
                in: channel
            )
            messagesByChannel[channel, default: []].append(message)
            errorsByChannel[channel] = nil
            return true
        } catch {
            errorsByChannel[channel] = "Your message wasn’t sent. Your draft is still here."
            return false
        }
    }

    func appendTutorReply(
        _ text: String,
        sources: [TutorSource] = [],
        in channel: WorkspaceDestination
    ) {
        messagesByChannel[channel, default: []].append(
            SessionMessage(role: .tutor, text: text, sources: sources)
        )
    }

    func appendPreviewTutorReply(_ text: String, in channel: WorkspaceDestination) {
        appendTutorReply(text, in: channel)
    }
}
