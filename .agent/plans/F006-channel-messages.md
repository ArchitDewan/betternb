# F006 — Channel messages

## Outcome

Students can send text messages from message-capable course surfaces. Each surface keeps an independent in-memory thread while the app is running. Overview and global navigation destinations remain non-conversational.

## Acceptance criteria

- Materials, Notes, Problems, Practice, Flashcards, Formula Sheet, and Canvas expose a message composer.
- Overview, Home, Search, and Review do not expose a message composer.
- Sending trims surrounding whitespace, rejects empty text, appends a student message, and clears the draft.
- Each destination owns a separate thread that survives navigation during the current app session.
- Student messages align to the right and tutor/service responses align to the left.
- Return submits the current message from the composer.
- The native file picker accepts one PNG, JPEG, or PDF up to 10 MiB; a selected file can accompany text or be sent by itself.
- A selected attachment is visible and removable before send, and sent messages retain their attachment metadata and preview data for the current app session.
- The existing guided Practice presentation and tutor reply remain intact.
- UI state depends on an async repository protocol so an authenticated HTTP/PostgreSQL adapter can replace the preview adapter without changing feature views.

## Implementation notes

- Keep conversation behavior in plain Swift domain state so it is testable without rendering SwiftUI.
- Own conversation state at the workspace shell so destination views do not lose it when navigation changes.
- Use an in-memory repository for this native prototype. PostgreSQL remains the canonical durable store behind the future Go API; the Mac app must not connect to PostgreSQL directly.
- Do not edit the concurrent authentication or Go service work. Its authenticated principal will later provide ownership at the API boundary.

## Verification

- Add focused Swift tests for destination capability, trimming/blank behavior, and per-channel isolation.
- Run `swift test`, `swift build`, and build the inspectable app bundle.
- Inspect the relevant views at default and minimum window sizes.

## Recovery

The feature is isolated to `feat/F006-channel-messages` in its own worktree. Removing the branch/worktree returns to the previous prototype with no data migration.
