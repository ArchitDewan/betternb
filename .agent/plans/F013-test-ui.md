# F013 test UI

## Purpose and acceptance

Give Lemma’s Study home and shared navigation the reference’s quiet, layered depth. Success looks like a near-black central canvas (`#191A1B`) with a slightly lighter matte sidebar (`#222324`), a top bar that stays with the canvas, and faint dividers instead of filled panels. The Continue Learning card becomes an editorial continuation on the canvas, study shortcuts stay compact, and the duplicate Recent study cards are gone. Sidebar thread shortcuts, their order, and All threads access stay. Lavender is a small accent. Light appearance uses the same layering. Tutor logic, thread data, Problems behavior, and persistence stay unchanged.

## Context

This experiment is a copy of the uncommitted F012 worktree. F012 itself is not edited. Worktree: `/Users/architdewan/Desktop/projects/betternb-worktrees/F013-test-ui`. Branch: `feat/F013-test-ui`. “Hollow” means low-contrast matte layers, not macOS translucency. Entry is `WorkspaceShellView`; Study home is `StudyDeskView`; shared planes live in `LemmaColors`.

## Plan

1. Shift semantic colors to matte canvas, sidebar, top bar, divider, and a single elevated composer surface.
2. Replace the continuation card and recent-thread cards with open editorial type and one action.
3. Tighten sidebar rows and replace the lavender selection fill with a soft neutral.
4. Inspect Study at the default and minimum window sizes in dark and light, then run Swift tests and the macOS app build.

## Progress

- [x] 2026-10-07: Copied F012’s uncommitted state into `F013-test-ui` without modifying F012.
- [x] 2026-10-07: Applied matte tokens, editorial Study home, compact study shortcuts, and quieter sidebar and top bar.
- [x] 2026-10-07: Inspected the running F013 Study view at its default size and a separate minimum-window preview in dark and light. Fixed the glass composer's faint native placeholder with an explicit, accessible label; verified typing enables Send and clearing disables it.

## Decisions and discoveries

- The top bar uses the canvas color plus a hairline so it does not become a third flat block. Depth is the sidebar-to-canvas shift, the divider, and the composer’s slight lift.
- Recent thread cards were removed from the canvas because the same three threads remain under Study in the sidebar. All threads stays on that sidebar row when more than three exist.
- The decorative integration equation was removed from the continuation area only. Home and sign-in still use the motif.

## Validation

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --quiet` passed 99 tests in 7 suites. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build-macos-prototype.sh` built the app bundle. A separate minimum-window preview showed Study controls within the viewport in dark and light, and the composer placeholder is readable in both after the fix. The existing F013 app was inspected without resetting its in-memory threads; its prior Flashcards and collapsed-course state were restored. `git diff --check` passed before the final contrast fix and should be rerun at integration.

## Recovery

No migrations. Discard this worktree to drop the experiment. F012 is a separate checkout and is unchanged.

## Outcome

F013 is the preferred UI and includes F012's behavior work. Complete final diff review and integration checks before merging; leave F012 untouched as a fallback.
