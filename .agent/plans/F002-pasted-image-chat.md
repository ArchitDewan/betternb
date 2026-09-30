# F002: Paste an image into notebook chat

This plan follows `.agent/PLANS.md` and stays current while the feature is active.

## Purpose and acceptance

Deliver the first directly useful BetterNB interaction: a user can paste an image from the clipboard into a notebook chat, review it, optionally add text, send it, and see the persisted message from another browser session.

Acceptance criteria:

- Pasting one PNG, JPEG, GIF, or WebP image into the chat composer immediately shows a preview and filename.
- The pasted image can be removed before sending without clearing typed text.
- Sending a message with text, an image, or both persists it on the server and renders it in the notebook conversation.
- A fresh browser request to the same notebook displays the message and can load its image, establishing the server-backed basis for cross-device access.
- Images larger than 10 MiB, unsupported data, and empty submissions receive clear errors.
- Uploaded bytes are type-checked and are only retrievable within the notebook URL that owns them.

## Context

The repository currently contains product and architecture documentation but no application scaffold. `docs/ARCHITECTURE.md` assigns notebook chat, uploads, and HTML rendering to a Go web application and recommends server-rendered HTML with small isolated JavaScript adapters. This feature will establish that Go surface using only the standard library. It will use a local file-backed repository for development so the behavior is persistent without prematurely introducing the broader PostgreSQL/object-storage stack required by F001.

Authentication, OCR/image understanding, notebook creation, AI responses, and production object storage are outside this feature. The route uses a fixed development notebook slug; later notebook and authorization work must put ownership checks in front of the same repository boundary.

## Plan

1. Add a minimal Go module and executable web server.
2. Add failing tests for accepted image messages, persistence, notebook isolation, invalid image data, size limits, and empty submissions.
3. Implement the file-backed message and attachment repository with atomic metadata writes and strict identifiers.
4. Implement server-rendered notebook chat handlers and attachment delivery.
5. Add the clipboard adapter, accessible composer states, and responsive styling.
6. Run unit, race, vet, and manual HTTP/browser-oriented verification; inspect the final diff.

## Progress

- [x] (2026-09-30) Define the feature boundary and observable acceptance criteria.
- [x] (2026-09-30) Create `feat/F002-pasted-image-chat` in a dedicated worktree.
- [x] (2026-09-30) Add behavior tests and observe the expected missing-implementation failure.
- [x] (2026-09-30) Implement persistent image messages and HTTP handlers.
- [x] (2026-09-30) Implement the paste/preview/remove adapter and verify responsive rendering.
- [x] (2026-09-30) Complete repository checks and reviewer handoff.

## Decisions and discoveries

- Decision: Treat pasted images as message attachments, not document sources.
  Rationale: This matches the user's requested interaction while leaving later image understanding free to promote an attachment into derived evidence without forcing a document-upload detour.
  Date/Author: 2026-09-30 / Codex.

- Decision: Persist development data on the server's filesystem behind repository methods.
  Rationale: It proves reload and cross-browser behavior now while keeping the eventual PostgreSQL and object-store migration localized. It is explicitly not the production storage design.
  Date/Author: 2026-09-30 / Codex.

- Decision: Keep browser JavaScript limited to clipboard capture, preview, removal, and inline client feedback.
  Rationale: The server remains authoritative for validation and persistence, consistent with the documented architecture.
  Date/Author: 2026-09-30 / Codex.

## Validation

Automated checks cover multipart message creation, server restart persistence, attachment retrieval, notebook isolation, supported image signatures, magic-byte validation, the 10 MiB limit, and empty submissions.

Validation completed on 2026-09-30:

- `go test ./...` passed.
- `go test -race ./...` passed.
- `go vet ./...` passed.
- `go build -o /private/tmp/betternb-F002 ./cmd/betternb` passed.
- `node --check internal/web/assets/app.js` passed.
- A built server accepted a real PNG and text multipart request, returned `303 See Other`, and displayed the persisted image message after a fresh GET.
- Headless Chrome screenshots at 1440px and 500px showed the empty state, composer, persisted message, and responsive layout without visible clipping at Chrome's supported viewport widths.

An actual OS clipboard paste remains a useful reviewer check because the automated suite exercises the server boundary and the browser adapter only has a syntax check in this framework-free scaffold.

## Recovery

All work is isolated in the F002 worktree and branch. No migration or external service is involved. The feature can be removed by discarding this branch after explicit user direction. Development data lives beneath the configured `-data-dir` and can be deleted independently of source code.

## Outcome

The feature meets the server-backed acceptance criteria: supported images and optional text persist, reload, and remain scoped to their notebook; invalid, empty, and oversized submissions show useful errors. The browser adapter captures pasted image files, previews and removes them, and submits through the same multipart form used by the tested server path.

The deliberately deferred production concerns are authentication/authorization, CSRF protection, PostgreSQL/object storage, multi-process write coordination, OCR or model image understanding, and notebook creation. Until those arrive, this is a single-server development feature with a default `research` notebook, not a production cross-device release.
