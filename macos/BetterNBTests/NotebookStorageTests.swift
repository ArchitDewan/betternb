import Foundation
import CryptoKit
import Testing
@testable import BetterNB

@Suite("Notebook storage isolation")
struct NotebookStorageTests {
    @Test func preservesLegacyCalculusStorage() {
        let account = "integration-account"
        let digest = SHA256.hash(data: Data(account.utf8))
            .prefix(10).map { String(format: "%02x", $0) }.joined()
        #expect(NotebookStorage.courseID(for: account, notebookID: "calculus-1") == "calculus-1-" + digest)
        #expect(NotebookStorage.problemsURL(for: account).deletingLastPathComponent().lastPathComponent == "calculus-1-" + digest)
        #expect(NotebookStorage.problemsURL(for: account) == NotebookStorage.problemsURL(for: account, notebookID: "calculus-1"))
        #expect(NotebookStorage.attemptsURL(for: account) == NotebookStorage.attemptsURL(for: account, notebookID: "calculus-1"))
    }

    @Test func separatesAccountsAndNotebooks() {
        #expect(NotebookStorage.courseID(for: "alice", notebookID: "physics") != NotebookStorage.courseID(for: "bob", notebookID: "physics"))
        #expect(NotebookStorage.courseID(for: "alice", notebookID: "physics") != NotebookStorage.courseID(for: "alice", notebookID: "calculus-1"))
        #expect(NotebookStorage.problemsURL(for: "alice", notebookID: "physics") != NotebookStorage.problemsURL(for: "alice", notebookID: "calculus-1"))
        #expect(NotebookStorage.attemptsURL(for: "alice", notebookID: "physics") != NotebookStorage.attemptsURL(for: "bob", notebookID: "physics"))
    }
}
