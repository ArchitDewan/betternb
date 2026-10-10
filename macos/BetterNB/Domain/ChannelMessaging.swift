import AppKit
import Foundation
import PDFKit
import Observation
import UniformTypeIdentifiers

struct MessageAttachment: Identifiable, Equatable, Sendable, Codable {
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
        try self.init(id: id, filename: filename, mediaType: mediaType, data: data,
                      limit: Self.maximumBytes)
    }

    private init(id: UUID = UUID(), filename: String, mediaType: String,
                 data: Data, limit: Int) throws {
        guard Self.supportedMediaTypes.contains(mediaType) else {
            throw ChannelMessageError.unsupportedAttachment
        }
        guard data.count <= limit else {
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

    static func importingWorksheet(_ url: URL) throws -> MessageAttachment {
        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer { if hasSecurityScope { url.stopAccessingSecurityScopedResource() } }
        let extensionName = url.pathExtension.lowercased()
        if extensionName == "heic" || extensionName == "heif" {
            guard let image = NSImage(contentsOf: url),
                  let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
                throw ChannelMessageError.unsupportedAttachment
            }
            return try MessageAttachment(filename: url.deletingPathExtension().lastPathComponent + ".jpg",
                                         mediaType: "image/jpeg", data: jpeg)
        }
        let values = try url.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey])
        let limit = 25 * 1_024 * 1_024
        if let fileSize = values.fileSize, fileSize > limit {
            throw ChannelMessageError.attachmentTooLarge
        }
        guard let contentType = values.contentType,
              let mediaType = supportedMediaType(for: contentType) else {
            throw ChannelMessageError.unsupportedAttachment
        }
        return try MessageAttachment(filename: url.lastPathComponent, mediaType: mediaType,
                                     data: Data(contentsOf: url, options: .mappedIfSafe), limit: limit)
    }

    static func importingWorksheetFiles(_ urls: [URL]) throws -> MessageAttachment {
        guard !urls.isEmpty else { throw ChannelMessageError.unsupportedAttachment }
        if urls.count == 1 { return try importingWorksheet(urls[0]) }
        let document = PDFDocument()
        for url in urls {
            let attachment = try importingWorksheet(url)
            if attachment.mediaType == "application/pdf" {
                guard let source = PDFDocument(data: attachment.data) else {
                    throw ChannelMessageError.unsupportedAttachment
                }
                for index in 0..<source.pageCount {
                    if let page = source.page(at: index) { document.insert(page, at: document.pageCount) }
                }
            } else {
                guard let image = NSImage(data: attachment.data), let page = PDFPage(image: image) else {
                    throw ChannelMessageError.unsupportedAttachment
                }
                document.insert(page, at: document.pageCount)
            }
        }
        guard let data = document.dataRepresentation() else {
            throw ChannelMessageError.unsupportedAttachment
        }
        return try MessageAttachment(filename: "Worksheet (\(urls.count) files).pdf",
                                     mediaType: "application/pdf", data: data,
                                     limit: 25 * 1_024 * 1_024)
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
