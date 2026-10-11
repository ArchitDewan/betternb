# F025 Review roadmaps and Resources

## Purpose and acceptance
Review lists notebooks and opens editable unit/topic roadmaps generated from selected Resources. Students approve drafts, track status manually, save topic flashcards/problems, and start guided practice. Resources owns uploads. All saved work survives relaunch and stays account/notebook scoped.

## Context
Based on main 685d04f. Reuse CourseSourceIndex, CourseStudyClient, ProblemSetStore and StudyThreadStore. Preserve unrelated main changes and the concurrent F024 worktree.

## Plan
1. Test and implement source-grounded roadmap/topic generation.
2. Test and implement persistent roadmap, flashcard, category and activity models.
3. Build Resources, Review, editing and topic study flows; connect existing practice.
4. Verify Python/Swift suites, packaging, default/minimum window UI, and final diff.

## Progress
- [x] 2026-10-10: Created persistent isolated worktree.
- [x] Backend contracts, provider implementation and source-scoped generation: 62 Python tests pass.
- [x] Persistent roadmap/card/category/activity model: initial Swift suite 123 tests passed before UI wiring.
- [x] Resources, roadmap editor, topic material screens and notebook/practice navigation implemented.
- [x] Automated verification and bundle build passed.
- [ ] Complete default/minimum-window visual workflow: blocked by Computer Use approval denial; see Validation.

## Decisions and discoveries
Manual status: Not started, In progress, Reviewed. No mastery estimation or spaced scheduler. Uploaded documents are untrusted reference material. Existing source IDs and storage remain compatible. Removed topics detach materials; regeneration requires approval. Keep long text PDF ingestion separate from scanned worksheet OCR.

## Validation
- Initial backend regression tests failed (3 failures) before implementation; complete final `uv run pytest -q`: 65 passed, one existing Starlette deprecation warning.
- Final `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: 128 passed in 13 suites.
- `./scripts/build-macos-prototype.sh`: passed; artifact `.build/BetterNB.app`.
- `git diff --check`: passed.
- Regression coverage includes full-document roadmap coverage, citation validation, selected-resource isolation, API errors/provider requests, roadmap editing/reload, corrupt-file protection, legacy problems, topic detachment, activity persistence and source-page routing.
- Native UI accessibility inspection in a uniquely identified QA bundle verified Home/Review/Resources navigation, Review overview and empty state, primary-source selection, and generated editable roadmap using a local fixture server (no live model calls).
- Editing/saving through UI was rejected with `Computer Use was not approved to use Lemma`. Subsequent read-only UI inspection was also rejected. Screen capture initially failed with ScreenCaptureKit error -3811. No completed screenshot/layout verification or minimum-window check is claimed. Live-model roadmap quality, real file-picker uploads, and the remaining full UI workflow require manual smoke checks.
- Main's nine unrelated uncommitted files remain byte-for-byte unchanged.

## Recovery
New local files are additive; no migrations or deletion of existing user files. Leave changes uncommitted for review.

## Outcome
Implemented in `feat/F025-review-resources`; left uncommitted for review. Resources owns uploads, and Review provides persistent editable course roadmaps, manual topic status, saved flashcards/problems and guided-practice routing. No automatic mastery/spaced scheduling, global library, or cloud sync.

Start review at `macos/BetterNB/Features/Workspace/CourseReviewView.swift`, then `Domain/CourseReview.swift` and `services/tutor/src/betternb_tutor/course_study.py`. New API: POST `/v1/courses/{course_id}/roadmaps`; existing problem/flashcard routes accept paired optional `topic` and `source_ids`. Existing requests remain valid.

## Remaining QA handoff
Worktree and branch above contain all changes. Final logs: `/tmp/f025-swift-final.log`, `/tmp/f025-python-final.log`, `/tmp/f025-bundle-final.log`. Native QA used isolated `/tmp/f025-qa-data` and a fixture server on port 8089. No commits, pushes or merges were requested or performed. When UI access is available, verify at default/minimum sizes: upload resources; generate/edit/approve roadmap; create and review a saved flashcard set; generate/save problems; start practice and return to topic; relaunch and switch notebooks; remove a topic and confirm materials remain. Do not rerun `/tmp/f025-*.py` implementation helper scripts blindly.

## 2026-10-11 UI revision
User requested removal of the Resources channel and visual alignment with Textbook. Removed the library destination from sidebar/search, retaining materials in a sheet from existing screens. Review now uses shared Lemma typography, hairline cards, colored tool tiles, status chips and numbered unit badges. Saved-card review reuses Textbook flashcard gradients. Verification: 128 Swift tests pass; app bundle build and git diff --check pass. Minimum-window QA bundle launched with .env.local loaded and isolated test storage. Computer Use rejected access (`Computer Use was not approved to use Lemma`), so revised layout at default/minimum sizes remains visually unverified.

## 2026-10-11 Control-system correction
User screenshots identified native gray/beveled buttons, expanding menu bars, stock popup pickers, and oversized selection sheets. Added an explicit UI control rule to AGENTS.md and shared LemmaButtonStyle/LemmaMenuLabel/input treatment in DesignSystem/LemmaControls.swift. Applied styles across Review, materials, editors and preview sheets; WorkspaceShellView provides a styled fallback. Replaced category pickers with compact menu triggers. Source selection now uses selectable file rows and an inline Primary action, auto-selecting the first chosen file; sheet height follows file count. Removed the separate primary-source picker and reduced the materials sheet to 740×440. No data/schema changes.
Validation: 128 Swift tests pass, app bundle build passes, git diff --check passes. Source audit found no bordered/default pickers in the revised Review/materials screens. Full visual verification remains unavailable due to the previously reported Computer Use denial. Changes remain uncommitted in the F025 worktree.


## Scope correction: simple Review

User requested only upload materials and generate review, with an outline/lecture-slide recommendation. Replaced the Review setup and topic-tool flows with direct multi-PDF upload and automatic generation/save displayed inline. Course cards have one navigation action. Review no longer presents source/category/primary selectors, editors, statuses, practice, or flashcards. Existing stored data are preserved. The shared custom-control rule remains in AGENTS.md.

Acceptance: two main actions; upload multiple PDFs directly; generate from all course materials (maximum 20); automatically prefer outline/syllabus; show generated units/topics inline; keep the previous review on failure. API accepts 20 sources and bounds combined page excerpts to 400,000 characters while retaining every page. New contract tests failed before implementation. Swift tests: 128 passed. Final verification: 67 Python tests passed (existing Starlette deprecation warning), 128 Swift tests passed, app bundle build passed, and `git diff --check` passed. Live UI inspection resolved to an already-running older app, so the new screen has not been visually verified at default/minimum sizes.


## Final delivery correction

Problems now contains only its heading, In progress badge, and placeholder message; all internal controls and lists have been removed from the screen. Stored problems remain intact. User explicitly requested merge and push. The native UI rules live in macos/AGENTS.md so main's unrelated, uncommitted root AGENTS.md branding correction remains untouched. The final Review scope above supersedes the earlier editor/tool implementation notes.

Final delivery validation: 128 Swift tests and 67 Python tests passed; inspectable app bundle built successfully; diff whitespace check passed. Visual inspection of the current binary remains unverified.
