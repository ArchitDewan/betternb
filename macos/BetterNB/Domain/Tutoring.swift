import Foundation
import Observation

enum TutorAction: String, Codable, Equatable, Sendable {
    case chat
    case checkStep = "check_step"
    case requestHint = "request_hint"
    case revealSolution = "reveal_solution"
}

enum TutorMessageKind {
    static func looksLikeMathStep(_ text: String) -> Bool {
        let lowered = text.lowercased()
        if lowered.contains("f'(") || lowered.contains("f′(") || lowered.contains("dy/dx") || lowered.contains("d/dx") {
            return true
        }
        let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.contains("?") || stripped.count > 200 { return false }
        return stripped.contains("=") && stripped.unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics
                .union(CharacterSet(charactersIn: "+-*/^().= \t"))
                .contains(scalar)
        }
    }
}

enum TutorVerificationStatus: String, Codable, Equatable, Sendable {
    case verified
    case modelJudged = "model_judged"
    case inconclusive
}

struct TutorSource: Codable, Equatable, Sendable, Identifiable {
    let sourceID: String
    let title: String
    let section: String

    var id: String { sourceID }

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case title
        case section
    }
}

struct TutorTurnRequest: Codable, Equatable, Sendable {
    let sessionID: String
    let problem: String
    let attemptSteps: [String]
    let action: TutorAction
    let hintLevel: Int
    let solutionRevealed: Bool

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case problem
        case attemptSteps = "attempt_steps"
        case action
        case hintLevel = "hint_level"
        case solutionRevealed = "solution_revealed"
    }
}

struct TutorTurnResponse: Codable, Equatable, Sendable {
    let capability: String
    let assessment: String
    let message: String
    let errorCategory: String?
    let verificationStatus: TutorVerificationStatus
    let sources: [TutorSource]
    let actionAccepted: Bool
    let nextHintLevel: Int?
    let nextAction: String

    enum CodingKeys: String, CodingKey {
        case capability
        case assessment
        case message
        case errorCategory = "error_category"
        case verificationStatus = "verification_status"
        case sources
        case actionAccepted = "action_accepted"
        case nextHintLevel = "next_hint_level"
        case nextAction = "next_action"
    }
}

protocol TutorClient: Sendable {
    func transcribe(_ attachment: MessageAttachment) async throws -> String
    func send(_ request: TutorTurnRequest) async throws -> TutorTurnResponse
}

enum TutorTurnKind: Equatable, Sendable {
    case message
    case hint(Int)
    case solution

    var caption: String {
        switch self {
        case .message:
            ""
        case .hint(let level):
            "Hint \(level)"
        case .solution:
            "Solution"
        }
    }
}

struct TutorConversationEntry: Identifiable, Equatable, Sendable {
    enum Role: Equatable, Sendable {
        case student
        case tutor
    }

    let id: UUID
    let role: Role
    let text: String
    let kind: TutorTurnKind
    let verificationStatus: TutorVerificationStatus?
    let assessment: String?
    let errorCategory: String?
    let sources: [TutorSource]

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        kind: TutorTurnKind = .message,
        verificationStatus: TutorVerificationStatus? = nil,
        assessment: String? = nil,
        errorCategory: String? = nil,
        sources: [TutorSource] = []
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.kind = kind
        self.verificationStatus = verificationStatus
        self.assessment = assessment
        self.errorCategory = errorCategory
        self.sources = sources
    }
}

struct PendingMathTranscription: Equatable, Sendable {
    enum Purpose: Sendable {
        case problem
        case step
    }

    let purpose: Purpose
    let note: String
    var text: String
    let filename: String
}

@MainActor
@Observable
final class TutorSessionStore {
    private let client: any TutorClient
    private let sessionID: String
    var minimumResponseDelay: Duration

    private(set) var problem: String?
    private(set) var attemptSteps: [String] = []
    private(set) var entries: [TutorConversationEntry] = []
    private(set) var pendingTranscription: PendingMathTranscription?
    private(set) var nextHintLevel: Int? = 1
    private(set) var solutionRevealed = false
    private(set) var isBusy = false
    private(set) var errorMessage: String?

    var canRevealSolution: Bool {
        problem != nil && !solutionRevealed && pendingTranscription == nil
    }

    init(
        client: any TutorClient,
        sessionID: String = UUID().uuidString,
        minimumResponseDelay: Duration = .milliseconds(400)
    ) {
        self.client = client
        self.sessionID = sessionID
        self.minimumResponseDelay = minimumResponseDelay
    }

    @discardableResult
    func submit(_ text: String, attachment: MessageAttachment? = nil) async -> Bool {
        guard !isBusy else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || attachment != nil else { return false }

        if let attachment {
            guard attachment.mediaType == "image/png" || attachment.mediaType == "image/jpeg" else {
                errorMessage = "Practice accepts PNG and JPEG images."
                return false
            }
            return await prepareTranscription(attachment, note: trimmed)
        }

        if problem == nil {
            problem = trimmed
            return await sendConversation(trimmed, userLabel: trimmed)
        }
        if TutorMessageKind.looksLikeMathStep(trimmed) {
            return await submitStep(trimmed)
        }
        return await sendConversation(trimmed, userLabel: trimmed)
    }

    func updatePendingTranscription(_ text: String) {
        pendingTranscription?.text = text
    }

