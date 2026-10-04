@preconcurrency import Auth0
import Foundation

func awaitOffMainActorCallback<Value: Sendable>(
    _ start: @escaping @Sendable (@escaping @Sendable (Result<Value, Error>) -> Void) -> Void
) async throws -> Value {
    try await withCheckedThrowingContinuation { continuation in
        start { result in
            continuation.resume(with: result)
        }
    }
}

func resumeOffMainActor<Value: Sendable>(
    _ continuation: CheckedContinuation<Value, Error>,
    with result: Result<Value, Error>
) {
    continuation.resume(with: result)
}

func detachedWebAuthCallback(
    _ continuation: CheckedContinuation<Credentials, Error>
) -> (WebAuthResult<Credentials>) -> Void {
    { result in
        resumeOffMainActor(continuation, with: result.mapError { $0 as Error })
    }
}

func detachedWebAuthVoidCallback(
    _ continuation: CheckedContinuation<Void, Error>
) -> (WebAuthResult<Void>) -> Void {
    { result in
        resumeOffMainActor(continuation, with: result.map { _ in () }.mapError { $0 as Error })
    }
}

func authenticationContainsOfflineError(_ error: Error) -> Bool {
    if let urlError = error as? URLError {
        return [.notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .timedOut].contains(urlError.code)
    }
    if let error = error as? WebAuthError, let cause = error.cause {
        return authenticationContainsOfflineError(cause)
    }
    if let error = error as? CredentialsManagerError, let cause = error.cause {
        return authenticationContainsOfflineError(cause)
    }
    if let error = error as? AuthenticationError, let cause = error.cause {
        return authenticationContainsOfflineError(cause)
    }
    return false
}

func authenticationFailure(from error: Error) -> AuthenticationFailure {
    if authenticationContainsOfflineError(error) {
        return .offline
    }
    if WebAuthError.userCancelled ~= error {
        return .cancelled
    }
    if error as? CredentialsManagerError == .noCredentials || error as? CredentialsManagerError == .noRefreshToken {
        return .unauthenticated
    }
    if let webAuthError = error as? WebAuthError {
        return .unavailable(webAuthError.debugDescription)
    }
    return .unavailable("The secure sign-in service is temporarily unavailable.")
}

struct AuthenticationConfiguration: Sendable {
    let domain: String
    let clientID: String
    let audience: String
    let apiBaseURL: URL

    static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        info: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) -> AuthenticationConfiguration? {
        func value(environmentKey: String, infoKey: String) -> String? {
            let raw = environment[environmentKey] ?? info[infoKey] as? String
            guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                return nil
            }
            return trimmed
        }

        guard
            let domain = value(environmentKey: "BETTERNB_AUTH0_DOMAIN", infoKey: "BetterNBAuth0Domain"),
            let clientID = value(environmentKey: "BETTERNB_AUTH0_CLIENT_ID", infoKey: "BetterNBAuth0ClientID"),
            let audience = value(environmentKey: "BETTERNB_AUTH0_AUDIENCE", infoKey: "BetterNBAuth0Audience"),
            let apiURLString = value(environmentKey: "BETTERNB_API_URL", infoKey: "BetterNBAPIURL"),
            let apiBaseURL = URL(string: apiURLString),
            Self.isAllowedAPIURL(apiBaseURL)
        else {
            return nil
        }
        return AuthenticationConfiguration(domain: domain, clientID: clientID, audience: audience, apiBaseURL: apiBaseURL)
    }

    private static func isAllowedAPIURL(_ url: URL) -> Bool {
        if url.scheme == "https" { return true }
        return url.scheme == "http" && ["127.0.0.1", "localhost", "::1"].contains(url.host ?? "")
    }
}

@MainActor
final class Auth0AuthenticationClient: AuthenticationClient {
    private let configuration: AuthenticationConfiguration
    private let credentialsManager: CredentialsManager

    init(configuration: AuthenticationConfiguration) {
        self.configuration = configuration
        let authentication = Auth0.authentication(clientId: configuration.clientID, domain: configuration.domain)
        credentialsManager = CredentialsManager(authentication: authentication, storeKey: "betternb.auth0.credentials.v1")
    }

    private func makeWebAuth() -> Auth0.WebAuth {
        Auth0.webAuth(clientId: configuration.clientID, domain: configuration.domain)
            .audience(configuration.audience)
            .scope("openid profile email offline_access")
    }

    func restoreCredentials() async throws -> AuthCredentials {
        do {
            let credentials = try await storedCredentials()
            return try mappedCredentials(credentials)
        } catch {
            throw authenticationFailure(from: error)
        }
    }

    func signIn() async throws -> AuthCredentials {
        do {
            let credentials = try await startWebAuthentication()
            guard credentialsManager.store(credentials: credentials) else {
                throw AuthenticationFailure.unavailable("BetterNB couldn’t securely store your session.")
            }
            return try mappedCredentials(credentials)
        } catch {
            throw authenticationFailure(from: error)
        }
    }

