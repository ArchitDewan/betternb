# Textbook dual workspace

## Purpose and acceptance

Add a course-level Textbook destination where an uploaded PDF can stay visible beside a working area. In the first slice, a student can choose an indexed source, read its original pages, select or pin text with a page reference, quote a passage into the composer, and ask a grounded question without entering the Problems proof checker. Home presents study-tool previews and the working Ask Lemma composer; Chat holds the answers. Existing Study, Problems, and source import behavior must remain intact.

## Context

`WorkspaceDestination` and `WorkspaceShellView` own navigation. `CourseSourceStore` lists indexed PDFs but the Python tutor currently discards original bytes after import, so there is no reader endpoint. `CourseSourcesView` imports PDFs through `CourseStudyClient`; the new reader should use the same source IDs and course scope. The source service and app stores are currently in-memory, so this slice must not imply durable/offline access.

## Plan

1. Add a source-document read contract: retain uploaded PDF bytes in `CourseSourceIndex`, expose a scoped GET endpoint, and add a Swift client/store method. Test valid retrieval and unknown/cross-course IDs before implementation.
2. Add a `Textbook` course destination and a responsive dual-pane view. Left: source chooser, PDFKit reader, page count, selection capture. Right: Home/Chat workspace, pinned excerpts with source/page labels, and grounded question/answer using the existing course-answer service. Keep Problem practice separate.
3. Test selection/pin and question-context behavior in pure Swift where practical; build Swift and Python suites and inspect the native view at default and minimum window sizes.

## Progress

- [x] 2026-10-07: Inspected the existing source import path and created dedicated F014 worktree from merged main.
- [x] 2026-10-07: Source-document API and Swift client/store contract, tested across course scope.
- [x] 2026-10-07: Textbook sidebar destination, PDFKit reader, selection pinning, notes, and grounded Q&A.
- [x] 2026-10-07: Automated suites and inspectable app bundle; visually inspected the empty-state dual pane at the normal window size.
- [x] 2026-10-07: Follow-up visual pass: removed opaque full-canvas fills from Textbook, Problems, Practice, and Course Workspace so they inherit the shared shell glass; Textbook notes, pins, and composer now reuse the existing glass component.
- [x] 2026-10-07: Paper-inspired Textbook organization: Home/Chat/Summary/Flashcards/Quiz tool strip, colored study-tool cards, and a direct PDF-selection-to-chat quote with source/page attribution. Pages and Podcast intentionally omitted. Summary, Flashcards, and Quiz are labeled previews, not fabricated generators.
- [x] 2026-10-07: Replaced the Home notes editor with the same working Ask Lemma composer used in Chat, docked to the bottom of the right pane. Sending from Home opens Chat for the answer.
- [ ] Live PDF import/selection smoke test with tutor service running, plus minimum-window inspection.

## Decisions and discoveries

- Textbook is a per-course destination, sharing existing indexed PDFs instead of creating a second upload silo.
- The first slice handles selectable PDF text. Scanned pages and geometric figures remain visible but cannot yet become structured pins; OCR/region capture is later work.
- The scratchpad is for exploration and reference-grounded questions, not proof-step verification. Pinned excerpts are explicitly included as context only when the student chooses them.
- The shell already applies `lemmaGlass` to the detail column and sidebar. Opaque child backgrounds, not a missing glass modifier, caused Textbook and several other destinations to look flat. Full-canvas layers are now transparent, while discrete controls keep contrast.
- Future independent milestones: durable source/notes/threads; handwriting-to-LaTeX; code/SymPy cells; interactive graphs; flashcard and quiz artifacts. Avoid fake controls for these until they function.
- Paper's site and the user screenshot informed the source-left/tools-right hierarchy; its linked MP4 did not load through the web tool. The F014 treatment uses Lemma's own graphite glass and semantic tool accent colors rather than replicating Paper's light palette.
- The user preferred immediate textbook Q&A over a notes editor on Home. The scratchpad store now holds question/quote/pin state only; note-taking can return as a dedicated future tool rather than competing with the composer.

## Validation

Completed: targeted API and Swift tests; `uv run pytest` (39 passed, one existing Starlette/httpx deprecation warning); `swift test` (102 passed after the Home-composer change); `build-macos-prototype.sh` (passed after the Home-composer change); `git diff --check` (passed). The user visually confirmed the glass Textbook Home/tool-strip layout before the composer replacement. Automated API tests cover 200 PDF response and 404 for cross-course/unknown IDs. The new bottom-docked composer still needs visual confirmation after restarting the app; live PDF selection and minimum-window inspection also remain.

## Recovery

No migration in F014. Work remains isolated in `feat/F014-textbook-workspace`; the user authorized committing and pushing this branch, but not merging it. Preserve F012 and F013 worktrees. A later persistence milestone must replace the in-memory document cache before shipping beyond the prototype.

## Outcome

First functional slice is implemented and isolated for review. The dual workspace is present, but it is not yet the complete vision: no image/region pinning, handwriting recognition, code cells, graphs, generated flashcards/quizzes, or durable storage. The branch is ready for the user-requested commit and push; no merge is planned.
