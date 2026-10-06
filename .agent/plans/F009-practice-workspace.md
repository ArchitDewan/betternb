# Practice workspace (auto-check, split feedback, sources rail)

## Purpose and acceptance

Practice becomes the working page from the landing mock: the student types a LaTeX or casual line, send grades it, the right rail shows a short first-break summary, and a longer explanation sits under the worksheet in a distinct tint. New Chat classifies the first message and opens Practice when it is a problem.

This is not F009B. Course PDF ingestion, problem generation from uploads, review scheduling, and flashcard generation stay later. The existing sidebar stays.

Slice 1 is accepted when:

- There is no Check step / Ask / Check toggle.
- Send on a written line (`u=\cos x`, `f'(x)=…`, `\[…\]`) is a check.
- Send on a question stays conversation and still appears on the worksheet.
- The inspector shows a short summary (verdict, error type, one or two sentences, cited source).
- The longer coach note is under the focused step, in a tinted block (the mock’s blue/indigo), not jammed into the inspector.
- Hint is one control that walks 1→2→3. Reveal stays explicit and still disappears after use.
- LaTeX in the composer still live-previews.

## Context

- Worktree: `/Users/architdewan/Desktop/projects/betternb-worktrees/F009-guided-math-tutor` on `feat/F009-guided-math-tutor`.
- Practice UI: `PracticeSessionView.swift`, `PromptComposer.swift`.
- Session + worksheet: `Tutoring.swift`.
- Tutor contracts: `services/tutor/src/betternb_tutor/contracts.py`, `providers.py`.
- Nav: `WorkspaceModels.swift`, `WorkspaceShellView.swift`, `SidebarView.swift`. Sidebar IA is intentionally not the marketing unit tree.
- Product invariants that must not regress: the student writes the next line; only SymPy awards `verified`; hints are a ladder; reveal is explicit; BetterNB owns retrieval; drafts survive failure.

The mock’s right rail also has a concept mastery bar and “scheduled for review in 2 days.” That needs `MasteryEvent` / Review (F013). Show the concept name now; do not fake a schedule.

## Plan

### Slice 1 — this worktree, next implementation

1. **Auto-check on send.** Remove the Check step capsule and the Ask/Check chips. Composer send uses the existing classifier: math/LaTeX/equation → `check_step`; `?` or informal prose → `chat`. First message with no problem still starts the problem.
2. **Split tutor output.** Add `summary` (short) next to `message` (long) on the tutor response. Inspector renders `summary` + error type + source. The focused step gets a tinted long note (`message`) under the row.
3. **Composer chrome.** One field. Live LaTeX/casual preview stays. Hint is a single button (advances the ladder, label shows the next level). Reveal stays, not as a tiny sibling chip row.
4. **Tests first.** Opening a problem still shows the tutor note on the worksheet. `u = cos 2x` send is `check_step`. “what should I do next?” is `chat`. Inspector note is the short summary; the long text is on the step, not the rail.

### Slice 2 — sources rail (shell now, ingest later)

Right rail under Step check:

- **Now:** list the sources the current check actually cited (title · section). A quiet “Add source” can exist as a disabled or local-file picker that does not change retrieval yet.
- **Later (F011):** upload lecture PDFs, list course materials, generate a Problems set from a marked page. Practice can then pick a generated item. That is not this slice.

Do not turn the rail into a second chatbot.

### Slice 3 — Study desk and slim navigation

The student should not choose an implementation category before beginning. **Study** is the course's primary surface: one composer automatically routes problems into the worksheet and course questions into conversation. It must not stop to ask the student which kind of input they entered. Back returns to the desk without erasing the attempt.

Global navigation is Home and Review. Course sources are shared context, reached from the Study desk rather than a separate Library destination. Problems remains a direct route to assigned work. Flashcards, Formula Sheet, and Canvas remain under a nested, collapsed Study Tools group until they contain useful generated artifacts. Search is secondary rather than a permanent destination.

PDF ingest remains F011. The Study desk does not expose a dead upload-material action before that capability exists.

### Later (do not start)

- Review countdown and mastery bars on the concept card.
- “Create flashcards for this topic” on the rail.
- Generate problems from uploaded sources.
- Durable attempts, account-backed courses, streaming.

## Progress

- [x] 2026-10-04: Write the plan from the landing mock and the current Practice/nav code. Wait for approval before Slice 1.
- [x] 2026-10-04: Pin IA: Practice is the do-surface; nav is the file-surface. Materials = course master. Rail upload = session packet → Problems. Problems = set, Practice = attempt.
- [x] 2026-10-04: Slim nav to Practice + Library + Review. New Chat always stays in Practice. Problems becomes an in-Practice picker.
- [x] 2026-10-04: Slice 1: auto-check on send, `summary` vs `message`, Check/Ask chips removed, one Hint + Reveal in the bar, tinted long note under the focused step.
- [x] 2026-10-04: Verify and fix Practice math pixels in the rebuilt app: mixed prose/math stays in one left-aligned flow, sentence spacing is repaired at renderer seams, composer assignments stay on one row, and checks do not shift the worksheet.
- [ ] Slice 2: cited-source list on the rail (no ingest).
- [x] 2026-10-05: Slice 3 navigation contract and Study input router covered by tests; Study/Problems shell implemented with automatic question-vs-problem routing, course sources moved into Study context, and Study Tools visibly nested under the course.

## Decisions and discoveries

- Auto-check is classification, not “everything is a grade.” A question must not become Step N.
- Short vs long is a contract field, not a client-side first-sentence split.
- The mock’s blue is the long diagnosis block and the concept accent, not a new chat column.
- One starting surface (Study), which can become a question thread or worksheet without a confirmation step. Problems and Review are not chatbots.
- **Course sources** are the course's master resources and future retrieval context. They are managed from Study, not presented as a separate place the student must understand before beginning.
- **Upload sources on the Practice rail** = a session packet (homework page, circled #35). Creates items you work *right there*. The problem *list* is a panel in Practice, not its own nav chat.
- Overview and Practice are folded into Study. Flashcards, Formula Sheet, and Canvas are progressively disclosed Study Tools nested under the active course.
- F009B / F011 / F013 stay deferred. A sources *list of citations* is in scope; PDF ingest is not.

## Validation

After Slice 1: `swift test`, `uv run pytest -q`, and a manual Practice pass: paste an integral, send `u=\cos 2x`, confirm the rail is short and the tinted block under the step is long, then send a question and confirm it is not a numbered step.

Math layout verification: `swift test` passes 76 tests; `uv run pytest -q` passes 32 tests with one existing Starlette deprecation warning; `./scripts/build-macos-prototype.sh` and `git diff --check` pass. The exact product-rule problem, live tutor prose, comma-separated composer preview, and post-check worksheet were visually inspected at default and minimum window sizes from the rebuilt `.build/BetterNB.app` executable.

## Recovery

All work stays on `feat/F009-guided-math-tutor`. No migrations. Revert the Practice/tutor contract commits if the split field needs to wait.

## Outcome

Slices 1 and 3 are implemented. The renderer-level math layout regression is fixed and verified. Source ingestion/retrieval and source-backed generation remain deferred to F009B/F011.
