# F009 guided math tutor

## Purpose and acceptance

Deliver a demoable native tutoring loop backed by a custom, bounded agent rather than a raw chat completion. A student can enter a typed or image-based derivative problem, confirm image transcription, submit steps, receive retrieval-backed feedback with honest verification labels, request three progressively stronger hints, and explicitly reveal a full solution.

F009A is accepted when the native Practice surface completes that loop against a loopback Python service, citations identify the built-in calculus material used, only the symbolic verifier can award `verified`, and failure leaves the student's draft intact. Revealed solutions render as native-looking math rather than raw LaTeX, a simple power-rule problem does not cite chain/product/quotient material, and the Reveal action disappears once a solution is shown. F009B remains deferred.

## Context

- The SwiftUI Practice surface is the product. `PracticeSessionView` owns the in-memory session, transcription confirmation, hints, reveal, and now native math rendering of tutor/student text.
- The loopback Python service lives under `services/tutor` with provider-neutral model, embedding, retrieval, and verification interfaces. OpenAI is the first adapter. Credentials stay in the service process.
- Development sessions are in memory and the service binds only to loopback. Remote authentication, durable storage, course uploads, PDFs, pgvector, and additional subject capabilities are F009B or later work.

## Plan

1. Establish Python contracts and failing tests for safe derivative verification, semantic retrieval, citations, hint policy, and API validation.
2. Implement the bounded tutor orchestration, built-in derivative corpus, provider adapters, HTTP endpoints, and deterministic fake adapters.
3. Add Swift tutoring domain state and tests for transcription confirmation, turn submission, verification labels, hint progression, reveal policy, and draft recovery.
4. Replace the Practice preview with the real session flow and connect it to the loopback service.
5. Integrate the tutor service into the development runner, document configuration and commands, and complete automated plus visual verification.
6. Polish F009A: native math rendering, tighter retrieval, hide a redundant reveal action, and live-provider exercise.

## Progress

- [x] 2026-10-04: Confirm product boundary, two-stage delivery, agent architecture, and built-in calculus RAG scope.
- [x] 2026-10-04: Create dedicated branch and persistent worktree.
- [x] 2026-10-04: Add Python behavior and contract tests.
- [x] 2026-10-04: Implement and verify the tutor service.
- [x] 2026-10-04: Add Swift session tests.
- [x] 2026-10-04: Implement and verify the native tutoring flow.
- [x] 2026-10-04: Integrate the development runner and documentation.
- [x] 2026-10-04: Complete automated verification and default/minimum-window visual review.
- [x] 2026-10-04: Render model LaTeX (`\frac`, `\boxed`, `\[...\]`, align) as native math.
- [x] 2026-10-04: Tighten retrieval so a simple power-rule problem cites only Power rule.
- [x] 2026-10-04: Hide Reveal solution after an accepted reveal.
- [x] 2026-10-04: Exercise the live OpenAI provider and re-run plan validation.
- [x] 2026-10-04: Fix jammed prose, conversational turns, thinking state, and Command-V image paste.
- [x] 2026-10-04: Remove duplicate problem header and citation stack; match Practice to channel chat chrome; fix aligned/display spacing.
- [x] 2026-10-04: Give revealed solutions room: operator/function spacing, break long display math at `=` and `+`/`-`, wrap display instead of a tight HStack, and ask the model for one equation per step.
- [x] 2026-10-04: Snapshot commit `075ea51` before the notebook pass.
- [x] 2026-10-04: Turn Practice into a notebook: problem rail, Ask/Check, live draft preview, hint ladder, conversation history, and a Problems set that opens Practice.

## Decisions and discoveries

- One bounded tool-using tutor owns the initial workflow. Multiple LLM agents are deferred until evaluations show a concrete need.
- A checked-in Calculus I derivative pack proves retrieval now; private course ingestion follows after provenance and deletion contracts are defined.
- Deterministic verification alone produces `verified`; retrieval-backed language-model assessments use `model_judged`, and uncertain verification uses `inconclusive`.
- F009A uses non-streaming HTTP and in-memory session state to preserve a small, testable vertical slice.
- Retrieval queries the problem only. Student steps mentioning the wrong rule no longer pollute citations. Results stay on the leading title unless another rule is both structurally cued by the problem and nearly tied in score. Live OpenAI embeddings placed Product rule next to Power rule for `Differentiate f(x) = x^2` until that cue gate was added.
- The native client renders a bounded LaTeX subset itself rather than embedding WebKit/KaTeX. A live reveal used display math, `\frac{d}{dx}`, superscripts, and `\boxed{f'(x)=2x}`; that sample is a Swift regression test.
- `TutorSessionStore.canRevealSolution` is the UI contract: after an accepted reveal, the Reveal button is omitted so the solution is not shown beside the same action.
- The orchestrator owns conversation. The derivative verifier runs only on a written step (`f'(x)=`, `d/dx`, or a short equation). Informal help such as "can you help me differentiate 7x^2 + 4x?" is `chat`, returns `not_assessed`, and does not show a verification badge.
- The student bubble is appended immediately. A Thinking row stays visible until the tutor reply, with a 400ms minimum wait so the response does not appear in the same instant.
- Command-V pastes a PNG/JPEG from the clipboard into the practice composer when an image is on the pasteboard; otherwise text paste still goes to the field.
- Practice matches the other channel conversation chrome: no duplicate problem header, no citation stack, student bubbles use the same paper/stroke treatment, and empty state language matches Materials/Notes. Align environments inside display math are parsed as stacked lines; English inside math delimiters is spaced as words.

## Validation

- `uv run pytest -q`: 30 passed; one non-failing Starlette `TestClient` deprecation warning.
- `swift test`: 42 passed.
- `swift build`: passed.
- `./scripts/build-macos-prototype.sh`: passed; wrote `.build/BetterNB.app`.
- `go test ./...`: passed.
- `go test -race ./...`: passed.
- `go vet ./...`: passed.
- `go build -o /private/tmp/betternb-F009-api ./cmd/betternb-api`: passed.
- `bash -n scripts/run-dev.sh`: passed.
- `git diff --check`: passed.
- Live OpenAI smoke (`PYTHONPATH=services/tutor/src uv run python services/tutor/evals/live_smoke.py`, using the existing worktree `.env.local` in-process and not copied): typed `Differentiate f(x) = x^2` step was `verified`/`correct` and cited only Power rule; hints 1–3 were accepted; an invalid hint returned 422 and a later step still verified; reveal closed with `next_action=continue_practice` and `\boxed`; image transcription returned `Differentiate f(x) = x^2` with `requires_confirmation=true`.
- Previous session already confirmed default and minimum-window Practice layouts. This pass did not relaunch the GUI; math rendering is covered by unit tests against the live reveal sample, and the reveal control is covered by `canRevealSolution` tests. A human glance at Practice after a live reveal is still useful.

## Recovery

All work remains isolated in `/Users/architdewan/Desktop/projects/betternb-worktrees/F009-guided-math-tutor` on `feat/F009-guided-math-tutor`. The service has no migrations or remote resources. Removing the feature branch after explicit approval restores the pre-F009 application. The embedding cache key is `title-section-v1`; delete `.build/tutor/derivatives-index.json` if retrieval results look stale after another index-text change.

## Outcome

F009A is a reviewable, polished vertical slice. Conversation is handled by the orchestrator; the solver only grades a written derivative. Practice now keeps word spacing, shows the student message and a Thinking row before the reply, accepts Command-V images, and hides verification badges on chat/hint/reveal turns. F009B remains deferred.
