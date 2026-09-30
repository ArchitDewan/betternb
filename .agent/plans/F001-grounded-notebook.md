# F001: Deliver the grounded-notebook vertical slice

This plan follows `.agent/PLANS.md` and must remain current as implementation proceeds.

## Purpose and acceptance

Deliver the smallest BetterNB workflow that proves a user can obtain a source-grounded answer and verify it. A user can create a notebook, upload one PDF, observe ingestion, ask a question, open a cited passage on the correct page, save the answer as a note, and delete the notebook with its derived data.

Acceptance requires citations that point to supporting text. A fluent answer with an incorrect, missing, or inaccessible citation fails acceptance.

## Context

`docs/PRODUCT.md` defines the initial product promise and scope. `docs/ARCHITECTURE.md` defines the recommended component boundaries and provenance model. The repository currently contains process documentation only and has no initial Git commit, application scaffold, or selected provider credentials.

## Plan

Milestone 1 establishes the product and technical contracts: confirm the initial user, deployment mode, provider boundaries, source-location format, and the first evaluation documents. The selected implementation shape is a Go web application and product API with a Python intelligence API and worker.

Milestone 2 creates a runnable local scaffold with a web application, API, worker, database, object storage, and queue. It adds health checks and one command that starts the development environment.

Milestone 3 implements notebook creation, PDF upload, durable ingestion state, passage extraction with page provenance, chunking, and embeddings.

Milestone 4 implements notebook-scoped retrieval, streamed grounded answers, citation validation, and a source viewer that opens the cited passage.

Milestone 5 implements editable notes, complete notebook deletion, end-to-end verification, and the first retrieval-quality evaluation report.

## Progress

- [x] (2026-09-29) Define the initial product brief, architecture direction, and feature-session workflow.
- [x] (2026-09-29) Select Go for the web application and product API and Python for ingestion, retrieval, model integration, and evaluations.
- [ ] Confirm the initial user and deployment mode.
- [ ] Create and approve the baseline repository commit so task worktrees can be created.
- [ ] Define API, job, citation, and source-location contracts.
- [ ] Scaffold and verify the local development environment.
- [ ] Implement notebook and PDF ingestion behavior.
- [ ] Implement grounded chat and citation inspection.
- [ ] Implement notes and complete deletion.
- [ ] Run automated checks, quality evaluations, and manual acceptance.

## Decisions and discoveries

- Decision: Build one end-to-end vertical slice before audio, collaboration, web research, or broad output generation.
  Rationale: It tests ingestion, retrieval, generation, provenance, and the central user experience with the least surface area.
  Date/Author: 2026-09-29 / Codex, pending user review.

- Decision: Use one worktree per independent feature and reuse it across sessions for the same feature.
  Rationale: It keeps parallel work isolated while preserving continuity and reviewable diffs.
  Date/Author: 2026-09-29 / User and Codex.

- Decision: Keep the first development phase sequential until data, API, job, and citation contracts are accepted.
  Rationale: Parallel edits to foundational contracts would create avoidable integration churn.
  Date/Author: 2026-09-29 / Codex, pending user review.

- Decision: Use Go and server-rendered HTML for the product surface, with Python behind a narrow internal contract for document and AI workloads.
  Rationale: The owner can review and change Go and Python directly. This keeps document and evaluation work in Python without requiring a TypeScript application architecture.
  Date/Author: 2026-09-29 / User and Codex.

- Decision: Start with PostgreSQL-backed jobs instead of Redis and isolate the small amount of unavoidable browser JavaScript.
  Rationale: This reduces infrastructure and keeps the application understandable while retaining a path to richer PDF and streaming interactions.
  Date/Author: 2026-09-29 / Codex, pending user review.

## Validation

The final slice will require unit, contract, integration, and browser-level tests plus a small retrieval-quality evaluation set. Manual acceptance will upload a known PDF, ask questions with known answers and unanswerable questions, inspect cited passages, save a note, and verify complete deletion.

For the current documentation milestone, validate that the project instructions route agents to the three new documents, the plan contains every section required by `.agent/PLANS.md`, and no application-stack command is presented as already implemented.

## Recovery

All current changes are documentation in the primary checkout. They can be revised without migrations or external state. Do not create task worktrees until the repository has an initial commit. Do not create that commit without explicit user instruction.

## Outcome

The project now has a reviewable product thesis, recommended architecture, feature-session model, and first vertical-slice plan. Implementation has not started, pending the product and stack choices listed in Progress.
