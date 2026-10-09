# Textbook quizzes

## Purpose and acceptance

Turn the Textbook Quiz preview into a usable course-grounded multiple-choice quiz. A student can choose Easy, Standard, or Challenging and 3, 5, or 10 questions, generate a quiz from imported course PDFs, select one of four options per question, and see the correct answer and explanation immediately by default. Turning off “Reveal after each answer” defers feedback until the student submits the quiz. A completed quiz shows the score. Errors and missing sources are visible without discarding setup choices.

## Context

`TextbookWorkspaceView` owns the Textbook tool tabs. `CourseSourceStore` and `CourseStudyClient` bridge to the Python tutor service. The tutor service indexes imported PDF chunks through `CourseSourceIndex`; its model gateway uses structured OpenAI responses. Quiz state should remain local and transient in this first pass, like the current textbook conversation.

## Plan

1. Add a versioned quiz generation request/response and a course-grounded model method, with validation of question shape and answer index.
2. Add Swift client/domain quiz types and a testable quiz session store for immediate and deferred reveal.
3. Replace the Quiz preview with setup, loading/error, answering, and result states using existing Lemma design tokens.
4. Run focused and full Python/Swift checks, build the app bundle, and inspect the diff.

## Progress

- [x] 2026-10-08: Inspected the Textbook tab and course-source service; chose multiple choice with four options.
- [x] 2026-10-08: Backend contract, source-scoped generation, shape validation, and tests.
- [x] 2026-10-08: Native client, quiz session state, and tests for both reveal policies.
- [x] 2026-10-08: Quiz setup, question, feedback, and result UI.
- [x] 2026-10-08: Automated checks, app bundle build, and diff check.
- [x] 2026-10-09: Reworked quiz setup after visual review: direct-select difficulty and length, clearer source status, a compact answer-reveal switch, and a single primary action.

## Decisions and discoveries

- “Reveal after each answer” defaults on. With it off, choices remain editable until `Submit quiz`; answers and explanations then appear together.
- Difficulty and length are chosen before generation. Regenerating starts a new transient session; there is no persistence or mastery update in this pass.
- Generated answer keys are model output, not independently verified mathematics; the quiz UI must not imply deterministic proof checking.
- Quiz generation uses the currently selected PDF when one is open. This keeps the quiz aligned with the left-hand reader; the backend also supports course-wide generation when no source is specified.
- The task worktree includes post-assembly ad-hoc signing of its development app bundle, matching the root checkout's uncommitted launcher repair. Otherwise the quiz build may fail to launch even though it compiles.

## Validation

- `uv run pytest`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build-macos-prototype.sh`
- Manual: with a readable PDF, generate each size/difficulty; answer once with immediate feedback and once with deferred feedback; inspect loading, missing-source, and failure states at normal/minimum window widths.

Automated results on 2026-10-08: 48 Python tests passed; 108 Swift tests passed; app bundle built and passed `codesign --verify --deep --strict`; `git diff --check` clean. A local `.env.local` symlink is now present in the worktree; manual live-model inspection with a readable PDF remains useful.

After the 2026-10-09 setup refinement, `swift test` passed (108 tests) and the macOS app bundle rebuilt successfully. Visual review at normal and narrow Textbook pane widths remains useful.

## Recovery

All changes remain isolated on `feat/F018-textbook-quizzes`; no migration or persisted data is involved. An interrupted implementation can resume from this plan. Reverting the branch restores the Quiz placeholder.

## Outcome

The requested quiz flow is implemented in the isolated F018 worktree. Remaining: human visual/interactive smoke test with a real indexed PDF and live model response, then decide whether to commit/merge. No data migration is needed.
