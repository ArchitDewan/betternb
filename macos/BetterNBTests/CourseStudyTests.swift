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
        generated.forEach { problemSet.add($0.prompt, sources: $0.sources) }

        #expect(problemSet.items.count == 2)
        #expect(problemSet.items.allSatisfy { $0.sources.first?.section == "Page 3" })
    }
}

private actor RecordingCourseStudyClient: CourseStudyClient {
    func listSources(courseID: String) async throws -> [CourseSourceRecord] {
        []
    }

    func importPDF(_ attachment: MessageAttachment, courseID: String) async throws -> CourseSourceRecord {
        CourseSourceRecord(
            sourceID: "source-1",
            filename: attachment.filename,
            pageCount: 4,
            chunkCount: 7
        )
    }

    func answerCourseQuestion(_ question: String, courseID: String) async throws -> GroundedCourseAnswer {
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
