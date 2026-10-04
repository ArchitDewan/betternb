import Auth0
import Foundation
import Testing
@testable import BetterNB

@MainActor
struct AuthenticationSessionTests {
    @Test
    func localDevelopmentIdentityUnlocksWorkspaceWithoutExternalServices() async {
        let snapshots = MemoryAccountSnapshotStore()
        let session = AuthenticationSession(
            authClient: DevelopmentAuthenticationClient(),
            accountAPI: DevelopmentAccountAPI(),
            snapshotStore: snapshots
        )

        await session.restore()

        #expect(session.state == .signedIn(DevelopmentAccountAPI.account))
        #expect(snapshots.load() == DevelopmentAccountAPI.account)
    }

    @Test
    func accountAPIDecodesPostgresFractionalTimestamp() throws {
        let json = #"{"id":"account-1","status":"active","created_at":"2026-10-03T20:04:05.123456Z"}"#.data(using: .utf8)!
        let account = try makeAPIJSONDecoder().decode(BetterNBAccount.self, from: json)

        #expect(account.id == "account-1")
        #expect(account.status == "active")
        #expect(account.createdAt.timeIntervalSince1970 > 0)
    }

    @Test
    func successfulSignInBootstrapsAndPersistsAccount() async {
        let credentials = AuthCredentials(accessToken: "access", subject: "auth0|student", displayName: "Student")
        let account = BetterNBAccount(id: "account-1", status: "active", createdAt: .distantPast)
        let auth = FakeAuthenticationClient(signInResult: .success(credentials))
        let api = FakeAccountAPI(result: .success(account))
        let snapshots = MemoryAccountSnapshotStore()
        let session = AuthenticationSession(authClient: auth, accountAPI: api, snapshotStore: snapshots)

        await session.signIn()

        #expect(session.state == .signedIn(account))
        #expect(api.receivedTokens == ["access"])
        #expect(snapshots.load() == account)
    }

    @Test
    func restoreUsesAccountSnapshotOnlyForNetworkFailure() async {
        let account = BetterNBAccount(id: "account-1", status: "active", createdAt: .distantPast)
        let snapshots = MemoryAccountSnapshotStore(account: account)
        let offline = FakeAuthenticationClient(restoreResult: .failure(AuthenticationFailure.offline))
        let session = AuthenticationSession(authClient: offline, accountAPI: FakeAccountAPI(), snapshotStore: snapshots)

        await session.restore()

        #expect(session.state == .offlineAuthenticated(account))
    }

    @Test
    func revokedCredentialsLockWorkspaceEvenWhenSnapshotExists() async {
        let account = BetterNBAccount(id: "account-1", status: "active", createdAt: .distantPast)
        let snapshots = MemoryAccountSnapshotStore(account: account)
        let revoked = FakeAuthenticationClient(restoreResult: .failure(AuthenticationFailure.unauthenticated))
        let session = AuthenticationSession(authClient: revoked, accountAPI: FakeAccountAPI(), snapshotStore: snapshots)

        await session.restore()

        #expect(session.state == .signedOut)
        #expect(snapshots.load() == nil)
    }

    @Test
    func cancelledWebAuthIsNotShownAsUnavailable() {
        #expect(authenticationFailure(from: WebAuthError.userCancelled) == .cancelled)
    }

    @Test
    func missingStoredCredentialsAreUnauthenticated() {
        #expect(authenticationFailure(from: CredentialsManagerError.noCredentials) == .unauthenticated)
    }

    @Test
    func backgroundAuthCallbackCanFinishMainActorWait() async throws {
        let value = try await awaitOffMainActorCallback { finish in
            DispatchQueue.global(qos: .userInitiated).async {
                finish(.success("restored"))
            }
        }

        #expect(value == "restored")
    }

    @Test
    func logoutClearsCredentialsAndActiveSnapshot() async {
        let account = BetterNBAccount(id: "account-1", status: "active", createdAt: .distantPast)
        let auth = FakeAuthenticationClient()
        let snapshots = MemoryAccountSnapshotStore(account: account)
        let session = AuthenticationSession(authClient: auth, accountAPI: FakeAccountAPI(), snapshotStore: snapshots)

        await session.signOut()

        #expect(session.state == .signedOut)
        #expect(auth.signOutCalls == 1)
        #expect(snapshots.load() == nil)
    }
}

@MainActor
private final class FakeAuthenticationClient: AuthenticationClient {
    var restoreResult: Result<AuthCredentials, Error>
    var signInResult: Result<AuthCredentials, Error>
    var signOutCalls = 0

    init(
        restoreResult: Result<AuthCredentials, Error> = .failure(AuthenticationFailure.unauthenticated),
        signInResult: Result<AuthCredentials, Error> = .failure(AuthenticationFailure.cancelled)
    ) {
        self.restoreResult = restoreResult
        self.signInResult = signInResult
    }

    func restoreCredentials() async throws -> AuthCredentials { try restoreResult.get() }
    func signIn() async throws -> AuthCredentials { try signInResult.get() }
    func signOut() async { signOutCalls += 1 }
}

@MainActor
private final class FakeAccountAPI: AccountAPI {
    var result: Result<BetterNBAccount, Error>
    var receivedTokens: [String] = []

    init(result: Result<BetterNBAccount, Error> = .failure(AuthenticationFailure.unauthenticated)) {
        self.result = result
    }

    func bootstrap(accessToken: String) async throws -> BetterNBAccount {
        receivedTokens.append(accessToken)
        return try result.get()
    }
}

private final class MemoryAccountSnapshotStore: AccountSnapshotStore, @unchecked Sendable {
    private var account: BetterNBAccount?

    init(account: BetterNBAccount? = nil) { self.account = account }
    func load() -> BetterNBAccount? { account }
    func save(_ account: BetterNBAccount) { self.account = account }
    func clear() { account = nil }
}
