import CryptoKit
import Foundation

enum NotebookStorage {
    static func courseID(for accountID: String) -> String {
        let digest = SHA256.hash(data: Data(accountID.utf8))
        return "calculus-1-" + digest.prefix(10).map { String(format: "%02x", $0) }.joined()
    }

    private static func directory(for accountID: String) -> URL {
        if let override = ProcessInfo.processInfo.environment["BETTERNB_NOTEBOOK_DATA_DIR"],
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
                .appendingPathComponent(courseID(for: accountID), isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lemma/" + courseID(for: accountID), isDirectory: true)
    }

    static func problemsURL(for accountID: String) -> URL {
        directory(for: accountID).appendingPathComponent("problems-v1.json")
    }

    static func attemptsURL(for accountID: String) -> URL {
        directory(for: accountID).appendingPathComponent("attempts-v1.json")
    }
}
