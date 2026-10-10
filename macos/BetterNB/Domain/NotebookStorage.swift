import CryptoKit
import Foundation

enum NotebookStorage {
    static func courseID(for accountID: String, notebookID: String = "calculus-1") -> String {
        let digest = SHA256.hash(data: Data(accountID.utf8))
        return notebookID + "-" + digest.prefix(10).map { String(format: "%02x", $0) }.joined()
    }

    private static func directory(for accountID: String, notebookID: String = "calculus-1") -> URL {
        if let override = ProcessInfo.processInfo.environment["BETTERNB_NOTEBOOK_DATA_DIR"],
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
                .appendingPathComponent(courseID(for: accountID, notebookID: notebookID), isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lemma/" + courseID(for: accountID, notebookID: notebookID), isDirectory: true)
    }

    static func problemsURL(for accountID: String, notebookID: String = "calculus-1") -> URL {
        directory(for: accountID, notebookID: notebookID).appendingPathComponent("problems-v1.json")
    }

    static func attemptsURL(for accountID: String, notebookID: String = "calculus-1") -> URL {
        directory(for: accountID, notebookID: notebookID).appendingPathComponent("attempts-v1.json")
    }
}
