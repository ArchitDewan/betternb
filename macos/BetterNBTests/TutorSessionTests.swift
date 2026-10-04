import Foundation
import Testing
@testable import BetterNB

private actor RecordingTutorClient: TutorClient {
    enum Failure: Error { case unavailable }

    var transcription = "Differentiate f(x) = (x^2 + 1)^3"
    var response = TutorTurnResponse(
        capability: "calculus.derivatives",
        assessment: "incorrect",
        message: "The inner derivative is missing.",
        errorCategory: "conceptual",
        verificationStatus: .verified,
        sources: [TutorSource(sourceID: "calc.derivatives.chain-rule.method", title: "Chain rule", section: "Method")],
        actionAccepted: true,
        nextHintLevel: 1,
        nextAction: "request_hint"
    )
    var shouldFail = false
    private(set) var requests: [TutorTurnRequest] = []

    func transcribe(_ attachment: MessageAttachment) async throws -> String {
        if shouldFail { throw Failure.unavailable }
        return transcription
    }

    func send(_ request: TutorTurnRequest) async throws -> TutorTurnResponse {
        if shouldFail { throw Failure.unavailable }
        requests.append(request)
        return response
    }

    func recordedRequests() -> [TutorTurnRequest] { requests }
}

struct TutorSessionTests {
    @Test
    func tutorTurnsLabelHintsAndRevealedSolutions() {
        #expect(TutorTurnKind.problem.caption == "Problem")
        #expect(TutorTurnKind.message.caption.isEmpty)
        #expect(TutorTurnKind.step(1).caption == "Step 1")
        #expect(TutorTurnKind.hint(2).caption == "Hint 2")
        #expect(TutorTurnKind.solution.caption == "Solution")
    }

    @Test
    func onlyWrittenDerivativesCountAsCheckableSteps() {
        #expect(!TutorMessageKind.looksLikeMathStep("can you help me differentiate 7x^2 + 4x?"))
        #expect(!TutorMessageKind.looksLikeMathStep("hmmm i think i take derivatives individually?"))
        #expect(TutorMessageKind.looksLikeMathStep("f'(x) = 14x + 4"))
        #expect(TutorMessageKind.looksLikeMathStep("dy/dx = 2x"))
    }

    @Test @MainActor
    func openingMessageStartsAConversationInsteadOfASilentHeader() async {
        let client = RecordingTutorClient()
        let store = TutorSessionStore(client: client, minimumResponseDelay: .zero)

        #expect(await store.submit("can you help me differentiate 7x^2 + 4x?"))
        #expect(store.problem == "can you help me differentiate 7x^2 + 4x?")
        #expect(store.entries.first?.role == .student)
        #expect(store.entries.first?.text == "can you help me differentiate 7x^2 + 4x?")
        #expect(store.entries.last?.role == .tutor)
        let requests = await client.recordedRequests()
        #expect(requests.map(\.action) == [.chat])
        #expect(requests[0].attemptSteps.isEmpty)
    }

    @Test @MainActor
    func informalFollowUpIsConversationAndWrittenDerivativeIsChecked() async {
        let client = RecordingTutorClient()
        let store = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        #expect(await store.submit("can you help me differentiate 7x^2 + 4x?"))
        #expect(await store.submit("hmmm i think i take derivatives individually?"))
        #expect(await store.submit("f'(x) = 14x + 4"))

        #expect(store.attemptSteps == ["f'(x) = 14x + 4"])
        let requests = await client.recordedRequests()
        #expect(requests.map(\.action) == [.chat, .chat, .checkStep])
        #expect(requests[1].attemptSteps == ["hmmm i think i take derivatives individually?"])
        #expect(store.entries.last?.verificationStatus == .verified)
    }

    @Test @MainActor
    func studentMessageAppearsBeforeTheTutorReply() async {
        let client = GatedTutorClient()
        let store = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        let task = Task { await store.submit("can you help me differentiate 7x^2 + 4x?") }

        await client.waitUntilSendStarts()
        #expect(store.isBusy)
        #expect(store.entries.map(\.role) == [.student])
        await client.release()
        #expect(await task.value)
        #expect(store.entries.map(\.role) == [.student, .tutor])
        #expect(!store.isBusy)
    }

    @Test @MainActor
    func imageProblemRequiresEditableConfirmation() async throws {
        let client = RecordingTutorClient()
        let store = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        let image = try MessageAttachment(
            filename: "problem.png",
            mediaType: "image/png",
            data: Data([0x89, 0x50, 0x4E, 0x47])
        )

        #expect(await store.submit("Use the chain rule", attachment: image))
        #expect(store.problem == nil)
        #expect(store.pendingTranscription?.text == "Differentiate f(x) = (x^2 + 1)^3")

        store.updatePendingTranscription("Differentiate f(x) = (x^2 + 2)^3")
        #expect(await store.confirmTranscription())
        #expect(store.problem == "Use the chain rule\nDifferentiate f(x) = (x^2 + 2)^3")
        #expect(store.entries.contains { $0.role == .tutor })
    }

