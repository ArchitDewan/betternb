import Foundation

struct AuthCredentials: Equatable, Sendable {
    let accessToken: String
    let subject: String
    let displayName: String?
}

struct BetterNBAccount: Codable, Equatable, Sendable {
    let id: String
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case createdAt = "created_at"
    }
}

enum AuthenticationFailure: Error, Equatable {
    case cancelled
    case offline
    case unauthenticated
    case unavailable(String)
}

@MainActor
protocol AuthenticationClient {
    func restoreCredentials() async throws -> AuthCredentials
    func signIn() async throws -> AuthCredentials
    func signOut() async
}

@MainActor
protocol AccountAPI {
    func bootstrap(accessToken: String) async throws -> BetterNBAccount
}

@MainActor
protocol AccountSnapshotStore: AnyObject {
    func load() -> BetterNBAccount?
    func save(_ account: BetterNBAccount)
    func clear()
}

@MainActor
final class AuthenticationSession: ObservableObject {
    enum State: Equatable {
        case restoring
        case signedOut
        case authenticating
        case bootstrappingAccount
        case signedIn(BetterNBAccount)
        case offlineAuthenticated(BetterNBAccount)

        var account: BetterNBAccount? {
            switch self {
            case .signedIn(let account), .offlineAuthenticated(let account): account
            default: nil
            }
        }

        var unlocksWorkspace: Bool { account != nil }
    }

    @Published private(set) var state: State = .restoring
    @Published private(set) var errorMessage: String?

    private let authClient: AuthenticationClient
    private let accountAPI: AccountAPI
    private let snapshotStore: AccountSnapshotStore

    init(authClient: AuthenticationClient, accountAPI: AccountAPI, snapshotStore: AccountSnapshotStore) {
        self.authClient = authClient
        self.accountAPI = accountAPI
        self.snapshotStore = snapshotStore
    }

    func restore() async {
        state = .restoring
        errorMessage = nil
        do {
            let credentials = try await authClient.restoreCredentials()
            state = .bootstrappingAccount
            let account = try await accountAPI.bootstrap(accessToken: credentials.accessToken)
            snapshotStore.save(account)
            state = .signedIn(account)
        } catch {
            if Self.isOffline(error), let account = snapshotStore.load() {
                state = .offlineAuthenticated(account)
                return
            }
            if Self.isUnauthenticated(error) {
                snapshotStore.clear()
            }
            state = .signedOut
        }
    }

    func signIn() async {
        state = .authenticating
        errorMessage = nil
        do {
            let credentials = try await authClient.signIn()
            state = .bootstrappingAccount
            let account = try await accountAPI.bootstrap(accessToken: credentials.accessToken)
            snapshotStore.save(account)
            state = .signedIn(account)
        } catch AuthenticationFailure.cancelled {
            state = .signedOut
        } catch {
            state = .signedOut
            errorMessage = Self.message(for: error)
        }
    }

    func signOut() async {
        await authClient.signOut()
        snapshotStore.clear()
        errorMessage = nil
        state = .signedOut
    }

    private static func isOffline(_ error: Error) -> Bool {
        if error as? AuthenticationFailure == .offline { return true }
        guard let urlError = error as? URLError else { return false }
        return [.notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .timedOut].contains(urlError.code)
    }

    private static func isUnauthenticated(_ error: Error) -> Bool {
        error as? AuthenticationFailure == .unauthenticated
    }

    private static func message(for error: Error) -> String {
        if isOffline(error) {
            return "Connect to the internet to sign in."
        }
        if case .unavailable(let message) = error as? AuthenticationFailure {
            return message
        }
        return "We couldn’t sign you in. Try again."
    }
}

@MainActor
final class UserDefaultsAccountSnapshotStore: AccountSnapshotStore {
    private let defaults: UserDefaults
    private let key = "betternb.active-account.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> BetterNBAccount? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(BetterNBAccount.self, from: data)
    }

    func save(_ account: BetterNBAccount) {
        guard let data = try? JSONEncoder().encode(account) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
