# F022 — Worksheet problems

## Purpose and acceptance

Problems is the course's saved problem set. A student can upload a text or scanned PDF, PNG/JPEG/HEIC worksheet, review extracted questions, generate new related questions from that worksheet, add a question manually, and open any saved question in the Study Practice worksheet. Saved work and attempts survive relaunch.

## Context

`ProblemSetView` is folder-first and in memory. `CourseSourcesView` imports text PDFs and generates three questions from all course sources. `WorkspaceShellView` starts a fresh `TutorSessionStore` each time a card opens. The tutor source index is also in memory. Keep generated and transcribed questions as drafts until the student reviews them.

## Plan

1. Add source-scoped worksheet extraction and generation to the tutor API; support text pages, scanned pages, and images with page provenance. Persist course uploads and rebuild the index on restart.
2. Add native upload, extraction, generation, and draft review to a list-first Problems screen. Keep source import in the existing Sources view as well.
3. Link saved problems to Practice attempts; resume the latest or start another. Add explicit save for ad hoc Practice, manual Done, and local persistence of problems and attempts.
4. Verify backend and Swift contracts, builds, and default/minimum-window visual layout.

## Progress

- [x] 2026-10-09: Inspected current source, set, and Practice routes; created isolated F022 worktree.
- [x] 2026-10-09: Backend worksheet ingestion, extraction, generation, and persistence.
- [x] 2026-10-09: Problems UI and Practice linkage/persistence.
- [x] 2026-10-09: Python and Swift tests, app bundle build, and default/minimum-window visual inspection.

## Decisions and discoveries

- Uploaded source text is untrusted reference data. Extracted/generated questions require review before save.
- "Generate" creates fresh problems with similar methods and difficulty; "Import questions" captures existing questions.
- No backend account sync; local course data and tutor source IDs are scoped to the current account's Calculus I course.
- Native file pickers in the direct-run visual test did not enable Open for a selected synthetic PDF or PNG, including the pre-existing Course Sources picker. Import behavior was verified through service/API tests and the native attachment path remains covered by compilation. A full UI import with a real model service remains unverified.

## Validation

- `uv run pytest -q`: 59 passed; one existing Starlette deprecation warning.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: 115 passed.
- `./scripts/build-macos-prototype.sh`: passed.
- `git diff --check`: passed.
- Inspected Problems empty state, saved card, Practice navigation, and minimum-window layout in the running app. The native file picker prevented a live upload in this direct-run test.

## Recovery

New local storage is versioned and additive. Existing in-memory state has no durable migration source. Keep the F012 worktree untouched; F022 can be revised independently before merge.

## Outcome

Problems now opens as a saved-question list with a worksheet section. Students can import existing questions or generate new ones from a chosen worksheet, edit/select drafts, add manually, and resume or restart Practice. Local sets, attempts, and tutor source data survive relaunch. Live model output and file-picker upload still need a user-environment smoke check.
