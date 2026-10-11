import Foundation
import Testing
@testable import BetterNB

@Suite("Course review") struct CourseReviewTests {
    @Test @MainActor func draftApprovalStatusAndReload() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("review.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = CourseReviewStore(storageURL: url)
        let topic = ReviewTopic(title: "Limits", description: "Understand limits")
        let units = [ReviewUnit(title: "Foundations", topics: [topic])]
        #expect(store.units.isEmpty)
        #expect(store.approve(units, sourceIDs: ["source"]))
        store.setStatus(topic.id, .reviewed)
        store.visit(topic.id)
        let loaded = CourseReviewStore(storageURL: url)
        #expect(loaded.reviewedCount == 1)
        #expect(loaded.continueTopicID == topic.id)
        #expect(loaded.sourceIDs == ["source"])
    }

    @Test @MainActor func replacingRoadmapDetachesCardsAndPreservesActivity() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("review.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = CourseReviewStore(storageURL: url)
        let topic = ReviewTopic(title: "Limits", description: "d")
        #expect(store.approve([ReviewUnit(title: "Unit", topics: [topic])], sourceIDs: []))
        let set = ReviewCardSet(title: "Limits", topicID: topic.id, cards: [GeneratedTextbookFlashcard(front: "Q", back: "A", sources: [])])
        store.saveCards(set)
        store.recordCardReview(set.id, known: 1, total: 1)
        #expect(store.reviewedCount == 0)
        #expect(store.approve([ReviewUnit(title: "New", topics: [ReviewTopic(title: "Integrals", description: "d")])], sourceIDs: []))
        let loaded = CourseReviewStore(storageURL: url)
        #expect(loaded.cardSets.count == 1)
        #expect(loaded.cardSets[0].topicID == nil)
        #expect(loaded.cardSets[0].reviewCount == 1)
    }

    @Test @MainActor func invalidDraftDoesNotReplaceSavedRoadmap() {
        let store = CourseReviewStore(storageURL: nil)
        let first = ReviewUnit(title: "Unit", topics: [ReviewTopic(title: "Limits", description: "d")])
        #expect(store.approve([first], sourceIDs: []))
        #expect(!store.approve([ReviewUnit(title: " ", topics: [])], sourceIDs: []))
        #expect(store.units.first?.id == first.id)
    }
    @Test @MainActor func editsKeepIdentityCategoriesAndPracticeAcrossReload() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("review.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = CourseReviewStore(storageURL: url)
        let first = ReviewTopic(title: "Limits", description: "d")
        let second = ReviewTopic(title: "Integrals", description: "d")
        #expect(store.approve([ReviewUnit(title: "Course", topics: [first, second])], sourceIDs: ["book"]))
        store.setStatus(first.id, .reviewed)
        store.setResources(first.id, sourceIDs: ["notes"])
        store.setCategory("book", .textbook)
        store.recordPractice(topicID: first.id, problemID: UUID())
        var edited = store.units
        edited[0].topics.swapAt(0, 1)
        edited[0].topics[1].title = "Limits and continuity"
        #expect(store.approve(edited, sourceIDs: ["book"]))
        let loaded = CourseReviewStore(storageURL: url)
        #expect(loaded.topics.map(\.id) == [second.id, first.id])
        #expect(loaded.topics[1].status == .reviewed)
        #expect(loaded.topics[1].resourceIDs == ["notes"])
        #expect(loaded.continueTopicID == second.id)
        #expect(loaded.category("book") == .textbook)
        #expect(loaded.category("old-source") == .other)
        #expect(loaded.practice[0].topicID == first.id)
    }

    @Test @MainActor func legacyProblemsLoadAndDetachWithoutDeleting() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("problems.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let id = UUID()
        try Data("{\"items\":[{\"id\":\"\(id)\",\"prompt\":\"Find a limit\",\"openedInPractice\":false,\"sources\":[]}],\"groups\":[]}".utf8).write(to: url)
        let problems = ProblemSetStore(storageURL: url)
        #expect(problems.items.count == 1)
        #expect(problems.items[0].topicID == nil)
        problems.linkTopic(id, topicID: UUID())
        #expect(ProblemSetStore(storageURL: url).items[0].topicID != nil)
        problems.detachTopics(except: [])
        #expect(ProblemSetStore(storageURL: url).items[0].id == id)
        #expect(ProblemSetStore(storageURL: url).items[0].topicID == nil)
    }

    @Test @MainActor func corruptSnapshotIsNeverOverwritten() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let original = Data("broken snapshot".utf8)
        try original.write(to: url)
        let store = CourseReviewStore(storageURL: url)
        #expect(store.errorMessage != nil)
        #expect(!store.approve([ReviewUnit(title: "New", topics: [ReviewTopic(title: "Topic", description: "")])], sourceIDs: []))
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func referenceRoutesToTheCorrectDocumentAndPage() {
        let target = ResourcePreviewTarget(reference: TutorSource(sourceID: "course.abc.p99.c2", title: "Book", section: "Page 99"))
        #expect(target.sourceID == "course.abc")
        #expect(target.page == 99)
    }

    @Test func reviewStorageSeparatesAccountsAndNotebooks() {
        let original = NotebookStorage.reviewURL(for: "alice", notebookID: "calculus-1")
        #expect(original != NotebookStorage.reviewURL(for: "bob", notebookID: "calculus-1"))
        #expect(original != NotebookStorage.reviewURL(for: "alice", notebookID: "physics"))
    }

}
