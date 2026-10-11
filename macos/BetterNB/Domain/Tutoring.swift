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
        let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.contains("?") || stripped.count > 200 { return false }
        let lowered = stripped.lowercased()
        if lowered.contains("f'(") || lowered.contains("f′(") || lowered.contains("dy/dx") || lowered.contains("d/dx") {
            return true
        }
        if stripped.contains("\\") || stripped.contains("$") {
            return true
        }
        return stripped.contains("=") && stripped.unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics
                .union(CharacterSet(charactersIn: "+-*/^().= \t\\_{}"))
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

struct TutorConversationTurn: Codable, Equatable, Sendable {
    let role: String
    let text: String
    let kind: String
}

enum TutorSubmitIntent: Sendable {
    case automatic
    case ask
    case check
}

struct TutorTurnRequest: Codable, Equatable, Sendable {
    let sessionID: String
    let problem: String
    let attemptSteps: [String]
    let conversation: [TutorConversationTurn]
    let action: TutorAction
    let hintLevel: Int
    let solutionRevealed: Bool

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case problem
        case attemptSteps = "attempt_steps"
        case conversation
        case action
        case hintLevel = "hint_level"
        case solutionRevealed = "solution_revealed"
    }
}

struct TutorTurnResponse: Codable, Equatable, Sendable {
    let capability: String
    let assessment: String
    let message: String
    let summary: String?
    let errorCategory: String?
    let verificationStatus: TutorVerificationStatus
    let sources: [TutorSource]
    let actionAccepted: Bool
    let nextHintLevel: Int?
    let nextAction: String

    init(
        capability: String,
        assessment: String,
        message: String,
        summary: String? = nil,
        errorCategory: String? = nil,
        verificationStatus: TutorVerificationStatus,
        sources: [TutorSource],
        actionAccepted: Bool = true,
        nextHintLevel: Int? = nil,
        nextAction: String
    ) {
        self.capability = capability
        self.assessment = assessment
        self.message = message
        self.summary = summary
        self.errorCategory = errorCategory
        self.verificationStatus = verificationStatus
        self.sources = sources
        self.actionAccepted = actionAccepted
        self.nextHintLevel = nextHintLevel
        self.nextAction = nextAction
    }

    enum CodingKeys: String, CodingKey {
        case capability
        case assessment
        case message
        case summary
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

enum TutorTurnKind: Equatable, Sendable, Codable {
    case problem
    case message
    case step(Int)
    case hint(Int)
    case solution

    var caption: String {
        switch self {
        case .problem:
            "Problem"
        case .message:
            ""
        case .step(let number):
            "Step \(number)"
        case .hint(let level):
            "Hint \(level)"
        case .solution:
            "Solution"
        }
    }

    var wireName: String {
        switch self {
        case .problem: "problem"
        case .message: "message"
        case .step: "step"
        case .hint: "hint"
        case .solution: "solution"
        }
    }
}

struct TutorConversationEntry: Identifiable, Equatable, Sendable, Codable {
    enum Role: Equatable, Sendable, Codable {
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
    let summary: String?

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        kind: TutorTurnKind = .message,
        verificationStatus: TutorVerificationStatus? = nil,
        assessment: String? = nil,
        errorCategory: String? = nil,
        sources: [TutorSource] = [],
        summary: String? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.kind = kind
        self.verificationStatus = verificationStatus
        self.assessment = assessment
        self.errorCategory = errorCategory
        self.sources = sources
        self.summary = summary
    }
}

enum PracticeStepStatus: Equatable, Sendable {
    case pending
    case correct
    case incorrect
    case unchecked
}

struct PracticeWorksheetStep: Identifiable, Equatable, Sendable {
    let id: UUID
    let number: Int
    let text: String
    let status: PracticeStepStatus
    let diagnosis: String?
    let feedback: String?
    let summary: String?
    let errorCategory: String?
    let verificationStatus: TutorVerificationStatus?
    let sources: [TutorSource]
    let isFocus: Bool
}

struct PracticeInspectorSnapshot: Equatable, Sendable {
    let checkedCount: Int
    let totalCount: Int
    let verdict: String?
    let errorType: String?
    let concept: String?
    let sourceTitle: String?
    let sourceSection: String?
    let note: String?
    let noteCaption: String
}

struct PracticeWorksheetNote: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let text: String
    let emphasized: Bool
}

struct RevealedSolutionStep: Identifiable, Equatable, Sendable {
    let number: Int
    let text: String