    @discardableResult
    func confirmTranscription() async -> Bool {
        guard let pendingTranscription else { return false }
        let transcription = pendingTranscription.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcription.isEmpty else {
            errorMessage = "Confirm the extracted math or enter a correction."
            return false
        }
        let combined = [pendingTranscription.note, transcription]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        switch pendingTranscription.purpose {
        case .problem:
            problem = combined
            self.pendingTranscription = nil
            return await sendConversation(combined, userLabel: combined)
        case .step:
            let didSend = TutorMessageKind.looksLikeMathStep(combined)
                ? await submitStep(combined)
                : await sendConversation(combined, userLabel: combined)
            if didSend {
                self.pendingTranscription = nil
            }
            return didSend
        }
    }

    func cancelTranscription() {
        pendingTranscription = nil
        errorMessage = nil
    }

    @discardableResult
    func requestHint() async -> Bool {
        guard let level = nextHintLevel, (1...3).contains(level) else { return false }
        return await perform(action: .requestHint, hintLevel: level, recordStudent: false)
    }

    @discardableResult
    func revealSolution() async -> Bool {
        guard canRevealSolution else { return false }
        let didReveal = await perform(action: .revealSolution, hintLevel: 3, recordStudent: false)
        if didReveal {
            solutionRevealed = true
        }
        return didReveal
    }

    func reset() {
        problem = nil
        attemptSteps = []
        entries = []
        pendingTranscription = nil
        nextHintLevel = 1
        solutionRevealed = false
        errorMessage = nil
    }

    private func prepareTranscription(_ attachment: MessageAttachment, note: String) async -> Bool {
        isBusy = true
        defer { isBusy = false }
        do {
            let transcription = try await client.transcribe(attachment)
            pendingTranscription = PendingMathTranscription(
                purpose: problem == nil ? .problem : .step,
                note: note,
                text: transcription,
                filename: attachment.filename
            )
            errorMessage = nil
            return true
        } catch {
            errorMessage = "The image couldn’t be transcribed. Your work is still here."
            return false
        }
    }

    private func submitStep(_ step: String) async -> Bool {
        guard let problem else { return false }
        let proposedSteps = attemptSteps + [step]
        let request = TutorTurnRequest(
            sessionID: sessionID,
            problem: problem,
            attemptSteps: proposedSteps,
            action: .checkStep,
            hintLevel: 0,
            solutionRevealed: false
        )
        return await send(
            request,
            userLabel: step,
            proposedSteps: proposedSteps,
            recordStudent: true,
            recordAttempt: true
        )
    }

    private func sendConversation(_ message: String, userLabel: String) async -> Bool {
        guard let problem else { return false }
        let request = TutorTurnRequest(
            sessionID: sessionID,
            problem: problem,
            attemptSteps: message == problem ? [] : [message],
            action: .chat,
            hintLevel: 0,
            solutionRevealed: false
        )
        return await send(
            request,
            userLabel: userLabel,
            proposedSteps: attemptSteps,
            recordStudent: true,
            recordAttempt: false
        )
    }

    private func perform(action: TutorAction, hintLevel: Int, recordStudent: Bool) async -> Bool {
        guard let problem else { return false }
        let request = TutorTurnRequest(
            sessionID: sessionID,
            problem: problem,
            attemptSteps: attemptSteps,
            action: action,
            hintLevel: hintLevel,
            solutionRevealed: action == .revealSolution
        )
        return await send(
            request,
            userLabel: "",
            proposedSteps: attemptSteps,
            recordStudent: recordStudent,
            recordAttempt: false
        )
    }

    private func send(
        _ request: TutorTurnRequest,
        userLabel: String,
        proposedSteps: [String],
        recordStudent: Bool,
        recordAttempt: Bool
    ) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        if recordStudent {
            entries.append(TutorConversationEntry(role: .student, text: userLabel))
        }
        let started = ContinuousClock.now
        do {
            let response = try await client.send(request)
            await pauseIfNeeded(since: started)
            guard response.actionAccepted else {
                nextHintLevel = response.nextHintLevel
                errorMessage = response.message
                return false
            }
            if recordAttempt {
                attemptSteps = proposedSteps
            }
            let checked = request.action == .checkStep && response.assessment != "not_assessed"
            entries.append(
                TutorConversationEntry(
                    role: .tutor,
                    text: response.message,
                    kind: kind(for: request),
                    verificationStatus: checked ? response.verificationStatus : nil,
                    assessment: response.assessment,
                    errorCategory: checked ? response.errorCategory : nil,
                    sources: response.sources
                )
            )
            nextHintLevel = response.nextHintLevel
            errorMessage = nil
            return true
        } catch {
            await pauseIfNeeded(since: started)
            errorMessage = "The tutor couldn’t respond. Your work is still here."
            return false
        }
    }

    private func kind(for request: TutorTurnRequest) -> TutorTurnKind {
        switch request.action {
        case .requestHint:
            .hint(request.hintLevel)
        case .revealSolution:
            .solution
        case .chat, .checkStep:
            .message
        }
    }

    private func pauseIfNeeded(since started: ContinuousClock.Instant) async {
        let elapsed = started.duration(to: .now)
        if elapsed < minimumResponseDelay {
            try? await Task.sleep(for: minimumResponseDelay - elapsed)
        }
    }
}
