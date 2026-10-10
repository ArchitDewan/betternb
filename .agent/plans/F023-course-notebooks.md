# F023 — Course notebooks and Home

## Purpose and acceptance

- Home lists the student's notebooks and offers a clear Create notebook action.
- A student can name a notebook for any course, open it, switch between notebooks, and find the same notebook after relaunch.
- Each notebook behaves like the original expandable course folder. Right-click offers Rename and Delete; deletion asks for confirmation and requires another notebook to remain.
- The sidebar and course headings show the chosen name. The fixed Linear Algebra coming-soon row is gone.
- Course sources and in-session work stay separate when switching notebooks; legacy Calculus I remains available.
- Home remains usable at default and minimum window sizes.

## Context

`WorkspaceHomeView` and `SidebarView` currently hard-code Calculus I and Linear Algebra. `WorkspaceShellView` builds one fixed `CourseSourceStore`. The product brief calls for student-created course notebooks. F022 Problems work is uncommitted in its own worktree; keep this independent branch isolated.

## Plan

1. Add an account-scoped local notebook catalog, retaining Calculus I for existing users. Test create, duplicate/blank validation, selection, and reload.
2. Route Home, sidebar, top bar, Study, and source views through the active notebook. Keep a separate in-memory workspace state per notebook during the app session.
3. Redesign Home around a compact heading, notebook grid, and create dialog. Verify build/tests and inspect default/minimum windows.

## Progress

- [x] 2026-10-09: Inspected current navigation and created isolated F023 worktree.
- [x] 2026-10-09: Notebook model and create/select/reload test.
- [x] 2026-10-09: Course switching, dynamic labels, and Home UI.
- [x] 2026-10-09: Swift tests, app bundle build, and default/minimum-window visual checks.
- [x] 2026-10-09: Follow-up: restored the original expandable folder pattern for every notebook after the user clarified that the folder feel is intentional. Added a confirmed delete action.
- [x] 2026-10-09: Follow-up: removed the visible three-dot control; moved Rename and Delete to right-click menus on folders and Home cards.
- [x] 2026-10-09: Follow-up: notebook expansion is independent; switching courses no longer collapses another open folder.

## Decisions and discoveries

- A notebook name is free-form course text, not a fixed subject enum.
- Keep legacy `calculus-1` as the seeded notebook ID so existing source references can remain associated after this branch is integrated.
- Other feature branches own long-term Problems and attempt persistence; this branch must not copy their uncommitted changes.
- Newly created notebooks use distinct course IDs for tutor sources. Workspace stores are cached per course while the app is open. The existing main-branch source and attempt stores are still transient after a full relaunch; F022's separate work will need integration for durable content.
- The Calculus I motif is shown only in Calculus I, avoiding an integral illustration in unrelated course notebooks.

## Validation

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: 114 passed.
- `./scripts/build-macos-prototype.sh`: passed.
- `git diff --check`: passed.
- Inspected Home at 1420×900 and 1040×680; created Linear Algebra, switched to Calculus I, and confirmed both notebooks remain after relaunch.
- Follow-up sidebar check: built a separate QA app bundle at minimum size, created Linear Algebra, confirmed its folder expanded with Study/Textbook/Problems, collapsed it, switched to Calculus I, and deleted the QA notebook through its confirmed menu action.
- Right-click QA: renamed Calculus I to Mathematics and confirmed the title updated in Home; created Physics and confirmed its right-click menu offers both Rename and Delete.
- Confirmed a Home notebook card exposes the same right-click menu in a separate QA app.
- Multi-folder QA: created Linear Algebra alongside Calculus I, confirmed both remain expanded through course switches, then clicked Calculus I again and confirmed only it collapsed.

## Recovery

The catalog is additive local JSON. Removing this branch restores the fixed Home; no server migration or user data deletion is required.

## Outcome

Home now lists real, student-named notebooks and gives two clear creation entry points. The sidebar retains the original expandable course folder layout for every notebook, with indented Study/Textbook/Problems and recent threads. Multiple notebook folders can stay open independently. Right-clicking a folder or Home card offers Rename and Delete without a visible options control. Deletion is confirmed and requires another notebook to remain. Course surfaces use the selected title, and the fixed Linear Algebra coming-soon entry is removed. Notebook metadata persists locally by account; full content persistence remains in the separate F022 work.