    var id: Int { number }

    var boxedAnswer: String? {
        boxedMatch?.answer
    }

    var textWithoutBoxedAnswer: String {
        guard let match = boxedMatch else { return text }
        var remainder = text
        remainder.removeSubrange(match.range)
        return remainder
            .replacingOccurrences(of: " .", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var boxedMatch: (range: Range<String.Index>, answer: String)? {
        let command = text.range(of: #"\boxed{"#, options: .backwards)
            ?? text.range(of: "boxed{", options: .backwards)
        guard let command else { return nil }

        var depth = 1
        var cursor = command.upperBound
        while cursor < text.endIndex {
            let character = text[cursor]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    let afterClosingBrace = text.index(after: cursor)
                    return (
                        command.lowerBound..<afterClosingBrace,
                        String(text[command.upperBound..<cursor])
                    )
                }
            }
            cursor = text.index(after: cursor)
        }
        return nil
    }
}

struct RevealedSolutionLayout: Equatable, Sendable {
    let introduction: String?
    let steps: [RevealedSolutionStep]

    init(_ source: String) {
        let normalized = Self.repairBareBoxedCommands(in: source)
        let text = normalized as NSString
        let range = NSRange(location: 0, length: text.length)
        let expression = try? NSRegularExpression(
            pattern: #"(?i)\bStep\s+(\d+)\s*[.:]\s*"#
        )
        let matches = expression?.matches(in: normalized, range: range) ?? []

        guard !matches.isEmpty else {
            let content = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
            let sentences = Self.sentences(in: content)
            if sentences.count >= 3 {
                introduction = nil
                steps = sentences.enumerated().map { index, sentence in
                    RevealedSolutionStep(number: index + 1, text: sentence)
                }
            } else {
                introduction = content.isEmpty ? nil : content
                steps = []
            }
            return
        }

        let opening = text.substring(with: NSRange(location: 0, length: matches[0].range.location))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        introduction = opening.isEmpty ? nil : opening

        steps = matches.enumerated().compactMap { index, match in
            guard let numberRange = Range(match.range(at: 1), in: normalized),
                  let number = Int(normalized[numberRange]) else {
                return nil
            }
            let contentStart = NSMaxRange(match.range)
            let contentEnd = index + 1 < matches.count ? matches[index + 1].range.location : text.length
            guard contentEnd >= contentStart else { return nil }
            let content = text.substring(
                with: NSRange(location: contentStart, length: contentEnd - contentStart)
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { return nil }
            return RevealedSolutionStep(number: number, text: content)
        }
    }

    private static func repairBareBoxedCommands(in source: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: #"(?<!\\)\bboxed\s*\{"#) else {
            return source
        }
        let repaired = NSMutableString(string: source)
        let matches = expression.matches(
            in: source,
            range: NSRange(location: 0, length: (source as NSString).length)
        )
        for match in matches.reversed() {
            repaired.replaceCharacters(in: match.range, with: #"\boxed{"#)
        }
        return repaired as String
    }

    private static func sentences(in source: String) -> [String] {
        guard !source.isEmpty else { return [] }
        let text = source as NSString
        let fullRange = NSRange(location: 0, length: text.length)
        let punctuation = try? NSRegularExpression(pattern: #"(?<=[.!?])\s+(?=[A-Z])"#)
        let transitions = try? NSRegularExpression(
            pattern: #"\b(?:For your function|The exponent|Here the exponent|Apply|Applying|Simplify|Subtract|Since|Therefore|Now|Next|Finally)\b"#
        )
        var boundarySet: Set<Int> = [0, text.length]
        punctuation?.matches(in: source, range: fullRange).forEach {
            boundarySet.insert(NSMaxRange($0.range))
        }
        transitions?.matches(in: source, range: fullRange).forEach {
            if $0.range.location > 0 {
                boundarySet.insert($0.range.location)
            }
        }
        let boundaries = boundarySet.sorted()

        return zip(boundaries, boundaries.dropFirst()).compactMap { start, end in
            let sentence = text.substring(
                with: NSRange(location: start, length: end - start)
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            return sentence.isEmpty ? nil : sentence
        }
    }
}

enum PracticeWorksheetItem: Identifiable, Equatable, Sendable {
    case step(PracticeWorksheetStep)
    case note(PracticeWorksheetNote)

    var id: UUID {
        switch self {
        case .step(let step): step.id
        case .note(let note): note.id
        }
    }
}

struct PracticeWorksheet: Equatable, Sendable {
    let problem: String?
    let steps: [PracticeWorksheetStep]
    let notes: [PracticeWorksheetNote]
    let items: [PracticeWorksheetItem]
    let inspector: PracticeInspectorSnapshot
    let latestHint: TutorConversationEntry?
    let latestSolution: TutorConversationEntry?

    var showsInspector: Bool {
        inspector.verdict != nil || steps.contains { $0.feedback != nil }
    }

    init(problem: String?, entries: [TutorConversationEntry], isBusy: Bool = false) {
        self.problem = problem
        let built = Self.makeSteps(from: entries, isBusy: isBusy)
        self.steps = built
        self.items = Self.makeItems(from: entries, steps: built)
        self.notes = self.items.compactMap { item in
            if case .note(let note) = item { return note }
            return nil
        }
        self.latestHint = entries.last { $0.role == .tutor && $0.kind.wireName == "hint" }
        self.latestSolution = entries.last { $0.role == .tutor && $0.kind == .solution }
        self.inspector = Self.makeInspector(steps: built)
    }

    private static func makeSteps(from entries: [TutorConversationEntry], isBusy: Bool) -> [PracticeWorksheetStep] {
        var steps: [PracticeWorksheetStep] = []
        var focusID: UUID?
        for (index, entry) in entries.enumerated() {
            guard entry.role == .student, case .step(let number) = entry.kind else { continue }
            let following = index + 1 < entries.count ? entries[index + 1] : nil
            let feedback = following.flatMap { next -> TutorConversationEntry? in
                guard next.role == .tutor, next.kind == .message else { return nil }
                return next
            }
            let status: PracticeStepStatus
            if feedback?.assessment == "correct" {
                status = .correct
            } else if feedback?.assessment == "incorrect" {
                status = .incorrect
            } else if feedback == nil {
                status = isBusy || following == nil ? .pending : .unchecked
            } else {
                status = .unchecked
            }
            if status == .incorrect, focusID == nil {
                focusID = entry.id
            }
            steps.append(
                PracticeWorksheetStep(
                    id: entry.id,
                    number: number,
                    text: entry.text,
                    status: status,
                    diagnosis: status == .incorrect ? feedback?.text : nil,
                    feedback: feedback?.text,
                    summary: feedback?.summary,
                    errorCategory: feedback?.errorCategory,
                    verificationStatus: feedback?.verificationStatus,
                    sources: feedback?.sources ?? [],
                    isFocus: false
                )
            )
        }
        let focused = focusID ?? steps.last?.id
        return steps.map { step in
            PracticeWorksheetStep(
                id: step.id,
                number: step.number,
                text: step.text,
                status: step.status,
                diagnosis: step.diagnosis,
                feedback: step.feedback,
                summary: step.summary,
                errorCategory: step.errorCategory,
                verificationStatus: step.verificationStatus,
                sources: step.sources,
                isFocus: step.id == focused
            )
        }
    }

    private static func makeItems(
        from entries: [TutorConversationEntry],
        steps: [PracticeWorksheetStep]
    ) -> [PracticeWorksheetItem] {
        let stepsByID = Dictionary(uniqueKeysWithValues: steps.map { ($0.id, $0) })
        var items: [PracticeWorksheetItem] = []
        for (index, entry) in entries.enumerated() {
            if entry.role == .student {
                if case .problem = entry.kind { continue }
                if case .step = entry.kind, let step = stepsByID[entry.id] {
                    items.append(.step(step))
                    continue
                }
                if case .message = entry.kind {
                    items.append(.note(PracticeWorksheetNote(id: entry.id, title: "You", text: entry.text, emphasized: false)))
                }
                continue
            }
            switch entry.kind {
            case .hint:
                items.append(.note(PracticeWorksheetNote(id: entry.id, title: entry.kind.caption, text: entry.text, emphasized: false)))
            case .solution:
                items.append(.note(PracticeWorksheetNote(id: entry.id, title: "Solution", text: entry.text, emphasized: true)))
            case .message:
                let previous = index > 0 ? entries[index - 1] : nil
                if let previous, previous.role == .student, case .step = previous.kind {
                    continue
                }
                items.append(.note(PracticeWorksheetNote(id: entry.id, title: "Tutor", text: entry.text, emphasized: false)))
            case .problem, .step:
                continue
            }
        }
        return items
    }

    private static func makeInspector(
        steps: [PracticeWorksheetStep]
    ) -> PracticeInspectorSnapshot {
        let checked = steps.filter { $0.status == .correct || $0.status == .incorrect }
        let focus = steps.first(where: \.isFocus)
        let source = focus?.sources.first
        let hasCheck = focus?.feedback != nil || focus?.status == .pending
        return PracticeInspectorSnapshot(
            checkedCount: checked.count,
            totalCount: steps.count,
            verdict: hasCheck ? displayVerdict(focus) : nil,
            errorType: hasCheck ? displayErrorType(focus?.errorCategory) : nil,
            concept: hasCheck ? source?.title : nil,
            sourceTitle: hasCheck ? source?.title : nil,
            sourceSection: hasCheck ? source?.section : nil,
            note: hasCheck ? (focus?.summary ?? focus?.feedback) : nil,
            noteCaption: hasCheck ? displayNoteCaption(focus) : ""
        )
    }

    private static func displayVerdict(_ step: PracticeWorksheetStep?) -> String? {
        guard let step else { return nil }
        switch step.status {
        case .correct: return "Correct"
        case .incorrect: return "Incorrect"
        case .pending: return "Checking"
        case .unchecked: return step.feedback == nil ? nil : "Not graded"
        }
    }

    private static func displayNoteCaption(_ step: PracticeWorksheetStep?) -> String {
        switch step?.status {
        case .incorrect: return "First break"
        case .correct: return "Check"
        case .pending: return "Check"
        case .unchecked: return "Check"
        case nil: return ""
        }
    }

    private static func displayErrorType(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        return raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

extension TutorSessionStore {
    var worksheet: PracticeWorksheet {
        PracticeWorksheet(problem: problem, entries: entries, isBusy: isBusy)
    }
}

struct PendingMathTranscription: Equatable, Sendable, Codable {
    enum Purpose: Sendable, Codable {
        case problem
        case step
    }

    let purpose: Purpose
    let note: String
    var text: String
    let filename: String
}

struct TutorSessionSnapshot: Codable {
    let sessionID: String
    let problem: String?
    let attemptSteps: [String]
    let entries: [TutorConversationEntry]
    let composerDraft: String
    let composerAttachment: MessageAttachment?
    let pendingTranscription: PendingMathTranscription?
    let nextHintLevel: Int?
    let solutionRevealed: Bool
}

@MainActor
@Observable
final class TutorSessionStore {
    private let client: any TutorClient
    private let sessionID: String
    var minimumResponseDelay: Duration
    @ObservationIgnored var onStateChanged: (@MainActor () -> Void)?
    var composerDraft = "" { didSet { onStateChanged?() } }
    var composerAttachment: MessageAttachment? { didSet { onStateChanged?() } }

    private(set) var problem: String? { didSet { onStateChanged?() } }
    private(set) var attemptSteps: [String] = [] { didSet { onStateChanged?() } }
    private(set) var entries: [TutorConversationEntry] = [] { didSet { onStateChanged?() } }
    private(set) var pendingTranscription: PendingMathTranscription? { didSet { onStateChanged?() } }
    private(set) var nextHintLevel: Int? = 1 { didSet { onStateChanged?() } }
    private(set) var solutionRevealed = false { didSet { onStateChanged?() } }
    private(set) var isBusy = false
    private(set) var errorMessage: String?

    var canRevealSolution: Bool {
        problem != nil && !solutionRevealed && pendingTranscription == nil
    }

    var usedHintCount: Int {
        if solutionRevealed { return 3 }
        guard let nextHintLevel else { return 0 }
        return max(0, nextHintLevel - 1)
    }

    var nextGuidance: String? {
        guard problem != nil, pendingTranscription == nil, !isBusy else { return nil }
        if solutionRevealed {
            return "Try a nearby problem, or start a new one."
        }
        if entries.last?.assessment == "incorrect" {
            return "That step didn’t check. Fix it, or take a hint."
        }
        if entries.last?.assessment == "correct" {
            return "Write the next derivative term and check it."
        }
        return "Ask a question, or check a written step."
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

    convenience init(client: any TutorClient, snapshot: TutorSessionSnapshot) {
        self.init(client: client, sessionID: snapshot.sessionID)
        problem = snapshot.problem
        attemptSteps = snapshot.attemptSteps
        entries = snapshot.entries
        composerDraft = snapshot.composerDraft
        composerAttachment = snapshot.composerAttachment
        pendingTranscription = snapshot.pendingTranscription
        nextHintLevel = snapshot.nextHintLevel
        solutionRevealed = snapshot.solutionRevealed
    }

    var snapshot: TutorSessionSnapshot {
        TutorSessionSnapshot(sessionID: sessionID, problem: problem, attemptSteps: attemptSteps,
                             entries: entries, composerDraft: composerDraft,
                             composerAttachment: composerAttachment,
                             pendingTranscription: pendingTranscription,
                             nextHintLevel: nextHintLevel, solutionRevealed: solutionRevealed)
    }

    @discardableResult
    func submit(
        _ text: String,
        attachment: MessageAttachment? = nil,
        intent: TutorSubmitIntent = .automatic
    ) async -> Bool {
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
            return await sendConversation(trimmed, userLabel: trimmed, studentKind: .problem)
        }
        switch intent {
        case .ask:
            return await sendConversation(trimmed, userLabel: trimmed, studentKind: .message)
        case .check:
            return await submitStep(trimmed)
        case .automatic:
            if TutorMessageKind.looksLikeMathStep(trimmed) {
                return await submitStep(trimmed)
            }
            return await sendConversation(trimmed, userLabel: trimmed, studentKind: .message)
        }
    }

    @discardableResult
    func beginProblem(_ prompt: String) async -> Bool {
        reset()
        return await submit(prompt, intent: .ask)
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
            return await sendConversation(combined, userLabel: combined, studentKind: .problem)
        case .step:
            let didSend = TutorMessageKind.looksLikeMathStep(combined)
                ? await submitStep(combined)
                : await sendConversation(combined, userLabel: combined, studentKind: .message)
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
        composerDraft = ""
        composerAttachment = nil
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
            conversation: transcript(),
            action: .checkStep,
            hintLevel: 0,
            solutionRevealed: false
        )
        return await send(
            request,
            userLabel: step,
            proposedSteps: proposedSteps,
            recordStudent: true,
            recordAttempt: true,
            studentKind: .step(proposedSteps.count)
        )
    }

    private func sendConversation(_ message: String, userLabel: String, studentKind: TutorTurnKind) async -> Bool {
        guard let problem else { return false }
        let request = TutorTurnRequest(
            sessionID: sessionID,
            problem: problem,
            attemptSteps: message == problem ? [] : [message],
            conversation: transcript(),
            action: .chat,
            hintLevel: 0,
            solutionRevealed: false
        )
        return await send(
            request,
            userLabel: userLabel,
            proposedSteps: attemptSteps,
            recordStudent: true,
            recordAttempt: false,
            studentKind: studentKind
        )
    }

    private func perform(action: TutorAction, hintLevel: Int, recordStudent: Bool) async -> Bool {
        guard let problem else { return false }
        let request = TutorTurnRequest(
            sessionID: sessionID,
            problem: problem,
            attemptSteps: attemptSteps,
            conversation: transcript(),
            action: action,
            hintLevel: hintLevel,
            solutionRevealed: action == .revealSolution
        )
        return await send(
            request,
            userLabel: "",
            proposedSteps: attemptSteps,
            recordStudent: recordStudent,
            recordAttempt: false,
            studentKind: .message
        )
    }

    private func send(
        _ request: TutorTurnRequest,
        userLabel: String,
        proposedSteps: [String],
        recordStudent: Bool,
        recordAttempt: Bool,
        studentKind: TutorTurnKind
    ) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        if recordStudent {
            entries.append(TutorConversationEntry(role: .student, text: userLabel, kind: studentKind))
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
                    sources: response.sources,
                    summary: response.summary
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

    private func transcript() -> [TutorConversationTurn] {
        entries.suffix(12).map { entry in
            TutorConversationTurn(
                role: entry.role == .student ? "student" : "tutor",
                text: entry.text,
                kind: entry.kind.wireName
            )
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

struct CourseProblem: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    var prompt: String
    var openedInPractice: Bool
    let sources: [TutorSource]
    var groupID: UUID?
    var doneAttemptID: UUID? = nil
    var topicID: UUID? = nil

    init(
        id: UUID = UUID(),
        prompt: String,
        openedInPractice: Bool = false,
        sources: [TutorSource] = [],
        groupID: UUID? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.openedInPractice = openedInPractice
        self.sources = sources
        self.groupID = groupID
    }
}

struct ProblemGroup: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    var title: String
    var sourceTitle: String?

    init(id: UUID = UUID(), title: String, sourceTitle: String? = nil) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
    }
}

@MainActor
@Observable
final class ProblemSetStore {
    private(set) var items: [CourseProblem] = []
    private(set) var groups: [ProblemGroup] = []
    @ObservationIgnored private let storageURL: URL?

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL
        if let storageURL, let data = try? Data(contentsOf: storageURL),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            items = snapshot.items
            groups = snapshot.groups
        }
    }

    private struct Snapshot: Codable {
        let items: [CourseProblem]
        let groups: [ProblemGroup]
    }

    private func persist() {
        guard let storageURL,
              let data = try? JSONEncoder().encode(Snapshot(items: items, groups: groups)) else { return }
        try? FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: storageURL, options: .atomic)
    }

    @discardableResult
    func add(_ prompt: String, sources: [TutorSource] = [], groupID: UUID? = nil) -> CourseProblem? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard groupID == nil || groups.contains(where: { $0.id == groupID }) else { return nil }
        let item = CourseProblem(prompt: trimmed, sources: sources, groupID: groupID)
        items.insert(item, at: 0)
        persist()
        return item
    }

    /// Saving reviewed questions creates/reuses a folder for each source document.
    /// Importing a document alone never creates problems or folders.
    @discardableResult
    func addGenerated(_ generated: [GeneratedCourseProblem]) -> Int {
        var saved = 0
        for problem in generated.reversed() {
            let prompt = problem.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty else { continue }
            let sourceIDs = Set(problem.sources.map(\.sourceID))
            if items.contains(where: {
                $0.prompt.localizedCaseInsensitiveCompare(prompt) == .orderedSame
                    && Set($0.sources.map(\.sourceID)) == sourceIDs
            }) { continue }
            let titles = Set(problem.sources.map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
            let folderTitle = titles.count == 1 ? titles.first : (titles.isEmpty ? nil : "Mixed Course Sources")
            let groupID = folderTitle.flatMap(folderID(for:))
            if add(prompt, sources: problem.sources, groupID: groupID) != nil {
                saved += 1
            }
        }
        return saved
    }

    func linkTopic(_ id: UUID, topicID: UUID?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].topicID = topicID
        persist()
    }

    func detachTopics(except ids: Set<UUID>) {
        for i in items.indices where items[i].topicID.map({ !ids.contains($0) }) == true { items[i].topicID = nil }
        persist()
    }

    private func folderID(for sourceTitle: String) -> UUID? {
        let sourceTitle = sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceTitle.isEmpty else { return nil }
        if let existing = groups.first(where: {
            $0.sourceTitle?.localizedCaseInsensitiveCompare(sourceTitle) == .orderedSame
        }) {
            return existing.id
        }

        let title = Self.folderTitle(for: sourceTitle)
        if let index = groups.firstIndex(where: {
            $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame && $0.sourceTitle == nil
        }) {
            groups[index].sourceTitle = sourceTitle
            return groups[index].id
        }

        let group = ProblemGroup(title: title, sourceTitle: sourceTitle)
        groups.append(group)
        persist()
        return group.id
    }

    private static func folderTitle(for filename: String) -> String {
        let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let words = stem.components(separatedBy: CharacterSet(charactersIn: "_- "))
            .filter { !$0.isEmpty }
            .flatMap { word -> [String] in
                let lower = word.lowercased()
                if lower == "prac" || lower == "pract" { return ["Practice"] }
                if lower.count > 1, lower.first == "a", lower.dropFirst().allSatisfy(\.isNumber) {
                    return ["Assignment", String(lower.dropFirst())]
                }
                return [word == lower ? word.capitalized : word]
            }
        return words.joined(separator: " ")
    }

    @discardableResult
    func addGroup(_ title: String) -> ProblemGroup? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let group = ProblemGroup(title: trimmed)
        groups.append(group)
        persist()
        return group
    }

