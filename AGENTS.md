# BetterNB agent instructions

Use the `reviewable-delivery` skill for features, bug fixes, refactors, and release work.

This repository is at its initial setup stage. Derive commands from the files that actually exist, and update this document as the project gains canonical commands.

Current Go web application commands:

- Run locally: `go run ./cmd/betternb` (opens on `http://127.0.0.1:8080`; use `-data-dir` to select development storage).
- Test: `go test ./...`.
- Race test: `go test -race ./...`.
- Static analysis: `go vet ./...`.
- Build: `go build ./cmd/betternb`.

There is not yet a separate formatter/linter command, Python service, database migration command, or deployment command.

Use `docs/PRODUCT.md` for product scope, `docs/ARCHITECTURE.md` for system boundaries, and `docs/DEVELOPMENT.md` for the feature-session and worktree workflow. Read only the document relevant to the current task.

For a behavior change, define observable acceptance criteria and add or update a useful test before the implementation when feasible. Keep diffs focused and preserve unrelated user changes. Finish the requested implementation and verification before handing it back for review.

Use one Git worktree and branch per independent or concurrent task. Reuse that worktree when another session continues the same task. Read-only investigation does not require a worktree. Never remove another task's worktree or move its uncommitted changes without explicit direction.

For a complex feature, architectural change, or risky migration, create a living execution plan under `.agent/plans/` and follow [`.agent/PLANS.md`](.agent/PLANS.md).

Production deploys require an explicit user request. Prepare and verify the release first, then present the exact target, artifact, smoke checks, and rollback path at the deployment boundary.
