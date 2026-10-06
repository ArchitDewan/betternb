# F009B course ingestion and grounded study

## Purpose and acceptance

Turn Calculus I sources into working study context instead of a decorative count. A student can add a text-based PDF, see extraction/indexing status, ask a question from the Study desk, receive an answer grounded in retrieved page chunks with visible citations, and generate a small source-backed problem set that opens in the existing worksheet.

F009B is accepted when:

- The Sources sheet imports one PDF and reports actionable validation or extraction failures.
- Extracted text is chunked with stable source/page metadata and embedded behind the existing provider-neutral gateway.
- Course questions retrieve only that course's uploaded chunks and return page citations.
- Problem generation uses retrieved course context and adds its results to Problems.
- The Study landing is one calm focal composer with compact course/source context and no routing explanation or mode choice.
- The visible product name is Lemma and the supplied artwork is the packaged macOS icon; compatibility-sensitive internal identifiers stay unchanged.
- No provider credential enters the macOS app, and model output is never presented as deterministic mathematical verification.

## Context

- Continue in `/Users/architdewan/Desktop/projects/betternb-worktrees/F009-guided-math-tutor` on `feat/F009-guided-math-tutor`; F009A is uncommitted and F009B depends on it, so this is the same task worktree.
- Python owns PDF extraction, chunking, embeddings, retrieval, grounded generation, and HTTP contracts.
- Swift owns file selection, import state, source presentation, conversations, and the Problems list.
- The current service is loopback-only and in-memory. Durable account-backed resources and pgvector remain a later productionization step.

## Plan

1. Add failing Python tests for PDF validation/extraction, page-aware chunking, course isolation, grounded answer citations, problem generation, and HTTP contracts.
2. Implement an in-memory course source index using the existing embedding gateway plus a separate course-study orchestration boundary.
3. Add Swift contracts, client methods, source store tests, cited conversation messages, and generated-problem integration.
4. Replace the Sources placeholder with import/index/list/generate behavior and simplify the Study landing around the unified composer.
5. Rebuild the actual app, inspect default and minimum windows, exercise import/question/generation, and run all affected checks.

## Progress

- [x] 2026-10-05: Confirm F009B thin vertical slice and preserve the F009A worktree dependency.
- [x] 2026-10-05: Python course ingestion and retrieval tests.
- [x] 2026-10-05: Python implementation and endpoints.
- [x] 2026-10-05: Swift client/store tests and implementation.
- [x] 2026-10-05: Sources UI, grounded conversation, generated Problems, and Study landing polish.
- [x] 2026-10-05: Full automated, live-provider, packaged-app, and default/minimum-window verification.

## Decisions and discoveries

- Use the existing OpenAI embedding adapter through `EmbeddingGateway`; do not couple ingestion to a specific provider.
- Keep this demo index in memory and explicit about restart loss. PostgreSQL/pgvector and durable source files require the account/storage milestone rather than hidden client database access.
- A citation identifies source title and PDF page. Generated problems retain source provenance but are not treated as verified answers.
- Text-based PDFs are the first supported format. OCR for scanned PDFs is a later, separately observable pipeline.
- Rebrand the visible app, window, sidebar, account label, service title, and packaged icon to Lemma. Keep `BetterNB` package/executable names, the bundle identifier, Auth0 callback scheme, environment variables, and API types stable in this slice.

## Validation

- `uv run pytest -q`: 37 passed; one existing Starlette `TestClient` deprecation warning.
- `swift test`: 89 passed.
- `./scripts/build-macos-prototype.sh`: passed and packaged `Lemma.icns` in `.build/BetterNB.app`.
- `git diff --check`, `plutil -lint`, and shell syntax checks: passed.
- Live loopback/OpenAI smoke: imported a one-page Product Rule PDF, returned a cited grounded answer from Page 1, and generated a cited practice problem.
- Rebuilt-app flow: Sources listed the live indexed PDF, source-backed generation added three Problems, and a Study question rendered the grounded answer with `Product Rule Notes.pdf · Page 1`.
- The rebuilt Lemma landing and nested sidebar were visually inspected at default and minimum window sizes.

## Recovery

There are no migrations or remote writes. Restarting the tutor service clears the F009B in-memory index. Reverting the F009B service contracts and Swift source-store/UI additions restores the F009A demo without touching the existing tutor loop.

## Outcome

The F009B vertical slice is complete: text PDFs become isolated course embeddings, grounded answers and generated Problems retain page citations, the Sources sheet exposes import/index/generate state, and Study remains the single automatic entry point. The visible app is rebranded to Lemma with the supplied icon. Persistence across service restarts, OCR, pgvector, deletion, source-page viewing, and account sync remain intentionally deferred.
