# F022 and F023 integration

## Purpose and acceptance
Merge worksheet problems and student-created notebooks into main. Preserve unrelated uncommitted branding changes. Each account and notebook must have distinct persistent problems, attempts, and tutor sources; legacy Calculus I storage remains accessible.

## Context
Both feature branches start at 8e51b36. WorkspaceShellView and AuthenticationGateView conflict. F022 adds account-scoped storage while F023 adds per-notebook workspace caches.

## Plan
1. Commit feature work and combine in a persistent integration worktree.
2. Resolve workspace initialization with account-and-notebook-scoped storage, preserving legacy paths.
3. Verify Swift and Python tests, app packaging, and diff checks; merge into main.

## Progress
- [x] 2026-10-10: Committed both features and started integration.
- [x] 2026-10-10: Resolved authentication/workspace conflicts and verified storage isolation, Swift/Python tests, and app packaging.
- [x] 2026-10-10: Merged into main; all nine unrelated uncommitted files preserved byte-for-byte.

## Decisions and discoveries
Keep F022's legacy calculus-1 account hash and file paths. Other notebook IDs get their own account-scoped storage. Reset view identity on account and notebook switches.

## Validation
Storage regression tests cover legacy compatibility and account/notebook separation. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: 120 passed. `uv run pytest -q`: 59 passed, one existing Starlette deprecation warning. `./scripts/build-macos-prototype.sh`: passed. `git diff --check` and staged equivalent: passed. Feature plans retain their original default/minimum-window visual QA evidence; no fresh visual or live-model upload check was performed during this integration.

## Recovery
Feature commits remain on their original branches. Integration is isolated until checks pass. Revert the integration merge to recover main without deleting data.

## Outcome
Both features are combined with persistent state per account and notebook, legacy Calculus I paths preserved, and view identity reset on account/notebook switches. Integration checks passed. Merged into main. Original feature worktrees and integration worktree remain available; nothing was pushed.
