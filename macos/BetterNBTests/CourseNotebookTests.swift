import Foundation
import Testing
@testable import BetterNB

@Suite("Course notebooks")
struct CourseNotebookTests {
    @Test @MainActor
    func createSelectAndReloadAStudentNamedCourse() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("notebooks.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let catalog = CourseNotebookCatalog(storageURL: url)
        #expect(catalog.notebooks.map(\.title) == ["Calculus I"])
        let created = try #require(catalog.create("  Linear Algebra  "))
        #expect(created.title == "Linear Algebra")
        #expect(catalog.activeNotebook.id == created.id)
        #expect(catalog.create("linear algebra") == nil)
        #expect(catalog.create("   ") == nil)

        let reloaded = CourseNotebookCatalog(storageURL: url)
        #expect(reloaded.notebooks.map(\.title) == ["Calculus I", "Linear Algebra"])
        #expect(reloaded.activeNotebook.id == created.id)
        #expect(reloaded.select("calculus-1"))
        #expect(CourseNotebookCatalog(storageURL: url).activeNotebook.id == "calculus-1")
    }

    @Test @MainActor
    func deletingANotebookSelectsAnExistingCourseAndSurvivesReload() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("notebooks.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let catalog = CourseNotebookCatalog(storageURL: url)
        let created = try #require(catalog.create("Physics 101"))
        #expect(catalog.delete("calculus-1"))
        #expect(catalog.notebooks.map(\.title) == ["Physics 101"])
        #expect(catalog.activeNotebook.id == created.id)
        #expect(CourseNotebookCatalog(storageURL: url).notebooks.map(\.title) == ["Physics 101"])
        #expect(!catalog.delete(created.id))
    }

    @Test @MainActor
    func renameKeepsTheNotebookIdentityAndRejectsDuplicateNames() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("notebooks.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let catalog = CourseNotebookCatalog(storageURL: url)
        let created = try #require(catalog.create("Physics 101"))
        #expect(catalog.rename(created.id, to: "  Organic Chemistry  "))
        #expect(catalog.activeNotebook.id == created.id)
        #expect(catalog.activeNotebook.title == "Organic Chemistry")
        #expect(!catalog.rename(created.id, to: "Calculus I"))
        #expect(!catalog.rename(created.id, to: "  "))
        #expect(CourseNotebookCatalog(storageURL: url).activeNotebook.title == "Organic Chemistry")
    }
}
