# BetterNB agent instructions

Use the `reviewable-delivery` skill for features, bug fixes, refactors, and release work.

This repository is at its initial setup stage. Derive commands from the files that actually exist, and update this document as the project gains canonical commands.

Current Go web application commands:

- Run locally: `go run ./cmd/betternb` (opens on `http://127.0.0.1:8080`; use `-data-dir` to select development storage).
- Test: `go test ./...`.
- Race test: `go test -race ./...`.
- Static analysis: `go vet ./...`.
- Build: `go build ./cmd/betternb`.

Current Go account API commands:

- Configure: set `BETTERNB_DATABASE_URL`, `BETTERNB_AUTH0_ISSUER`, and `BETTERNB_AUTH0_AUDIENCE` as described in `docs/AUTHENTICATION.md`.
- Run and migrate locally: `go run ./cmd/betternb-api -migrate` (opens on `http://127.0.0.1:8081`).
- PostgreSQL integration test: set `BETTERNB_TEST_DATABASE_URL`, then run `go test ./internal/account -run TestPostgresStoreConcurrentBootstrapIsIdempotent -count=1`.

Current native macOS prototype commands:

- Run the complete development stack: `./scripts/run-dev.sh` (starts local PostgreSQL, then loads ignored `.env.local`; see `.env.example`).
- Run locally: `swift run BetterNB`.
- Test: `swift test`.
- Build: `swift build`.
- Build an inspectable app bundle: `./scripts/build-macos-prototype.sh`.
- Inspect the minimum window: `BETTERNB_WINDOW=min .build/BetterNB.app/Contents/MacOS/BetterNB`.
- Zoom type and spacing: `⌘+` / `⌘=` in, `⌘-` out, `⌘0` reset. Default is 110%.

Current Python tutoring service commands:

- Install/sync: `uv sync`.
- Test: `uv run pytest`.
- Run locally: set `OPENAI_API_KEY`, set `PYTHONPATH=services/tutor/src`, then run `uv run uvicorn --factory betternb_tutor.main:build_app --host 127.0.0.1 --port 8082`.
- The complete development stack remains `./scripts/run-dev.sh`; it starts the tutor service as well as the configured account stack and native app.

The SwiftUI prototype has unit tests for authentication state. Continue to verify visual-only changes by building and inspecting the running app at its default and minimum window sizes.

There is not yet a separate formatter/linter or deployment command. Account migrations run explicitly through `betternb-api -migrate`.

Use `docs/PRODUCT.md` for product scope, `docs/ARCHITECTURE.md` for system boundaries, and `docs/DEVELOPMENT.md` for the feature-session and worktree workflow. Read only the document relevant to the current task.

For a behavior change, define observable acceptance criteria and add or update a useful test before the implementation when feasible. Keep diffs focused and preserve unrelated user changes. Finish the requested implementation and verification before handing it back for review.

Use one Git worktree and branch per independent or concurrent task. Reuse that worktree when another session continues the same task. Read-only investigation does not require a worktree. Never remove another task's worktree or move its uncommitted changes without explicit direction.

Create BetterNB task worktrees under the persistent sibling directory `/Users/architdewan/Desktop/projects/betternb-worktrees/<feature-id>-<slug>`. Never create or relocate a task worktree under `/tmp`, `/private/tmp`, or another ephemeral directory. If the persistent worktree root requires sandbox approval, request that approval instead of substituting a temporary location.

For a complex feature, architectural change, or risky migration, create a living execution plan under `.agent/plans/` and follow [`.agent/PLANS.md`](.agent/PLANS.md).

Production deploys require an explicit user request. Prepare and verify the release first, then present the exact target, artifact, smoke checks, and rollback path at the deployment boundary.
