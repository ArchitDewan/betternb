# F007 native authentication and account foundation

## Purpose and acceptance

BetterNB requires a student to authenticate before entering the native workspace. Auth0 provides Apple, Google, and passwordless email login through OIDC; the Go API validates access tokens and persists a stable BetterNB account in PostgreSQL.

Acceptance criteria:

- A fresh app launch presents sign-in rather than the workspace.
- A valid Auth0 login bootstraps one stable account and unlocks the workspace.
- Credentials restore from Keychain and a previously authenticated account can enter local-only mode during a network outage.
- Logout locks the workspace and clears active credentials.
- The Go API rejects invalid tokens and idempotently creates or retrieves accounts by OIDC issuer and subject.
- The existing public site and prototype continue to build and pass their tests.

## Context

The SwiftUI app is the product; the existing `cmd/betternb` binary remains the marketing/prototype server. A new `cmd/betternb-api` binary owns account endpoints. Python is not part of authentication. The client is a public OAuth client and never contains a client secret.

## Plan

- Add test-driven account HTTP contracts, an authenticated principal, a PostgreSQL account store, and versioned migrations.
- Add Auth0 RS256/JWKS validation and configuration to a separate Go API binary.
- Add replaceable Swift authentication/API protocols, Auth0 and URLSession adapters, secure session restoration, and a launch gate.
- Add Swift unit tests for session transitions and document provider/runtime setup and canonical commands.
- Run Go tests/race/vet/build, Swift tests/build, and inspect the final diff for secrets and authorization gaps.

## Progress

- [x] 2026-10-03: Confirmed architecture, product intent, toolchains, and isolated task worktree.
- [x] 2026-10-03: Added failing Go account and API behavior tests before implementation.
- [x] 2026-10-03: Implemented the Go account service, persistence, migrations, and Auth0 validation.
- [x] 2026-10-03: Added failing Swift session-state tests before the native adapters.
- [x] 2026-10-03: Implemented the native authentication boundary and launch gate.
- [x] 2026-10-03: Documented configuration and completed automated, database, visual, and security review.
- [x] 2026-10-03: Added `scripts/run-dev.sh` as the single-terminal development entrypoint with ignored one-time configuration.
- [x] 2026-10-03: Made the no-config runner use an explicit local development identity so the workspace remains runnable before Auth0 setup.
- [x] 2026-10-03: Default `./scripts/run-dev.sh` starts local PostgreSQL and requires Auth0.
- [x] 2026-10-03: Fixed Auth0 restore crash: CredentialsManager callbacks hop off the main actor.

## Decisions and discoveries

- Auth0 is the managed OIDC provider; Apple, Google, and passwordless email are tenant connections.
- Native clients use Authorization Code + PKCE and send only API access tokens to Go.
- Email is profile metadata, not an account key. Accounts map by `(issuer, subject)` and are never automatically merged.
- Authentication is required on first use. A previously authenticated account may use cached local work offline.
- Auth0.swift 2.x is required by the repository's installed Swift/Xcode toolchain; 3.x requires a newer Xcode generation.

## Validation

- `go test ./...`
- `go test -race ./...`
- `go vet ./...`
- `go build ./cmd/betternb-api`
- `swift test`
- `swift build`
- `./scripts/build-macos-prototype.sh`
- Manual configured-tenant verification remains required for Apple, Google, email OTP, and redirect callbacks.

## Recovery

The feature is isolated on `feat/F007-authentication` in `/Users/architdewan/Desktop/projects/betternb-worktrees/F007-authentication`. No migration or deployment is run automatically. Removing the new API binary, migration, Swift auth files, and package dependencies returns the repository to the prior prototype.

## Outcome

Delivered the authenticated native launch boundary and PostgreSQL-backed Go account API. JWT validation covers signature, issuer, audience, expiry, and subject; concurrent first-login requests converge on one account. Native session tests cover bootstrap, restore, offline fallback, revoked credentials, logout, and PostgreSQL fractional timestamps. `scripts/run-dev.sh` now loads `.env.local`, starts and migrates the API, builds and launches the app, and cleans up the API from one terminal. Full Go tests and race tests, vet, API build, Swift tests, app-bundle build, and default/minimum-window visual checks passed. Live Apple, Google, and email OTP verification remains dependent on configuring an Auth0 tenant with the documented values.
