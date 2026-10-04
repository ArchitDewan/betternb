# Authentication setup

BetterNB uses Auth0 as its OIDC identity provider. The native app uses Authorization Code with PKCE through the system authentication browser. The Go account API accepts only Auth0 API access tokens and maps their verified `(issuer, subject)` identity to a BetterNB account in PostgreSQL.

Neither native client has a client secret. Never put Apple, Google, Auth0 Management API, or PostgreSQL credentials in the app bundle or repository.

## Auth0 tenant

Create an Auth0 API with an identifier such as `https://api.betternb.com`, RS256 signing, a 15-minute token lifetime, and offline access enabled. Create a first-party **Native** application for macOS with refresh-token rotation enabled, a 30-day inactivity lifetime, and a 90-day absolute lifetime.

For the prototype bundle identifier `com.betternb.prototype` and a tenant domain `TENANT.auth0.com`, allow these URLs:

```text
com.betternb.prototype://TENANT.auth0.com/macos/com.betternb.prototype/callback
```

Use the same value for Allowed Callback URLs and Allowed Logout URLs. Production should use the final bundle identifier and an HTTPS universal-link callback before distribution. A future iPhone target receives its own Auth0 native application and `/ios/` callback; it shares the API audience.

Enable these Universal Login connections for the native application:

- Sign in with Apple;
- Google;
- passwordless email using one-time codes, not passwords or magic-link-only deep links.

Configure Apple and Google provider credentials only in Auth0. Do not automatically link identities based on email; Apple relay email and provider email changes make that unsafe. Explicit account linking is a later authenticated workflow.

## Go account API

Set:

```text
BETTERNB_DATABASE_URL=postgres://USER:PASSWORD@HOST:5432/DATABASE?sslmode=require
BETTERNB_AUTH0_ISSUER=https://TENANT.auth0.com/
BETTERNB_AUTH0_AUDIENCE=https://api.betternb.com
```

Apply pending migrations explicitly and start the service:

```sh
go run ./cmd/betternb-api -migrate
```

The public health endpoint is `GET /healthz`. `POST /v1/accounts/me` validates the bearer token and idempotently creates or retrieves an account; `GET /v1/accounts/me` retrieves an already bootstrapped account. Run the service behind HTTPS in deployed environments.

## Native app

For normal development, copy the configuration template once, fill in the Auth0 values, and then use the single run command:

```sh
cp .env.example .env.local
./scripts/run-dev.sh
```

`run-dev.sh` loads the ignored configuration file, starts the PostgreSQL service in `compose.yaml` when it is not already accepting connections, builds and migrates the Go account API, waits for it to become healthy, builds the macOS app bundle, launches it in the foreground, and stops the API when the app exits. The database URL in `.env.example` matches that local database. `./scripts/run-dev.sh --local-account` is an explicit opt-in that opens the workspace with a local development identity and does not contact Auth0 or PostgreSQL. Release builds do not set `BETTERNB_DEV_AUTH_BYPASS`.

The development app reads public configuration from its process environment:

```text
BETTERNB_AUTH0_DOMAIN=TENANT.auth0.com
BETTERNB_AUTH0_CLIENT_ID=NATIVE_APPLICATION_CLIENT_ID
BETTERNB_AUTH0_AUDIENCE=https://api.betternb.com
BETTERNB_API_URL=http://127.0.0.1:8081
```

`BETTERNB_API_URL` must use HTTPS except for `localhost`, `127.0.0.1`, or `::1`. Release packaging may provide the same values through the `BetterNBAuth0Domain`, `BetterNBAuth0ClientID`, `BetterNBAuth0Audience`, and `BetterNBAPIURL` Info.plist keys. These identifiers are public configuration, not secrets.

Build the app bundle, then launch its executable from the configured shell so it inherits the variables:

```sh
./scripts/build-macos-prototype.sh
.build/BetterNB.app/Contents/MacOS/BetterNB
```

Auth0.swift stores access, ID, and rotating refresh tokens in Keychain. BetterNB stores only a non-secret active-account snapshot in UserDefaults for offline workspace gating. An explicit provider rejection clears that snapshot; a network outage can unlock only an account that previously bootstrapped successfully on the device.

## Verification boundaries

Automated tests cover JWT signature/issuer/audience/expiry checks, API authorization and account contracts, concurrent PostgreSQL bootstrap, and native session transitions. Before a release, manually verify all three tenant connections, callback/logout handling, token renewal, offline launch, logout, and account isolation using signed app builds.
