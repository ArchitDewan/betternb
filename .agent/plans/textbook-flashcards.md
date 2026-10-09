# Textbook flashcards

## Purpose and acceptance

Replace the Textbook Flashcards placeholder with a usable source-grounded review flow. A student can choose 5, 10, or 15 cards from the open PDF, generate a deck, reveal each answer, mark it “Again” or “Got it,” navigate cards, and see a completion summary. Missing sources, generation errors, and loading are visible. The active deck survives switching Textbook tabs but is not persisted or scheduled in this pass.

## Context

`TextbookWorkspaceView` owns the tool tabs and selected PDF. `CourseSourceStore` and `CourseStudyClient` call the Python course-study service, which owns PDF chunks and the model gateway. Quiz work is isolated in F018 and is not part of this branch; preserve it there.

## Plan

1. Add a source-scoped flashcard generation contract, model prompt, validation, and tests.
2. Add Swift client/domain types and a testable transient review store.
3. Build the Textbook Flashcards view using Lemma tokens, including setup, loading/error, review, and completion.
4. Run Python and Swift tests, build the macOS app, and inspect the final diff.

## Progress

- [x] 2026-10-09: Inspected Textbook placeholder, source index, model gateway, and worktree state.
- [x] 2026-10-09: Backend contract, source-scoped generation, citation/duplicate validation, and tests.
- [x] 2026-10-09: Native deck state, setup/review/completion view, and tests.
- [x] 2026-10-09: Python and Swift suites, signed app-bundle build, and diff check.
- [x] 2026-10-09: Refined the review UI after feedback: an animated, full-surface flip card, stronger front/back colors, direct card progress navigation, and simplified recall actions.

## Decisions and discoveries

- The open PDF scopes generation; absent a selection, all course sources are eligible. Every card references a provided source chunk.
- A study session is transient. “Again” and “Got it” are self-assessment labels, not proof of mastery or a persisted spaced-repetition schedule.
- Keep flashcards independent of uncommitted F018 quiz work. Both branches edit some shared boundaries and will need normal integration review later.
- Source excerpts are sampled across a long document instead of taking only its first pages. This is still a bounded sample, not full-document reasoning.
- The development app bundle is ad-hoc signed after assembly, matching the root checkout's uncommitted launcher repair so this worktree can run without a Launch Services failure.
- Card flips use a 3D turn with the face switched while edge-on; macOS Reduce Motion shows the new face without animation. The whole card is clickable and graded cards can be revisited from the progress strip.

## Validation

- `uv run pytest`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build-macos-prototype.sh`
- Manual: import a readable PDF, generate a deck, flip and grade cards, change tabs and return, and check a narrow Textbook pane.

Results on 2026-10-09: 48 Python tests passed (one upstream TestClient deprecation warning); 107 Swift tests passed; the macOS bundle built and `codesign --verify --deep --strict` succeeded; `git diff --check` was clean. The local `.env.local` is an ignored symlink to the root checkout. A different local tutor process was already listening on port 8082, so this turn did not replace it for a live-model UI smoke test.

After the visual refinement, 107 Swift tests passed again, the signed app bundle rebuilt and verified, and `git diff --check` stayed clean. The running Lemma instance exposed the sign-in gate, so a signed-in flashcard visual smoke test remains useful.

## Recovery

All edits stay in `feat/F019-textbook-flashcards`. There is no migration or persisted data; reverting this branch restores the placeholder.

## Outcome

The Textbook Flashcards tab now has source-grounded deck generation, flip/reveal, self-grading, navigation, and a session summary. The feature was committed on F019 and integrated with quizzes in F020; combined automated tests pass. Live-model visual review with a readable PDF remains useful.