    @discardableResult
    func renameGroup(_ id: UUID, to title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = groups.firstIndex(where: { $0.id == id }) else { return false }
        groups[index].title = trimmed
        persist()
        return true
    }

    @discardableResult
    func removeGroup(_ id: UUID) -> Bool {
        guard groups.contains(where: { $0.id == id }) else { return false }
        groups.removeAll { $0.id == id }
        for index in items.indices where items[index].groupID == id {
            items[index].groupID = nil
        }
        persist()
        return true
    }

    @discardableResult
    func update(_ id: UUID, prompt: String) -> Bool {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = items.firstIndex(where: { $0.id == id }) else { return false }
        items[index].prompt = trimmed
        persist()
        return true
    }

    @discardableResult
    func move(_ id: UUID, to groupID: UUID?) -> Bool {
        guard groupID == nil || groups.contains(where: { $0.id == groupID }),
              let index = items.firstIndex(where: { $0.id == id }) else { return false }
        items[index].groupID = groupID
        persist()
        return true
    }

    @discardableResult
    func remove(_ id: UUID) -> Bool {
        let previousCount = items.count
        items.removeAll { $0.id == id }
        persist()
        return items.count != previousCount
    }

    func markOpened(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].openedInPractice = true
        persist()
    }

    func markDone(_ id: UUID, attemptID: UUID?, done: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].doneAttemptID = done ? attemptID : nil
        persist()
    }
}
