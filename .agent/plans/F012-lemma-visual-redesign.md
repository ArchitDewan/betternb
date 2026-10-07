# Lemma visual redesign

## Purpose and acceptance

Make the existing macOS app feel like a calm mathematical learning workspace without changing its service contracts, problem models, or routing. Acceptance for this visual pass: a neutral charcoal default with a coordinated warm light variant; a course home led by current study work rather than a giant composer; quieter navigation; a dedicated editorial tutoring surface; usable controls at the default and minimum window sizes; all existing Study, Problems, source, and Practice actions remain reachable.

## Context

This work continues in `feat/F012-problem-organization` at the user's direction because the currently used Problem folders and Study threads are uncommitted there. Existing screen entry is `WorkspaceShellView`; `AppTheme` previously forced a near-black palette and `BetterNBApp` forced dark appearance. The F012 data is still in memory. Do not restart the user's running app solely for visual QA, because that would discard its unsaved folders, problems, sources, and threads.

## Plan

1. Introduce semantic `LemmaColors`, typography, spacing, radius tokens, and reusable study components. Keep compatibility aliases for existing views.
2. Make Study a course workspace: real latest thread, saved-problem and source counts, study actions, a quieter composer, and recent threads with an all-threads route. Do not display fabricated mastery or activity.
3. Keep the sidebar calm while showing three recent, specifically named Study threads directly beneath Study; preserve access to all older threads.
4. Restyle the tutoring conversation and Practice surfaces as reading/working spaces, leaving answers and tutor behavior unchanged.
5. Apply tokens to Home, Problems, source review, sign-in, and placeholders. Verify build/tests, then inspect both window sizes when a separate safe app instance is possible.

## Progress

- [x] 2026-10-07: Read current SwiftUI routes and adopted dynamic warm-light/charcoal-dark semantic tokens. The app defaults to light, with a native Appearance menu for Dark or Follow System.
- [x] 2026-10-07: Added reusable study action, section header, equation block, and restrained layered-knowledge motif.
- [x] 2026-10-07: Rebuilt Study around a real continuation thread, practical shortcuts, source count, recent threads, and a compact Ask Lemma composer.
- [x] 2026-10-07: Simplified sidebar to Home/Review, courses, and study tools. Older threads remain available in Study via View all.
- [x] 2026-10-07: Restyled the dedicated course conversation with a reading-width heading, editorial response treatment, and follow-up prompt chips. Refreshed global Home and the top bar.
- [x] 2026-10-07: Inspected a disposable preview app at the minimum and default window sizes, plus its dark appearance and light Problems screen. The first minimum screenshot revealed that four equal action cards pushed the composer below the fold; changed them to a compact action strip and verified the composer is visible. The user's first F012 instance and in-memory data were untouched.
- [x] 2026-10-07: After reference feedback, made neutral charcoal the default, adjusted its surfaces and text toward the supplied dark UI reference, and kept Light/Follow System available in the Appearance menu.
- [x] 2026-10-07: Restored the three newest thread shortcuts beneath Study after user feedback. Clicking one does not reorder the list. Thread titles now use the question's topic or expression, with readable math and a bounded length rather than a generic “Practice problem” category.
- [ ] Further refine Practice worksheet, Problems, source sheet, sign-in, and nonfunctional study-tool placeholders after visual feedback. The shared tokens already change their base palette.

## Decisions and discoveries

- Dark mode now defaults to neutral charcoal, with restrained indigo-lavender accents and soft surface separation; it is not a return to the original pure-black dashboard. The Appearance menu offers Light and Follow System as alternatives.
- There is no stored mastery score, due-review list, saved formula count, or meaningful concept model yet. The redesigned course home uses only actual threads, problem count, and source count; it does not invent those metrics.
- The user clarified that three recent threads should remain visible directly below Study in the sidebar as well as on the course home. The thread order remains stable on selection, and all threads are still retained in memory. Titles are generated locally from the initial question; this does not add an AI titling service or change tutoring APIs.
- Tutor responses are displayed with improved hierarchy, but this pass does not rewrite or fabricate explanations. Future structured tutoring sections should use real structured response data rather than visual guesses.
- Existing destination placeholders remain placeholders. The redesign does not imply Flashcards, Formula Sheet, or Review functionality is complete.

## Validation

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` succeeded after the shared theme, Study, sidebar, and conversation changes.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --quiet` passed: 98 tests in 7 suites.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build-macos-prototype.sh` passed and produced `.build/BetterNB.app`.
- `git diff --check` passed. A disposable `.build/LemmaVisualPreview.app` copy with a distinct bundle ID enabled live visual inspection without closing the user's F012 app. The revised Study screen fit at minimum size, default-size spacing was intentional, and the charcoal dark appearance was checked. Problems was inspected in its empty state; populated Problems, source review, Practice, and sign-in still need visual QA when representative data is available.
- After changing the default to neutral charcoal, 98 Swift tests, the packaged app build, and `git diff --check` passed again. A separate minimum-size preview confirmed the revised charcoal colors and readable surface hierarchy; the disposable preview process was closed without touching the user's running app.
- After restoring sidebar threads and specific local titles, `swift test --quiet` passed 99 tests in 7 suites, `build-macos-prototype.sh` built the app bundle, and `git diff --check` passed. The title tests cover complex limits, roots, differentiation, integration, mappings, arithmetic, image-only input, and stable recency order. The running user instance was not restarted, so its in-memory threads were preserved; reopen with the new build to see the sidebar change.

## Recovery

No migrations or external API changes. This is an uncommitted F012 worktree; preserve it as-is. Revert visual files independently if needed, retaining the existing Problem/Study behavior work. Do not merge or push without an explicit request.

## Outcome

The first cohesive visual pass is implemented in F012. It changes presentation and access paths, not tutor services or persistence. Subsequent sessions should begin visual review at `DesignSystem/AppTheme.swift`, `DesignSystem/LemmaComponents.swift`, `StudyDeskView.swift`, `SidebarView.swift`, and `ChannelConversationView.swift`.
