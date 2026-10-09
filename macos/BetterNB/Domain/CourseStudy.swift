import Foundation
import Observation

struct CourseSourceRecord: Codable, Equatable, Sendable, Identifiable {
    let sourceID: String
    let filename: String
    let pageCount: Int
    let chunkCount: Int

    var id: String { sourceID }

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case filename
        case pageCount = "page_count"
        case chunkCount = "chunk_count"
    }
}

struct GroundedCourseAnswer: Codable, Equatable, Sendable {
    let answer: String
    let sources: [TutorSource]
}

struct GeneratedCourseProblem: Codable, Equatable, Sendable {
    let prompt: String
    let sources: [TutorSource]
}

struct GeneratedProblemsEnvelope: Codable, Equatable, Sendable {
    let problems: [GeneratedCourseProblem]
}

struct GeneratedProblemDraft: Identifiable, Equatable {
    let id: UUID
    var prompt: String
    let sources: [TutorSource]
    var isSelected: Bool

    init(id: UUID = UUID(), prompt: String, sources: [TutorSource], isSelected: Bool = true) {
        self.id = id
        self.prompt = prompt
        self.sources = sources
        self.isSelected = isSelected
    }
}

@MainActor
@Observable
final class GeneratedProblemReviewStore {
    private(set) var drafts: [GeneratedProblemDraft] = []

    var selectedProblems: [GeneratedCourseProblem] {
        drafts.compactMap { draft in
            let trimmed = draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard draft.isSelected, !trimmed.isEmpty else { return nil }
            return GeneratedCourseProblem(prompt: trimmed, sources: draft.sources)
        }
    }

    func load(_ generated: [GeneratedCourseProblem]) {
        drafts = generated.map { GeneratedProblemDraft(prompt: $0.prompt, sources: $0.sources) }
    }

    func updatePrompt(_ id: UUID, to prompt: String) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[index].prompt = prompt
    }

    func toggleSelection(_ id: UUID) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[index].isSelected.toggle()
    }

    @discardableResult
    func saveSelected(into problems: ProblemSetStore) -> Int {
        let saved = problems.addGenerated(selectedProblems)
        drafts = []
        return saved
    }

    func discard() {
        drafts = []
    }
}

protocol CourseStudyClient: Sendable {
    func listSources(courseID: String) async throws -> [CourseSourceRecord]
    func readPDF(sourceID: String, courseID: String) async throws -> Data
    func importPDF(_ attachment: MessageAttachment, courseID: String) async throws -> CourseSourceRecord
    func answerCourseQuestion(_ question: String, courseID: String,
                              attachment: MessageAttachment?) async throws -> GroundedCourseAnswer
    func generateProblems(courseID: String, count: Int) async throws -> [GeneratedCourseProblem]
    func generateQuiz(courseID: String, sourceID: String?, count: Int,
                      difficulty: QuizDifficulty) async throws -> GeneratedTextbookQuiz
    func generateFlashcards(courseID: String, sourceID: String?, count: Int) async throws -> [GeneratedTextbookFlashcard]
}

extension CourseStudyClient {
    func answerCourseQuestion(_ question: String, courseID: String) async throws -> GroundedCourseAnswer {
        try await answerCourseQuestion(question, courseID: courseID, attachment: nil)
    }

    func generateQuiz(courseID: String, sourceID: String?, count: Int,
                      difficulty: QuizDifficulty) async throws -> GeneratedTextbookQuiz {
        throw TutorServiceError.rejected("Quiz generation is not available from this client.")
    }

    func generateFlashcards(courseID: String, sourceID: String?, count: Int) async throws -> [GeneratedTextbookFlashcard] {
        throw TutorServiceError.rejected("Flashcards are unavailable from this course client.")
    }
}

@MainActor
@Observable
final class CourseSourceStore {
    let courseID: String
    private let client: any CourseStudyClient

    private(set) var sources: [CourseSourceRecord] = []
    private(set) var isLoading = false
    private(set) var isImporting = false
    private(set) var isAnswering = false
    private var activeAnswerCount = 0
    private(set) var isGenerating = false
    private(set) var isGeneratingQuiz = false
    private(set) var isGeneratingFlashcards = false
    private(set) var errorMessage: String?

    init(courseID: String, client: any CourseStudyClient) {
        self.courseID = courseID
        self.client = client
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            sources = try await client.listSources(courseID: courseID)
            errorMessage = nil
        } catch {
            errorMessage = message(for: error, fallback: "Sources couldn’t be loaded.")
        }
    }

    func document(for sourceID: String) async throws -> Data {
        try await client.readPDF(sourceID: sourceID, courseID: courseID)
    }

    @discardableResult
    func importPDF(_ attachment: MessageAttachment) async -> Bool {
        guard attachment.mediaType == "application/pdf", !isImporting else { return false }
        isImporting = true
        defer { isImporting = false }
        do {
            let imported = try await client.importPDF(attachment, courseID: courseID)
            sources.removeAll { $0.id == imported.id }
            sources.append(imported)
            sources.sort { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending }
            errorMessage = nil
            return true
        } catch {
            errorMessage = message(for: error, fallback: "That PDF couldn’t be indexed.")
            return false
        }
    }

    func answer(_ question: String, attachment: MessageAttachment? = nil) async -> GroundedCourseAnswer? {
        activeAnswerCount += 1
        isAnswering = true
        defer {
            activeAnswerCount -= 1
            isAnswering = activeAnswerCount > 0
        }
        do {
            let answer = try await client.answerCourseQuestion(question, courseID: courseID,
                                                               attachment: attachment)
            errorMessage = nil
            return answer
        } catch {
            errorMessage = message(for: error, fallback: "A grounded answer couldn’t be generated.")
            return nil
        }
    }

    func generateProblems(count: Int = 3) async -> [GeneratedCourseProblem] {
        guard !isGenerating else { return [] }
        isGenerating = true
        defer { isGenerating = false }
        do {
            let problems = try await client.generateProblems(courseID: courseID, count: count)
            errorMessage = nil
            return problems
        } catch {
            errorMessage = message(for: error, fallback: "Problems couldn’t be generated from these sources.")
            return []
        }
    }

    func generateQuiz(sourceID: String?, count: Int,
                      difficulty: QuizDifficulty) async -> GeneratedTextbookQuiz? {
        guard !isGeneratingQuiz else { return nil }
        isGeneratingQuiz = true
        defer { isGeneratingQuiz = false }
        do {
            let quiz = try await client.generateQuiz(courseID: courseID, sourceID: sourceID,
                                                     count: count, difficulty: difficulty)
            errorMessage = nil
            return quiz
        } catch {
            errorMessage = message(for: error, fallback: "The quiz couldn’t be generated.")
            return nil
        }
    }

    func generateFlashcards(sourceID: String?, count: Int) async -> [GeneratedTextbookFlashcard]? {
        guard !isGeneratingFlashcards else { return nil }
        isGeneratingFlashcards = true
        defer { isGeneratingFlashcards = false }
        do {
            let cards = try await client.generateFlashcards(courseID: courseID, sourceID: sourceID, count: count)
            guard cards.count == count, cards.allSatisfy({
                !$0.front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !$0.back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !$0.sources.isEmpty
            }) else {
                errorMessage = "The generated cards were incomplete. Please try again."
                return nil
            }
            errorMessage = nil
            return cards
        } catch {
            errorMessage = message(for: error, fallback: "Flashcards couldn’t be generated from this source.")
            return nil
        }
    }

    private func message(for error: Error, fallback: String) -> String {
        if case let TutorServiceError.rejected(message) = error {
            return message
        }
        return fallback
    }
}
