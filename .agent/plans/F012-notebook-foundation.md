# Notebook and Problems foundation

## Purpose and acceptance

Build course notebooks that retain materials, grouped problems, and independent Practice histories. Importing a PDF must provide context, not create problems. Generation is explicit and reviewable. The completed initiative supports notebook create/rename/Trash/restore, topic/problem-set organization and CRUD, three recent attempt shortcuts with all older attempts retained, source add/delete with preserved historical citations, and restart-safe data.

## Context

At `a5fb716`, `WorkspaceShellView` and `SidebarView` hard-code Calculus I. `ProblemSetStore`, `TutorSessionStore`, and course-source indexing are in memory. The source sheet explicitly generates three problems, but immediately saves all of them. `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, and `docs/MATH-NOTEBOOK.md` describe the local-first direction.

## Plan

1. **F012 (this worktree):** In the current notebook, add editable problem groups and problem edit/move/delete. Convert generated problems into drafts with edit/select/save/discard. No persistence claim yet.
2. **Durable notebooks:** Add local SQLite repositories for notebooks, topics, sets, problems, and attempts; dynamic sidebar; create/rename/Trash/restore; seed Calculus I. Use ordered topics before nested folders. AI may suggest a roadmap only with user approval.
3. **Attempt history:** Key Practice transcripts by attempt ID; show three newest per notebook, retain/search older ones. Bind async responses to the correct attempt. Preserve historical prompt revisions.
4. **Materials:** Persist PDF files and source indexes; view/rename/delete; notebook-scoped retrieval in Study and Practice. Deleting a source removes file/index, not derived work; show unavailable-source citations. OCR later.
5. **Generation:** Explicit topic/source/count/difficulty/style controls, validation, draft review, save selected. No auto-generation on import. Keep existing endpoints compatible during migration.

Use separate task worktrees for later milestones; do not implement them speculatively in F012. Account sync is later.

## Progress

- [x] 2026-10-06: Inspected current app and selected bounded F012 slice.
- [x] 2026-10-06: Added failing tests for group/CRUD behavior and draft review; implemented the F012 model and SwiftUI controls.
- [x] 2026-10-06: Full Swift suite passed (91 tests) and `swift build` passed with full Xcode selected only for these commands.
- [x] 2026-10-06: Following screenshot feedback, generated questions are now automatically filed in a collapsible folder named from their source PDF; new regression tests first failed for missing/misleading behavior, then passed.
- [x] 2026-10-07: Following visual feedback, replaced the inline folder list and pinned bottom problem form with a folder browser, breadcrumb navigation, and a top New menu. Draft review uses rendered math with an explicit Edit control and live preview.
- [x] 2026-10-07: Following a live screenshot, corrected root content alignment and constrained all Problem-browser menus to intrinsic width; widened folder tiles and gave titles two lines so counts no longer wrap beneath a squeezed label.
- [x] 2026-10-07: Added in-memory Study threads for Practice problems and course questions. The sidebar shows three recent threads with short topic labels, `All threads` exposes older ones, and switching preserves each transcript and unsent draft. A late tutor reply stays with its originating thread.
- [x] 2026-10-07: Fixed sidebar thread ordering: opening a thread changes only selection, while creating a new thread adds it to the top. The three visible shortcuts are the three newest-created threads.
- [x] 2026-10-07: The Lemma visual redesign moves those three shortcuts from the global sidebar into the Study course home, with View all for older threads. Thread storage and stable creation order are unchanged; see `F012-lemma-visual-redesign.md`.
- [ ] Later: Persist the thread store/attempts across app relaunch and replace heuristic topic labels with editable or model-assisted summaries.
- [ ] Later: Durable notebooks, attempt history, materials, expanded generation.

## Decisions and discoveries

- One notebook equals one course. Three recent sessions are shortcuts, not a retention limit.
- AI topic suggestions require approval. Generated problems are editable drafts before saving.
- Source import is context-only. Source deletion must leave problems/attempts/history intact.
- Notebook deletion is recoverable through Trash.
- F012 remains in-memory; this is a deliberate interim limitation.
- Removing a group moves its problems to Inbox. Editing a problem keeps its ID/source citations. Generated drafts are held only in the Sources sheet and disappear when it closes unless saved.
- User feedback showed generated questions from one assignment PDF all landing in Inbox. F012 now creates/reuses a source folder **when reviewed questions are saved**, not when the PDF is imported. The display title expands common filename tokens (`A1` and `prac`), but this is filename-based and not semantic document understanding. The source filename is retained on the folder so a user rename does not break reuse.
- If a generated question cites multiple distinct PDFs, it goes in `Mixed Course Sources` rather than being falsely attributed to the first PDF. Source-specific generation controls belong to milestone 5.
- Raw LaTeX in the draft-review screenshot came from presenting the prompt in `TextField`, not from the math parser. The default draft card now uses `TutorMathText`; editing still exposes raw markup intentionally and shows a rendered preview.
- A packaged F012 app build succeeded on 2026-10-07. Starting a second GUI instance with `open -n` failed with macOS launchd `RBSRequestErrorDomain Code=5`; the user's running F012 app was not restarted because doing so would discard in-memory questions. Manual visual QA of this specific binary remains for the next launch.
- The next screenshot exposed `.borderlessButton` menus stretching to fill available HStack width (one chevron at the far right, one occupying most of a folder tile) and a centered outer frame leaving an excessive left gutter. The 2026-10-07 padding correction applies `.fixedSize` and hides menu indicators, left-aligns the body within the detail pane, and increases folder tile breathing room.
- A Study screenshot showed only one `Continue current problem` row containing raw LaTeX. New threads live under the Study row in `SidebarView`; the desk no longer shows that row. `StudyThreadStore` retains every in-memory thread and limits only the sidebar shortcuts to the three newest-created threads. Opening a thread does not reorder the list. Titles are local keyword summaries such as `Complex limits`, not a model-generated title; unrecognized prompts currently fall back to `Practice problem` or `Course question`.
- `PracticeSessionView`'s old New problem button called `tutor.reset()` and would have destroyed a saved thread. It now returns to the desk, where the next start creates a fresh tutor instance. Both Practice and course-conversation composers store unsent drafts in their respective session objects. `CourseSourceStore.answer` now permits two concurrent course-thread answers instead of rejecting the second.

## Validation

- F012: Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` and `swift build`; manually inspect problem grouping and draft review when possible.
- F012 evidence after the 2026-10-07 UI change: 94 Swift tests passed (including a representative generated LaTeX prompt), and the packaged app build passed. Manual UI walkthrough of the updated binary remains open as noted above.
- F012 evidence after the padding correction: 94 Swift tests passed, the packaged app build passed, and `git diff --check` passed. The corrected screenshot still needs user/live-app confirmation; do not claim visual acceptance from the build alone.
- F012 evidence after Study-thread work: 98 Swift tests passed, including four-thread recency, transcript/draft restoration, delayed response routing, and concurrent course answers; packaged app build passed. The sidebar layout still needs a live screenshot on the next app launch.
- Later: Test two-notebook isolation, restart-safe attempts and PDFs, four attempts with only three shortcuts, deleted-source retrieval removal with intact history, and Trash restore.

## Recovery

F012 has no migration. Its model/UI changes can be reviewed or reverted independently. Future persistence requires additive versioned migrations and a backup/recovery path before destructive changes. Preserve all unrelated worktrees.

## Outcome

F012 delivers the current Calculus I Problems screen as a folder browser with Inbox, folder rename/delete, problem add/edit/move/delete, and a PDF generation review stage where selected prompts are rendered as math and can be edited before saving. Saved questions from the same source PDF automatically share a folder. Importing a PDF remains independent of generation. Study now has independent Practice and course-question threads, three recent sidebar shortcuts, and an All threads list. **All of this remains in memory**: app relaunch loses folders, problems, sources, and threads; there is still only one hard-coded course. No schema or API was changed. Future agents should begin at `WorkspaceShellView`/`StudyThreadStore` for notebook/attempt ownership, `ProblemSetStore` for the interim problem model, and the Python course-source index for material persistence. Continue with durable notebooks and attempts before representing these controls as restart-safe.