    @Test @MainActor
    func checkedStepPreservesVerificationAndSources() async {
        let client = RecordingTutorClient()
        let store = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        #expect(await store.submit("Differentiate f(x) = (x^2 + 1)^3"))

        #expect(await store.submit("f'(x) = 3*(x^2 + 1)^2"))

        #expect(store.entries.last?.verificationStatus == .verified)
        #expect(store.entries.last?.sources.first?.title == "Chain rule")
        let requests = await client.recordedRequests()
        #expect(requests.map(\.action) == [.chat, .checkStep])
        #expect(requests.last?.attemptSteps == ["f'(x) = 3*(x^2 + 1)^2"])
    }

    @Test @MainActor
    func hintAndRevealAreExplicitActions() async {
        let client = RecordingTutorClient()
        let store = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        #expect(await store.submit("Differentiate f(x) = x^2"))
        #expect(await store.submit("f'(x) = x"))

        #expect(store.canRevealSolution)
        #expect(await store.requestHint())
        #expect(await store.revealSolution())

        let requests = await client.recordedRequests()
        #expect(requests.map(\.action) == [.chat, .checkStep, .requestHint, .revealSolution])
        #expect(requests[2].hintLevel == 1)
        #expect(requests[3].solutionRevealed)
        #expect(!store.canRevealSolution)
        #expect(await !store.revealSolution())
        #expect(store.entries.map(\.role) == [.student, .tutor, .student, .tutor, .tutor, .tutor])
        #expect(store.entries.map(\.kind) == [.problem, .message, .step(1), .message, .hint(1), .solution])
    }

    @Test @MainActor
    func serviceFailureDoesNotAppendTheStudentStep() async {
        let client = RecordingTutorClient()
        let store = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        #expect(await store.submit("Differentiate f(x) = x^2"))
        await client.setFailure(true)

        #expect(await !store.submit("f'(x) = 2*x"))
        #expect(store.attemptSteps.isEmpty)
        #expect(store.entries.contains { $0.role == .student && $0.text == "f'(x) = 2*x" })
        #expect(store.entries.last?.role == .student)
        #expect(store.errorMessage == "The tutor couldn’t respond. Your work is still here.")
    }

    @Test @MainActor
    func askIntentStaysConversationAndCheckIntentForcesAStep() async {
        let client = RecordingTutorClient()
        let store = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        #expect(await store.submit("Differentiate f(x) = x^2"))
        #expect(await store.submit("f'(x) = 2x", intent: .ask))
        #expect(await store.submit("I rewrote the first term", intent: .check))

        let requests = await client.recordedRequests()
        #expect(requests.map(\.action) == [.chat, .chat, .checkStep])
        #expect(!requests[1].conversation.isEmpty)
        #expect(store.entries.map(\.kind) == [.problem, .message, .message, .message, .step(1), .message])
    }

    @Test @MainActor
    func problemSetOpensInPracticeAsTheCurrentProblem() async {
        let client = RecordingTutorClient()
        let tutor = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        let problems = ProblemSetStore()
        let added = problems.add("Differentiate f(x) = x^2")
        #expect(added?.prompt == "Differentiate f(x) = x^2")
        #expect(await tutor.beginProblem(added!.prompt))
        problems.markOpened(added!.id)
        #expect(tutor.problem == "Differentiate f(x) = x^2")
        #expect(tutor.entries.first?.kind == .problem)
        #expect(problems.items.first?.openedInPractice == true)
    }
}

private actor GatedTutorClient: TutorClient {
    private var started = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []
    private var released = false

    func transcribe(_ attachment: MessageAttachment) async throws -> String {
        "Differentiate f(x) = x^2"
    }

    func send(_ request: TutorTurnRequest) async throws -> TutorTurnResponse {
        started = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        if !released {
            await withCheckedContinuation { releaseWaiters.append($0) }
        }
        return TutorTurnResponse(
            capability: "calculus.derivatives",
            assessment: "not_assessed",
            message: "Let’s start with the first term.",
            errorCategory: nil,
            verificationStatus: .inconclusive,
            sources: [],
            actionAccepted: true,
            nextHintLevel: 1,
            nextAction: "request_hint"
        )
    }

    func waitUntilSendStarts() async {
        if started { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func release() {
        released = true
        releaseWaiters.forEach { $0.resume() }
        releaseWaiters.removeAll()
    }
}

private extension RecordingTutorClient {
    func setFailure(_ value: Bool) {
        shouldFail = value
    }
}
