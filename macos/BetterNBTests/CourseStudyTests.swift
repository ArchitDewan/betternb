import Foundation
import Testing
@testable import BetterNB

@Suite("Course study sources")
struct CourseStudyTests {
    @Test @MainActor
    func importedPDFUpdatesCourseSources() async throws {
        let client = RecordingCourseStudyClient()
        let store = CourseSourceStore(courseID: "calculus-1", client: client)
        let pdf = try MessageAttachment(
            filename: "Lecture 4.pdf",
            mediaType: "application/pdf",
            data: Data("%PDF-1.4".utf8)
        )

        #expect(await store.importPDF(pdf))

        #expect(store.sources.map(\.filename) == ["Lecture 4.pdf"])
        #expect(store.sources.first?.pageCount == 4)
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func textbookReadsAnIndexedSourceDocument() async throws {
        let store = CourseSourceStore(courseID: "calculus-1", client: RecordingCourseStudyClient())

        let document = try await store.document(for: "source-1")

        #expect(document.starts(with: Data("%PDF".utf8)))
    }

    @Test @MainActor
    func groundedAnswerKeepsPageCitationsOnConversationReply() async {
        let client = RecordingCourseStudyClient()
        let answer = try! await client.answerCourseQuestion("What is the chain rule?", courseID: "calculus-1")
        let conversations = WorkspaceConversationStore(repository: InMemoryChannelMessageRepository())

        conversations.appendTutorReply(answer.answer, sources: answer.sources, in: .study)

        let reply = conversations.messages(in: .study).last
        #expect(reply?.role == .tutor)
        #expect(reply?.sources.first?.title == "Lecture 4.pdf")
        #expect(reply?.sources.first?.section == "Page 3")
    }

    @Test @MainActor
    func generatedProblemsCanPopulateTheProblemSet() async {
        let client = RecordingCourseStudyClient()
        let store = CourseSourceStore(courseID: "calculus-1", client: client)
        let problemSet = ProblemSetStore()

        let generated = await store.generateProblems(count: 2)
        #expect(problemSet.addGenerated(generated) == 2)

        #expect(problemSet.items.count == 2)
        #expect(problemSet.items.allSatisfy { $0.sources.first?.section == "Page 3" })
        #expect(problemSet.groups.map(\.title) == ["Lecture 4"])
    }

    @Test @MainActor
    func generatedProblemsRequireReviewBeforeSaving() async {
        let generated = await CourseSourceStore(courseID: "calculus-1", client: RecordingCourseStudyClient())
            .generateProblems(count: 2)
        let problems = ProblemSetStore()
        let review = GeneratedProblemReviewStore()
        review.load(generated)

        #expect(problems.items.isEmpty)
        #expect(review.drafts.count == 2)
        review.updatePrompt(review.drafts[0].id, to: "  Revised problem  ")
        review.toggleSelection(review.drafts[1].id)
        #expect(review.saveSelected(into: problems) == 1)
        #expect(problems.items.map(\.prompt) == ["Revised problem"])
        #expect(review.drafts.isEmpty)
    }

    @Test @MainActor
    func groupsAndProblemEditsPreserveIdentityAndSources() {
        let problems = ProblemSetStore()
        let group = problems.addGroup("  Limits  ")!
        let source = TutorSource(sourceID: "page-3", title: "Lecture.pdf", section: "Page 3")
        let problem = problems.add("Find the limit", sources: [source])!
        #expect(problems.move(problem.id, to: group.id))
        #expect(problems.update(problem.id, prompt: "  Find the left limit  "))
        #expect(problems.items[0].id == problem.id)
        #expect(problems.items[0].sources == [source])
        #expect(problems.items[0].groupID == group.id)
        #expect(problems.renameGroup(group.id, to: "Continuity"))
        #expect(problems.removeGroup(group.id))
        #expect(problems.items[0].groupID == nil)
        #expect(problems.remove(problem.id))
        #expect(problems.items.isEmpty)
    }

    @Test @MainActor
    func savedAssignmentQuestionsAutomaticallyShareASourceFolder() {
        let problems = ProblemSetStore()
        let assignment = TutorSource(sourceID: "a1-page-1", title: "Assignment_1_prac_questions.pdf", section: "Page 1")
        let generated = [
            GeneratedCourseProblem(prompt: "Question 1", sources: [assignment]),
            GeneratedCourseProblem(prompt: "Question 2", sources: [assignment]),
        ]

        #expect(problems.addGenerated(generated) == 2)
        #expect(problems.groups.map(\.title) == ["Assignment 1 Practice Questions"])
        #expect(problems.items.allSatisfy { $0.groupID == problems.groups[0].id })
        #expect(problems.renameGroup(problems.groups[0].id, to: "Week 1 assignment"))
        #expect(problems.addGenerated([GeneratedCourseProblem(prompt: "Question 3", sources: [assignment])]) == 1)
        #expect(problems.groups.count == 1)
        #expect(problems.groups[0].title == "Week 1 assignment")
        #expect(problems.items.count == 3)
        #expect(problems.add("My own question")?.groupID == nil)
    }

    @Test @MainActor
    func mixedSourceQuestionsUseAnHonestFolderName() {
        let problems = ProblemSetStore()
        let sources = [
            TutorSource(sourceID: "a", title: "Lecture.pdf", section: "Page 1"),
            TutorSource(sourceID: "b", title: "Assignment 1.pdf", section: "Page 2"),
        ]
        #expect(problems.addGenerated([GeneratedCourseProblem(prompt: "Explain both", sources: sources)]) == 1)
        #expect(problems.groups.map(\.title) == ["Mixed Course Sources"])
        #expect(problems.addGenerated([GeneratedCourseProblem(prompt: "  ", sources: sources)]) == 0)
        #expect(problems.groups.count == 1)
    }

    @Test @MainActor
    func twoCourseThreadsCanAnswerWhileFirstResponseIsPending() async {
        let client = GatedCourseAnswerClient()
        let store = CourseSourceStore(courseID: "calculus-1", client: client)
        let first = Task { await store.answer("first") }
        await client.waitUntilFirstStarts()

        let second = await store.answer("second")
        #expect(second?.answer == "Answer to second")
        await client.releaseFirst()
        #expect(await first.value?.answer == "Answer to first")
        #expect(!store.isAnswering)
    }
}

private actor GatedCourseAnswerClient: CourseStudyClient {
    private var firstStarted = false
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstReleased = false
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func listSources(courseID: String) async throws -> [CourseSourceRecord] { [] }

    func readPDF(sourceID: String, courseID: String) async throws -> Data { Data() }

    func importPDF(_ attachment: MessageAttachment, courseID: String) async throws -> CourseSourceRecord {
        CourseSourceRecord(sourceID: "unused", filename: attachment.filename, pageCount: 1, chunkCount: 1)
    }

    func answerCourseQuestion(_ question: String, courseID: String,
                              attachment: MessageAttachment?) async throws -> GroundedCourseAnswer {
        if question == "first" {
            firstStarted = true
            startedWaiters.forEach { $0.resume() }
            startedWaiters.removeAll()
            if !firstReleased {
                await withCheckedContinuation { releaseWaiters.append($0) }
            }
        }
        return GroundedCourseAnswer(answer: "Answer to \(question)", sources: [])
    }

    func generateProblems(courseID: String, count: Int) async throws -> [GeneratedCourseProblem] { [] }

    func waitUntilFirstStarts() async {
        if firstStarted { return }
        await withCheckedContinuation { startedWaiters.append($0) }
    }

    func releaseFirst() {
        firstReleased = true
        releaseWaiters.forEach { $0.resume() }
        releaseWaiters.removeAll()
    }
}

private actor RecordingCourseStudyClient: CourseStudyClient {
    func listSources(courseID: String) async throws -> [CourseSourceRecord] {
        []
    }

    func readPDF(sourceID: String, courseID: String) async throws -> Data {
        Data("%PDF-1.4 source-1".utf8)
    }

    func importPDF(_ attachment: MessageAttachment, courseID: String) async throws -> CourseSourceRecord {
        CourseSourceRecord(
            sourceID: "source-1",
            filename: attachment.filename,
            pageCount: 4,
            chunkCount: 7
        )
    }

    func answerCourseQuestion(_ question: String, courseID: String,
                              attachment: MessageAttachment?) async throws -> GroundedCourseAnswer {
        GroundedCourseAnswer(
            answer: "Differentiate the outer function, then multiply by the inner derivative.",
            sources: [TutorSource(sourceID: "chunk-1", title: "Lecture 4.pdf", section: "Page 3")]
        )
    }

    func generateProblems(courseID: String, count: Int) async throws -> [GeneratedCourseProblem] {
        (0..<count).map { index in
            GeneratedCourseProblem(
                prompt: "Generated problem \(index + 1)",
                sources: [TutorSource(sourceID: "chunk-1", title: "Lecture 4.pdf", section: "Page 3")]
            )
        }
    }
}
