# F005 native workspace UI

## Purpose and acceptance

Create the first runnable native macOS presentation of BetterNB. The prototype should communicate a calm, math-first study workspace — not a chatbot clone — without depending on a database, network service, or AI provider.

Acceptance criteria:

- The app launches into a polished dark-mode study workspace at desktop window sizes.
- A persistent sidebar exposes home, search, review, courses, and course tools.
- The central canvas presents the current Calculus I problem and workspace, not a chat landing page.
- A trailing tutor rail is not part of Home. Chat appears only after entering a practice session, as the session canvas.
- Visual language borrows ChatGPT’s quiet padding and color, not its empty-prompt product model.
- Selection and hover states use native macOS interaction and SF Symbols.
- The layout remains usable when resized to the documented minimum window size.
- The source is split into small design-system, model, component, and screen files.
- The prototype has no persistence, network, authentication, or AI dependency.

## Context

- `docs/ARCHITECTURE.md` defines the product as a native SwiftUI macOS application.
- The existing Go app remains the marketing site and interaction prototype.
- ChatGPT is a visual reference for dark-shell padding and color only.
- PostgreSQL is the future server database behind an API. This UI prototype intentionally has no database integration.
- Full Xcode is not selected in the current environment; Swift Package Manager is the available build path.

## Plan

1. Add a Swift Package executable for a native macOS SwiftUI application.
2. Establish semantic colors, spacing, and reusable visual primitives.
3. Build the three-surface workspace: sidebar, course canvas, tutor panel.
4. Add lightweight local presentation state for navigation and panel visibility.
5. Update architecture wording for PostgreSQL as the server database and deferred local caching.
6. Build and manually inspect the running prototype at multiple window sizes.

## Progress

- [x] 2026-09-30: Defined the visual acceptance contract and isolated the feature worktree.
- [x] 2026-09-30: Scaffolded the native Swift package, Info.plist bundle, and design-system/model/component/screen split.
- [x] 2026-09-30: Aligned architecture documentation with PostgreSQL-behind-API and deferred client cache.
- [x] 2026-09-30: Rebuilt Home as a Calculus workspace (current problem + course tools), reversing the ChatGPT clone landing.
- [x] 2026-09-30: Built and inspected the study-workspace rebuild at the default window size.

## Decisions and discoveries

- Use system typography and SF Symbols so the interface feels native and scales correctly.
- Use a small set of named design tokens instead of repeating raw colors in views.
- Treat all controls as prototype navigation; no fake loading or simulated backend behavior.
- PostgreSQL will be accessed only through the future service API, never directly from the distributed Mac client.
- Swift Package Manager plus a small bundle script is the current build path; Xcode project generation is deferred.
- macOS window restoration was filling the display from a previous launch, so the prototype disables restorable state and applies a centered launch frame.
- Home is the current problem in Calculus I. Chat-style “What should we work on?” and “Ask anything” composers are not the product.
- Geometric window zoom was removed because it broke layout. Zoom now scales type and spacing in place. Chat lives in the practice session, not a persistent right bar.

## Validation

- `swift build` — succeeded.
- `./scripts/build-macos-prototype.sh` — succeeded.
- Launch with `open .build/BetterNB.app` — Home shows Calculus I, the current limit problem, course tools, and a tutor panel. It does not show a chat landing page.
- `git diff --check` — clean.

## Recovery

All work is isolated on `feat/F005-native-workspace-ui` in its dedicated worktree. Removing the worktree and branch reverts the unmerged prototype without touching the Go application or `main`.

## Outcome

Home is a math study workspace: current problem on the canvas, courses in the sidebar, optional tutor beside the work. ChatGPT remains a padding/color reference only.
