import CryptoKit
import Foundation
import Observation

struct CourseNotebook: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var title: String
    let createdAt: Date

    static let legacy = CourseNotebook(id: "calculus-1", title: "Calculus I", createdAt: .distantPast)
}

@MainActor
@Observable
final class CourseNotebookCatalog {
    private struct Snapshot: Codable {
        var notebooks: [CourseNotebook]
        var activeID: String
    }

    private let storageURL: URL
    private(set) var notebooks: [CourseNotebook]
    private(set) var activeID: String

    var activeNotebook: CourseNotebook {
        notebooks.first(where: { $0.id == activeID }) ?? .legacy
    }

    convenience init(accountID: String) {
        let digest = SHA256.hash(data: Data(accountID.utf8))
            .map { String(format: "%02x", $0) }.joined()
        let root = ProcessInfo.processInfo.environment["BETTERNB_NOTEBOOK_DATA_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Lemma", isDirectory: true)
        self.init(storageURL: root.appendingPathComponent(digest, isDirectory: true)
            .appendingPathComponent("course-notebooks-v1.json"))
    }

    init(storageURL: URL) {
        self.storageURL = storageURL
        if let data = try? Data(contentsOf: storageURL),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
           !snapshot.notebooks.isEmpty {
            notebooks = snapshot.notebooks
            activeID = snapshot.notebooks.contains(where: { $0.id == snapshot.activeID })
                ? snapshot.activeID : snapshot.notebooks[0].id
        } else {
            notebooks = [.legacy]
            activeID = CourseNotebook.legacy.id
        }
    }

    func canCreate(_ name: String) -> Bool {
        validName(name, excluding: nil)
    }

    func canRename(_ id: String, to name: String) -> Bool {
        notebooks.contains(where: { $0.id == id }) && validName(name, excluding: id)
    }

    @discardableResult
    func create(_ name: String) -> CourseNotebook? {
        guard canCreate(name) else { return nil }
        let notebook = CourseNotebook(id: UUID().uuidString.lowercased(),
                                      title: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                      createdAt: .now)
        notebooks.append(notebook)
        activeID = notebook.id
        persist()
        return notebook
    }

    @discardableResult
    func select(_ id: String) -> Bool {
        guard notebooks.contains(where: { $0.id == id }) else { return false }
        activeID = id
        persist()
        return true
    }

    @discardableResult
    func rename(_ id: String, to name: String) -> Bool {
        guard canRename(id, to: name),
              let index = notebooks.firstIndex(where: { $0.id == id }) else { return false }
        notebooks[index].title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
        return true
    }

    @discardableResult
    func delete(_ id: String) -> Bool {
        guard notebooks.count > 1,
              let index = notebooks.firstIndex(where: { $0.id == id }) else { return false }
        notebooks.remove(at: index)
        if activeID == id { activeID = notebooks[0].id }
        persist()
        return true
    }

    private func validName(_ name: String, excluding id: String?) -> Bool {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty && title.count <= 80 && !notebooks.contains {
            $0.id != id && $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Snapshot(notebooks: notebooks, activeID: activeID))
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Keep the current session usable if local storage is unavailable.
        }
    }
}
