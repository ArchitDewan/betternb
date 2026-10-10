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
    @Test @MainActor
    func studyThreadsKeepIndependentSessionsAndThreeRecentShortcuts() async {
        let client = RecordingTutorClient()
        let threads = StudyThreadStore()
        let firstTutor = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        let first = threads.startPractice(
            prompt: #"Determine whether \(\lim_{z\to0}\overline z/z\) exists."#,
            tutor: firstTutor
        )
        #expect(await firstTutor.beginProblem(#"Determine whether \(\lim_{z\to0}\overline z/z\) exists."#))
        firstTutor.composerDraft = "I think the limit depends on direction"

        for prompt in ["Find all fourth roots of i", "Differentiate x^2", "Integrate x^2"] {
            _ = threads.startPractice(prompt: prompt, tutor: TutorSessionStore(client: client))
        }

        #expect(threads.all.count == 4)
        #expect(threads.recent.count == 3)
        #expect(!threads.recent.contains { $0.id == first })
        let originalOrder = threads.all.map(\.id)
        #expect(threads.activate(first) == .practice)
        #expect(threads.activeTutor === firstTutor)
        #expect(firstTutor.entries.count == 2)
        #expect(firstTutor.composerDraft == "I think the limit depends on direction")
        #expect(threads.all.map(\.id) == originalOrder)
        #expect(threads.recent.map(\.id) == Array(originalOrder.prefix(3)))
        #expect(threads.all.last?.title == "Complex limit at z → 0")
        #expect(threads.recent.map(\.title) == ["Integrate x²", "Differentiate x²", "Fourth roots of i"])
    }

    @Test @MainActor
    func courseQuestionThreadRemainsSeparateFromPractice() async {
        let threads = StudyThreadStore()
        let conversation = WorkspaceConversationStore(repository: InMemoryChannelMessageRepository())
        let courseID = threads.startCourse(question: "Explain the chain rule", conversations: conversation)
        #expect(await conversation.send("Explain the chain rule", in: .study))
        _ = threads.startPractice(prompt: "Differentiate x^2", tutor: TutorSessionStore(client: RecordingTutorClient()))

        #expect(threads.activate(courseID) == .courseQuestion)
        #expect(threads.activeConversations === conversation)
        #expect(conversation.messages(in: .study).count == 1)
        #expect(threads.recent.first?.title == "Differentiate x²")
        #expect(threads.all.last?.title == "Explain the chain rule")
    }

    @Test
    func studyThreadTitlesUseQuestionDetailsInsteadOfGenericCategories() {
        #expect(StudyThreadTitle.forPrompt("5 * 5", kind: .practice) == "5 × 5")
        #expect(StudyThreadTitle.forPrompt("Solve 2x + 3 = 9", kind: .practice) == "Solve 2x + 3 = 9")
        #expect(StudyThreadTitle.forPrompt("Image problem", kind: .practice) == "Problem from image")
        #expect(StudyThreadTitle.forPrompt(
            "Let S be a complex region. Find and sketch the image of S under w=z^3.",
            kind: .practice
        ) == "Image of S under w = z³")
        let longQuestion = "Determine whether the image of a region under a complex mapping is open or closed. Justify your answer."
        let title = StudyThreadTitle.forPrompt(longQuestion, kind: .practice)
        #expect(title.count <= 48)
        #expect(title.contains("image of a region"))
        #expect(!title.contains("Practice problem"))
    }

    @Test @MainActor
    func lateTutorReplyStaysWithTheThreadThatStartedIt() async {
        let client = GatedTutorClient()
        let threads = StudyThreadStore()
        let firstTutor = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        let firstID = threads.startPractice(prompt: "Differentiate x^2", tutor: firstTutor)
        let firstRequest = Task { await firstTutor.beginProblem("Differentiate x^2") }
        await client.waitUntilSendStarts()

        let secondTutor = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        let secondID = threads.startPractice(prompt: "Integrate x^2", tutor: secondTutor)
        #expect(threads.activeID == secondID)
        await client.release()
        #expect(await firstRequest.value)
        #expect(firstTutor.entries.count == 2)
        #expect(secondTutor.entries.isEmpty)
        #expect(threads.activate(firstID) == .practice)
        #expect(threads.activeTutor === firstTutor)
    }

    @Test
    func revealedSolutionSeparatesNumberedStepsAndRepairsBareBoxedAnswer() {
        let layout = RevealedSolutionLayout(
            "Your equation is correct. Step 1. Rewrite the fraction. "
                + "Step 2: Differentiate both sides. boxed{f'(99)\\cdot f'(99)=99}"
        )

        #expect(layout.introduction == "Your equation is correct.")
        #expect(layout.steps.map(\.number) == [1, 2])
        #expect(layout.steps[0].text == "Rewrite the fraction.")
        #expect(layout.steps[1].text.contains(#"\boxed{f'(99)\cdot f'(99)=99}"#))
    }

    @Test
    func revealedSolutionWithoutNumberedStepsRemainsReadable() {
        let layout = RevealedSolutionLayout("Use the power rule, then simplify.")

        #expect(layout.introduction == "Use the power rule, then simplify.")
        #expect(layout.steps.isEmpty)
    }

    @Test
    func revealedSolutionBuildsStepsWhenProviderReturnsSeveralSentences() {
        let layout = RevealedSolutionLayout(
            "Start with f(x) = x^2. Apply the power rule. Therefore boxed{f'(x)=2x}."
        )

        #expect(layout.introduction == nil)
        #expect(layout.steps.map(\.number) == [1, 2, 3])
        #expect(layout.steps[2].text == #"Therefore \boxed{f'(x)=2x}."#)
        #expect(layout.steps[2].boxedAnswer == "f'(x)=2x")
        #expect(layout.steps[2].textWithoutBoxedAnswer == "Therefore.")
    }

    @Test
    func revealedSolutionUsesMathTransitionsWhenEquationPunctuationIsMissing() {
        let layout = RevealedSolutionLayout(
            "Use the power rule: \\frac{d}{dx}x^n=nx^{n-1} "
                + "For your function, f(x)=x^2 The exponent is 2, so f'(x)=2x^{2-1} "
                + "Subtract one from the exponent. Since x^1=x, boxed{f'(x)=2x}"
        )

        #expect(layout.steps.count == 5)
        #expect(layout.steps[1].text.hasPrefix("For your function"))
        #expect(layout.steps[4].text.contains(#"\boxed{f'(x)=2x}"#))
    }

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
        #expect(!TutorMessageKind.looksLikeMathStep("what should I do next?"))
        #expect(TutorMessageKind.looksLikeMathStep("f'(x) = 14x + 4"))
        #expect(TutorMessageKind.looksLikeMathStep("dy/dx = 2x"))
        #expect(TutorMessageKind.looksLikeMathStep("u = cos 2x"))
        #expect(TutorMessageKind.looksLikeMathStep(#"u = \cos x"#))
        #expect(TutorMessageKind.looksLikeMathStep(#"\int \sin 2x / \cos^2 2x \, dx"#))
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
        let sheet = store.worksheet
        #expect(sheet.notes.contains { $0.title == "Tutor" && $0.text == "The inner derivative is missing." })
        #expect(sheet.inspector.note == nil)
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
        #expect(store.worksheet.notes.contains { $0.title == "You" && $0.text.contains("individually") })
        #expect(store.worksheet.notes.contains { $0.title == "Tutor" })
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
    func sendAutoChecksALatexLineAndKeepsAQuestionAsChat() async {
        let client = RecordingTutorClient()
        let store = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        #expect(await store.submit(#"\int \sin 2x / \cos^2 2x \, dx"#))
        #expect(await store.submit("u = \\cos 2x"))
        #expect(await store.submit("what should I do next?"))

        let requests = await client.recordedRequests()
        #expect(requests.map(\.action) == [.chat, .checkStep, .chat])
        #expect(store.worksheet.steps.count == 1)
        #expect(store.worksheet.notes.contains { $0.title == "You" && $0.text.contains("next") })
    }

    @Test @MainActor
    func inspectorUsesTheShortSummaryAndTheStepKeepsTheLongNote() async {
        let client = RecordingTutorClient()
        await client.setResponse(TutorTurnResponse(
            capability: "calculus.derivatives",
            assessment: "incorrect",
            message: "The minus sign was applied a second time when you changed bounds. Keep du = -sin x dx and flip the limits once.",
            summary: "The sign was counted twice when changing bounds.",
            errorCategory: "procedural",
            verificationStatus: .modelJudged,
            sources: [TutorSource(sourceID: "calc.integrals.u-sub", title: "u-substitution", section: "Definite bounds")],
            actionAccepted: true,
            nextHintLevel: 1,
            nextAction: "request_hint"
        ))
        let store = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        #expect(await store.submit("Differentiate f(x) = x^2"))
        #expect(await store.submit("u = \\cos x"))

        let sheet = store.worksheet
        #expect(sheet.steps[0].feedback?.contains("minus sign") == true)
        #expect(sheet.inspector.note == "The sign was counted twice when changing bounds.")
        #expect(sheet.inspector.verdict == "Incorrect")
        #expect(sheet.inspector.errorType == "Procedural")
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

    @Test @MainActor
    func savedProblemResumesItsAttemptAfterReload() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lemma-attempts-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let client = RecordingTutorClient()
        let problemID = UUID()
        let threads = StudyThreadStore(storageURL: url, tutorClient: client)
        let tutor = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        let id = threads.startPractice(prompt: "Differentiate x squared", tutor: tutor, problemID: problemID)
        #expect(await tutor.beginProblem("Differentiate x squared"))
        #expect(await tutor.submit("2x", intent: .check))

        let restored = StudyThreadStore(storageURL: url, tutorClient: client)
        #expect(restored.latestPractice(for: problemID) == id)
        #expect(restored.activate(id) == .practice)
        #expect(restored.activeTutor?.problem == "Differentiate x squared")
        #expect(restored.activeTutor?.entries.contains { $0.text == "2x" } == true)
    }

    @Test @MainActor
    func worksheetMapsCheckedStepsAndInspectorFromTutorFeedback() async {
        let client = RecordingTutorClient()
        let store = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        #expect(await store.submit("Differentiate f(x) = (x^2 + 1)^3"))
        #expect(await store.submit("f'(x) = 3*(x^2 + 1)^2", intent: .check))

        let sheet = store.worksheet
        #expect(sheet.problem == "Differentiate f(x) = (x^2 + 1)^3")
        #expect(sheet.steps.count == 1)
        #expect(sheet.steps[0].number == 1)
        #expect(sheet.steps[0].status == .incorrect)
        #expect(sheet.steps[0].isFocus)
        #expect(sheet.steps[0].diagnosis == "The inner derivative is missing.")
        #expect(sheet.steps[0].errorCategory == "conceptual")
        #expect(sheet.inspector.checkedCount == 1)
        #expect(sheet.inspector.totalCount == 1)
        #expect(sheet.inspector.verdict == "Incorrect")
        #expect(sheet.inspector.errorType == "Conceptual")
        #expect(sheet.inspector.sourceTitle == "Chain rule")
        #expect(sheet.inspector.sourceSection == "Method")
        #expect(sheet.inspector.note == "The inner derivative is missing.")
        #expect(sheet.inspector.noteCaption == "First break")
        #expect(sheet.showsInspector)
    }

    @Test @MainActor
    func inspectorStaysEmptyUntilAStepIsChecked() async {
        let client = RecordingTutorClient()
        let store = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        #expect(await store.submit("Differentiate f(x) = (x^2 + 1)^3"))

        let sheet = store.worksheet
        #expect(sheet.steps.isEmpty)
        #expect(sheet.inspector.checkedCount == 0)
        #expect(sheet.inspector.totalCount == 0)
        #expect(sheet.inspector.verdict == nil)
        #expect(sheet.inspector.note == nil)
        #expect(sheet.inspector.errorType == nil)
        #expect(!sheet.showsInspector)
    }

    @Test @MainActor
    func worksheetKeepsHintAndSolutionOffTheStepList() async {
        let client = RecordingTutorClient()
        await client.setResponse(TutorTurnResponse(
            capability: "calculus.derivatives",
            assessment: "correct",
            message: "That term is right.",
            errorCategory: nil,
            verificationStatus: .verified,
            sources: [TutorSource(sourceID: "calc.derivatives.power-rule", title: "Power rule", section: "Method")],
            actionAccepted: true,
            nextHintLevel: 1,
            nextAction: "request_hint"
        ))
        let store = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        #expect(await store.submit("Differentiate f(x) = x^2"))
        #expect(await store.submit("f'(x) = 2*x", intent: .check))
        #expect(await store.requestHint())
        #expect(await store.revealSolution())

        let sheet = store.worksheet
        #expect(sheet.steps.map(\.status) == [.correct])
        #expect(sheet.steps[0].diagnosis == nil)
        #expect(sheet.steps[0].feedback == "That term is right.")
        #expect(sheet.latestHint != nil)
        #expect(sheet.latestSolution != nil)
        #expect(sheet.inspector.verdict == "Correct")
        #expect(sheet.inspector.note == "That term is right.")
        #expect(sheet.inspector.noteCaption == "Check")
        #expect(sheet.inspector.sourceTitle == "Power rule")
    }

    @Test @MainActor
    func inspectorKeepsTheCheckAfterAHintAndShowsUngradedChecks() async {
        let client = RecordingTutorClient()
        await client.setResponse(TutorTurnResponse(
            capability: "calculus.derivatives",
            assessment: "not_assessed",
            message: "Write the substitution as an equation first.",
            errorCategory: nil,
            verificationStatus: .inconclusive,
            sources: [],
            actionAccepted: true,
            nextHintLevel: 1,
            nextAction: "request_hint"
        ))
        let store = TutorSessionStore(client: client, minimumResponseDelay: .zero)
        #expect(await store.submit(#"\int \sin 2x / \cos^2 2x dx"#))
        #expect(await store.submit("u = cos 2x", intent: .check))

        var sheet = store.worksheet
        #expect(sheet.steps[0].status == .unchecked)
        #expect(sheet.steps[0].feedback == "Write the substitution as an equation first.")
        #expect(sheet.inspector.verdict == "Not graded")
        #expect(sheet.inspector.note == "Write the substitution as an equation first.")
        #expect(sheet.inspector.checkedCount == 0)
        #expect(sheet.inspector.totalCount == 1)

        #expect(await store.requestHint())
        sheet = store.worksheet
        #expect(sheet.latestHint != nil)
        #expect(sheet.inspector.note == "Write the substitution as an equation first.")
        #expect(sheet.inspector.verdict == "Not graded")
        #expect(sheet.inspector.noteCaption != "Hint 1")
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

    func setResponse(_ value: TutorTurnResponse) {
        response = value
    }
}
