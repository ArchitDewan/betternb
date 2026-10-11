import Foundation
import Observation

enum ReviewStatus: String, Codable, CaseIterable, Identifiable {
    case notStarted = "Not started", inProgress = "In progress", reviewed = "Reviewed"
    var id: String { rawValue }
}

struct ReviewTopic: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var description: String
    var sources: [TutorSource] = []
    var status: ReviewStatus = .notStarted
    var resourceIDs: [String] = []
}

struct ReviewUnit: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var topics: [ReviewTopic] = []
}

struct ReviewCardSet: Codable, Identifiable {
    var id = UUID()
    var title: String
    var topicID: UUID?
    var cards: [GeneratedTextbookFlashcard]
    var reviewCount = 0
    var lastReviewed: Date?
    var lastKnownCount = 0
}

struct ReviewPracticeActivity: Codable, Identifiable {
    var id = UUID()
    var topicID: UUID?
    var problemID: UUID
    var date = Date()
}

enum ResourceCategory: String, CaseIterable, Codable, Identifiable {
    case outline = "Outline", textbook = "Textbook", notes = "Notes", worksheet = "Worksheet", other = "Other"
    var id: String { rawValue }
}

@MainActor @Observable final class CourseReviewStore {
    private struct Snapshot: Codable {
        var units: [ReviewUnit] = []
        var sourceIDs: [String] = []
        var cardSets: [ReviewCardSet] = []
        var practice: [ReviewPracticeActivity] = []
        var categories: [String: ResourceCategory] = [:]
        var lastTopicID: UUID?
    }
    private var state = Snapshot()
    private(set) var errorMessage: String?
    @ObservationIgnored private let storageURL: URL?
    @ObservationIgnored private var unreadableSnapshot = false
    init(storageURL: URL?) {
        self.storageURL = storageURL
        if let storageURL, FileManager.default.fileExists(atPath: storageURL.path) {
            do { state = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: storageURL)) }
            catch { unreadableSnapshot = true; errorMessage = "Saved review data could not be read. It has not been replaced." }
        }
    }
    var units: [ReviewUnit] { state.units }
    var sourceIDs: [String] { state.sourceIDs }
    var topics: [ReviewTopic] { units.flatMap(\.topics) }
    var cardSets: [ReviewCardSet] { state.cardSets }
    var practice: [ReviewPracticeActivity] { state.practice }
    var reviewedCount: Int { topics.filter { $0.status == .reviewed }.count }
    var continueTopicID: UUID? {
        if let id = state.lastTopicID, topics.contains(where: { $0.id == id }) { return id }
        return topics.first { $0.status != .reviewed }?.id ?? topics.first?.id
    }
    static func valid(_ units: [ReviewUnit]) -> Bool {
        !units.isEmpty && units.allSatisfy {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.topics.isEmpty && $0.topics.allSatisfy {
                !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }
    @discardableResult func approve(_ units: [ReviewUnit], sourceIDs: [String]) -> Bool {
        guard Self.valid(units) else { return false }
        var next = state
        next.units = units
        next.sourceIDs = sourceIDs
        let ids = Set(units.flatMap(\.topics).map(\.id))
        for i in next.cardSets.indices where next.cardSets[i].topicID.map({ !ids.contains($0) }) == true {
            next.cardSets[i].topicID = nil
        }
        for i in next.practice.indices where next.practice[i].topicID.map({ !ids.contains($0) }) == true {
            next.practice[i].topicID = nil
        }
        return save(next)
    }
    func setStatus(_ id: UUID, _ status: ReviewStatus) {
        var next = state
        for i in next.units.indices {
            if let j = next.units[i].topics.firstIndex(where: { $0.id == id }) { next.units[i].topics[j].status = status }
        }
        _ = save(next)
    }
    func setResources(_ id: UUID, sourceIDs: [String]) {
        var next = state
        for i in next.units.indices {
            if let j = next.units[i].topics.firstIndex(where: { $0.id == id }) { next.units[i].topics[j].resourceIDs = sourceIDs }
        }
        _ = save(next)
    }
    func visit(_ id: UUID) {
        guard topics.contains(where: { $0.id == id }) else { return }
        var next = state; next.lastTopicID = id; _ = save(next)
    }
    @discardableResult func saveCards(_ set: ReviewCardSet) -> Bool {
        guard !set.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !set.cards.isEmpty,
              set.cards.allSatisfy({ !$0.front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return false }
        var next = state; next.cardSets.append(set); return save(next)
    }
    func recordCardReview(_ id: UUID, known: Int, total: Int) {
        var next = state
        guard let i = next.cardSets.firstIndex(where: { $0.id == id }), total > 0 else { return }
        next.cardSets[i].reviewCount += 1
        next.cardSets[i].lastReviewed = .now
        next.cardSets[i].lastKnownCount = known
        _ = save(next)
    }
    func recordPractice(topicID: UUID?, problemID: UUID) {
        var next = state; next.practice.append(ReviewPracticeActivity(topicID: topicID, problemID: problemID)); _ = save(next)
    }
    func category(_ sourceID: String) -> ResourceCategory { state.categories[sourceID] ?? .other }
    func setCategory(_ sourceID: String, _ category: ResourceCategory) {
        var next = state; next.categories[sourceID] = category; _ = save(next)
    }
    @discardableResult private func save(_ next: Snapshot) -> Bool {
        if let storageURL {
            // Never overwrite an unreadable existing snapshot.
            if unreadableSnapshot { return false }
            do {
                try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(next).write(to: storageURL, options: .atomic)
            } catch { errorMessage = "Changes could not be saved. Please try again."; return false }
        }
        state = next; errorMessage = nil; return true
    }
}

struct GeneratedRoadmap: Decodable, Sendable {
    struct Topic: Decodable, Sendable { let title: String; let description: String; let sources: [TutorSource] }
    struct Unit: Decodable, Sendable { let title: String; let topics: [Topic] }
    let units: [Unit]
    var editableUnits: [ReviewUnit] {
        units.map { unit in ReviewUnit(title: unit.title, topics: unit.topics.map {
            ReviewTopic(title: $0.title, description: $0.description, sources: $0.sources)
        }) }
    }
}

extension NotebookStorage {
    static func reviewURL(for accountID: String, notebookID: String) -> URL {
        problemsURL(for: accountID, notebookID: notebookID).deletingLastPathComponent().appendingPathComponent("review-v1.json")
    }
}