    func signOut() async {
        try? await revokeCredentials()
        _ = credentialsManager.clear()
        try? await clearWebSession()
    }

    private func storedCredentials() async throws -> Credentials {
        let manager = credentialsManager
        return try await awaitOffMainActorCallback { completion in
            manager.credentials(minTTL: 60) { result in
                completion(result.mapError { $0 as Error })
            }
        }
    }

    private func startWebAuthentication() async throws -> Credentials {
        let webAuth = makeWebAuth()
        return try await withCheckedThrowingContinuation { continuation in
            webAuth.start(detachedWebAuthCallback(continuation))
        }
    }

    private func revokeCredentials() async throws {
        let manager = credentialsManager
        try await awaitOffMainActorCallback { completion in
            manager.revoke { result in
                completion(result.map { _ in () }.mapError { $0 as Error })
            }
        }
    }

    private func clearWebSession() async throws {
        let webAuth = makeWebAuth()
        try await withCheckedThrowingContinuation { continuation in
            webAuth.clearSession(callback: detachedWebAuthVoidCallback(continuation))
        }
    }

    private func mappedCredentials(_ credentials: Credentials) throws -> AuthCredentials {
        guard let user = credentialsManager.user, !user.sub.isEmpty else {
            throw AuthenticationFailure.unauthenticated
        }
        return AuthCredentials(accessToken: credentials.accessToken, subject: user.sub, displayName: user.name)
    }

}

@MainActor
final class URLSessionAccountAPI: AccountAPI {
    private let endpoint: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        endpoint = baseURL.appending(path: "v1/accounts/me")
        self.session = session
    }

    func bootstrap(accessToken: String) async throws -> BetterNBAccount {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationFailure.unavailable("The account service returned an invalid response.")
        }
        if httpResponse.statusCode == 401 {
            throw AuthenticationFailure.unauthenticated
        }
        guard [200, 201].contains(httpResponse.statusCode) else {
            throw AuthenticationFailure.unavailable("The account service is temporarily unavailable.")
        }
        return try makeAPIJSONDecoder().decode(AccountEnvelope.self, from: data).account
    }

    private struct AccountEnvelope: Decodable {
        let account: BetterNBAccount
    }
}

func makeAPIJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        if let date = standard.date(from: value) { return date }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid RFC 3339 timestamp")
    }
    return decoder
}

@MainActor
final class UnavailableAuthenticationClient: AuthenticationClient {
    func restoreCredentials() async throws -> AuthCredentials { throw AuthenticationFailure.unauthenticated }
    func signIn() async throws -> AuthCredentials {
        throw AuthenticationFailure.unavailable("Authentication isn’t configured for this build.")
    }
    func signOut() async {}
}

@MainActor
final class UnavailableAccountAPI: AccountAPI {
    func bootstrap(accessToken: String) async throws -> BetterNBAccount {
        throw AuthenticationFailure.unavailable("The account service isn’t configured for this build.")
    }
}

@MainActor
final class DevelopmentAuthenticationClient: AuthenticationClient {
    private let credentials = AuthCredentials(
        accessToken: "local-development-token",
        subject: "development|local-student",
        displayName: "Local Student"
    )

    func restoreCredentials() async throws -> AuthCredentials { credentials }
    func signIn() async throws -> AuthCredentials { credentials }
    func signOut() async {}
}

@MainActor
final class DevelopmentAccountAPI: AccountAPI {
    static let account = BetterNBAccount(
        id: "00000000-0000-0000-0000-000000000001",
        status: "active",
        createdAt: Date(timeIntervalSince1970: 0)
    )

    func bootstrap(accessToken: String) async throws -> BetterNBAccount {
        Self.account
    }
}

@MainActor
enum AppDependencies {
    static func makeAuthenticationSession() -> AuthenticationSession {
        let snapshotStore = UserDefaultsAccountSnapshotStore()
        if ProcessInfo.processInfo.environment["BETTERNB_DEV_AUTH_BYPASS"] == "1" {
            return AuthenticationSession(
                authClient: DevelopmentAuthenticationClient(),
                accountAPI: DevelopmentAccountAPI(),
                snapshotStore: snapshotStore
            )
        }
        guard let configuration = AuthenticationConfiguration.load() else {
            return AuthenticationSession(
                authClient: UnavailableAuthenticationClient(),
                accountAPI: UnavailableAccountAPI(),
                snapshotStore: snapshotStore
            )
        }
        return AuthenticationSession(
            authClient: Auth0AuthenticationClient(configuration: configuration),
            accountAPI: URLSessionAccountAPI(baseURL: configuration.apiBaseURL),
            snapshotStore: snapshotStore
        )
    }
}
