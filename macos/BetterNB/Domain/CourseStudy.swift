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

protocol CourseStudyClient: Sendable {
    func listSources(courseID: String) async throws -> [CourseSourceRecord]
    func importPDF(_ attachment: MessageAttachment, courseID: String) async throws -> CourseSourceRecord
    func answerCourseQuestion(_ question: String, courseID: String) async throws -> GroundedCourseAnswer
    func generateProblems(courseID: String, count: Int) async throws -> [GeneratedCourseProblem]
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
    private(set) var isGenerating = false
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

    func answer(_ question: String) async -> GroundedCourseAnswer? {
        guard !isAnswering else { return nil }
        isAnswering = true
        defer { isAnswering = false }
        do {
            let answer = try await client.answerCourseQuestion(question, courseID: courseID)
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

    private func message(for error: Error, fallback: String) -> String {
        if case let TutorServiceError.rejected(message) = error {
            return message
        }
        return fallback
    }
}
