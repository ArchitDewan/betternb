import Foundation
import Testing
@testable import BetterNB

struct StudyDeskNavigationTests {
    @Test
    func sidebarHasOnePrimaryStudyEntryAndProgressivelyDisclosedTools() {
        #expect(WorkspaceDestination.primary == [.home, .review])
        #expect(WorkspaceDestination.courseTools == [.study, .textbook, .problems])
        #expect(WorkspaceDestination.studyTools == [.flashcards, .formulaSheet, .canvas])
    }

    @Test
    func questionLikeInputProposesCourseQuestion() {
        #expect(StudyDeskInputRouter.proposal(for: "How does the chain rule work?") == .askCourse)
        #expect(StudyDeskInputRouter.proposal(for: "Explain why this limit exists") == .askCourse)
    }

    @Test
    func problemLikeInputProposesWorksheet() {
        #expect(
            StudyDeskInputRouter.proposal(for: "Differentiate f(x) = (x^2 + 1)^3")
                == .startProblem
        )
        #expect(StudyDeskInputRouter.proposal(for: "Evaluate the integral from 0 to 1") == .startProblem)
        #expect(StudyDeskInputRouter.route(for: "5 * 5") == .startProblem)
    }

    @Test
    func ambiguousInputRoutesIntoConversationWithoutBlockingConfirmation() {
        #expect(StudyDeskInputRouter.proposal(for: "chain rule") == .choose)
        #expect(StudyDeskInputRouter.route(for: "chain rule") == .askCourse)
        #expect(StudyDeskInputRouter.proposal(for: "   ") == nil)
        #expect(StudyDeskInputRouter.route(for: "   ") == nil)
    }

    @Test
    func homeworkImageProposesWorksheet() throws {
        let attachment = try MessageAttachment(
            filename: "homework.png",
            mediaType: "image/png",
            data: Data([0x89, 0x50, 0x4E, 0x47])
        )

        #expect(StudyDeskInputRouter.proposal(for: "", attachment: attachment) == .startProblem)
    }
}
