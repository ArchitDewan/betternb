# Textbook summary and Home conversation

## Purpose and acceptance

- Summary generates a concise overview and source-linked key ideas for the selected readable PDF, with loading, empty, and retry states.
- Changing PDFs does not show the previous PDF's summary as current.
- Textbook Home keeps its tool cards stationary while only the complete conversation below them scrolls. The cards are never hidden by a fixed-height crop. Chat shows the same exchanges.
- An “Add to Chat” PDF quote remains visible with its sent question; it is removed only from the composer so the next question does not reuse it accidentally.

## Context

`TextbookWorkspaceView` owns the Home/Chat/summary tabs. `CourseSourceStore` calls the Python tutor through `CourseStudyClient`; other generated study tools provide the API and UI pattern. The root checkout contains unrelated uncommitted branding/launcher edits, so this task uses F021.

## Plan

1. Add source-grounded summary contract and service/API tests.
2. Add Swift client/store and Summary view.
3. Replace Home's nested latest-exchange scroller with a full-history conversation scroller below stationary tools; retain the sent quote on its exchange.
4. Run Python and Swift tests, build the app, review diff.

## Progress

- [x] 2026-10-09: Summary service and tests.
- [x] 2026-10-09: Swift summary experience.
- [x] 2026-10-09: Initial fixed-height split clipped cards; a follow-up whole-page timeline scrolled the tools too. Home now holds the tools stationary and gives remaining height to the conversation scroller. Sent quotes remain on exchanges and their outer message border is removed.
- [x] 2026-10-09: Automated verification and diff review. Signed-in visual smoke test remains.
- [x] 2026-10-09: Refined Summary setup after user review: compact source metadata, editorial reading-guide copy, lighter action, no oversized enclosing card. Fixed the generated summary page-count caption.

## Decisions and discoveries

- Summaries are generated from sampled chunks of the selected PDF, not a claim to have exhaustively read every page. Each key idea cites one excerpt.
- Summary state is transient, like quiz and flashcards; no persistence or migration.
- The F021 checkout does not contain main's uncommitted local-account bypass. Its built app reached the sign-in gate, so signed-in visual inspection must be done by the user or after separately integrating that unrelated local setup.
- The fixed-height split cropped the tool grid, while one whole-page ScrollView moved the tools when reading chat. The final layout keeps the grid at intrinsic height outside the only vertical chat scroller.
- The task worktree's ad-hoc-signing edit to `scripts/build-macos-prototype.sh` duplicates a signing change already present as uncommitted work in the root checkout. Keep that script edit out of the F021 feature commit so merging preserves the root's app-name and signing changes.

## Validation

- `uv run pytest -q`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build-macos-prototype.sh`
- Manual: source switch, summary generation, long Home chat scroll, Chat tab continuity, sent PDF quote visibility, normal/narrow window.

Results on 2026-10-09 after the UI refinement: 55 Python tests passed (one upstream TestClient deprecation warning), 111 Swift tests passed, app bundle built and passed `codesign --verify --deep --strict`, and `git diff --check` was clean. The user supplied signed-in screenshots of Home and Summary; the final Summary styling remains useful to inspect in the app.

## Recovery

The feature changes are isolated on F021 until integrated. Reverting the feature commit restores the Summary placeholder and earlier Home layout. No data migration. The worktree-only signing change is intentionally excluded from that commit because the root checkout already has its own uncommitted signing and app-name changes.

## Outcome

Summary now generates cited key ideas for the selected PDF with retry and source-switch reset. Home keeps its tool cards fixed, with the complete conversation scrollable beneath them and the composer fixed below; Chat shares the history. Sent PDF quotes remain visible on their corresponding questions without an outer message border. The signed-in UI smoke test remains.
