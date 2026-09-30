# BetterNB architecture direction

Status: recommended starting shape; stack choices remain revisable until the first scaffold is accepted.

## Design goals

- Preserve source provenance from ingestion through every answer and saved note.
- Keep model providers replaceable behind narrow interfaces.
- Make asynchronous processing observable and retryable.
- Support a complete local development environment.
- Prefer a modular application over independently deployed services until scale justifies separation.

## Recommended starting stack

- Web application and product API: Go, using server-rendered templates and HTMX-style HTML interactions.
- Intelligence service and ingestion worker: Python with FastAPI and a background worker mode.
- Primary database: PostgreSQL with `pgvector` for early retrieval needs.
- Source storage: an S3-compatible object store, using a local emulator in development.
- Queue: a PostgreSQL-backed job table for the first release.
- Browser tests: Python Playwright so the project does not require application code in TypeScript.
- Model gateway: Python interfaces for generation, embeddings, and reranking.

This split keeps the product surface in a language the owner can review while giving document parsing, retrieval, and evaluation access to Python's AI ecosystem. Go owns HTTP, authorization, notebooks, uploads, notes, source viewing, and HTML rendering. Python owns parsing, retrieval, model calls, citation analysis, and quality evaluations.

Use Go's standard library where it remains clear. A small router and typed template library are reasonable, but avoid a frontend build system initially. HTMX can cover forms and partial updates through HTML attributes. Confine unavoidable browser JavaScript to isolated adapters such as PDF rendering, passage highlighting, and streaming controls; do not let those adapters become a second application architecture.

The first deployment can run as one Go web process, one Python intelligence process, one Python worker process, PostgreSQL, and object storage. PostgreSQL jobs avoid adding Redis before throughput proves it necessary.

## Main components

```text
Browser
  -> Go web application / product API
      -> PostgreSQL / vector index
      -> Object storage
      -> PostgreSQL job table -> Python ingestion worker
      -> Python intelligence API -> generation / embeddings / reranking
```

The Go application owns navigation, authorization, notebook state, source metadata, uploads, source views, conversations, notes, deletion, and the public HTTP contract. The Python intelligence API owns notebook-scoped retrieval, grounded-answer generation, and citation analysis. The Python worker owns parsing, normalization, chunking, embeddings, and ingestion retries.

Go and Python communicate through a small versioned internal HTTP/JSON contract. Stream grounded-answer events from Python through Go to the browser using Server-Sent Events. Keep database ownership explicit: Go owns user-facing records and migrations; Python owns derived passage, chunk, embedding, evaluation, and job-result writes defined by accepted contracts.

## Core records

- `User`: identity and account-level preferences.
- `Notebook`: ownership, title, and lifecycle state.
- `Source`: original file metadata, storage reference, type, checksum, and processing state.
- `SourcePassage`: normalized text with stable source, page, and character or bounding-box provenance.
- `Chunk`: retrieval unit derived from one or more passages, with embedding metadata.
- `Conversation` and `Message`: notebook-scoped interaction history.
- `AnswerClaim`: a claim extracted from an assistant answer.
- `Citation`: the relationship between an answer or claim and a supporting passage.
- `Note`: editable user content with optional links to messages and passages.
- `Job`: durable ingestion or generation state with attempts and failure details.

Keep passages separate from chunks. Passages represent stable evidence in the original source; chunks are a replaceable retrieval strategy. Re-chunking should not invalidate saved citations.

## Grounded-answer path

1. Authorize notebook and selected sources.
2. Rewrite or expand the question only when retrieval benefits.
3. Retrieve candidate chunks and rerank them.
4. Build a bounded context containing stable passage identifiers.
5. Generate an answer whose citations reference those identifiers.
6. Validate that each citation exists and that cited text is present in the supplied context.
7. Optionally classify claim support and flag unsupported statements.
8. Stream answer content and citation events to the client.

Citation validation cannot prove semantic support by itself. The evaluation suite should include labeled questions where the expected source passage and answerability are known.

## Boundaries for parallel feature work

Parallel work is safe after these contracts are explicit:

- database migrations and record ownership;
- API request, response, and error schemas;
- job payloads and lifecycle states;
- model gateway interfaces;
- citation and source-location format;
- shared UI tokens and component contracts.

Until those stabilize, work on the foundation sequentially. Several agents editing the schema, API, and shared types at once will create integration work faster than product value.

## Security and privacy baseline

- Enforce notebook authorization on every source, message, note, and job operation.
- Treat uploaded files and extracted text as untrusted input.
- Validate file type and size, isolate parsers, and scan uploads before processing.
- Never include one user's passages in another user's retrieval scope.
- Encrypt transport and provider secrets; avoid logging document content by default.
- Make deletion cover database records, stored objects, derived passages, embeddings, and queued work.

## Verification strategy

- Unit tests for parsing, chunk construction, citation validation, and authorization rules.
- Contract tests between the web application and API and between the API and worker.
- Go handler and domain tests using the standard `testing` package.
- Python ingestion, retrieval, and evaluation tests using `pytest`.
- Integration tests with real PostgreSQL, object storage, and queue substitutes.
- Python Playwright end-to-end tests for the first vertical slice.
- Retrieval and answer-quality evaluations over a small versioned document set.
- Production smoke checks for upload, processing, grounded chat, citation opening, and deletion.
