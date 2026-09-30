# BetterNB architecture direction

Status: accepted product direction as of 2026-09-30; implementation details remain revisable until the native scaffold is reviewed.

## Product boundary

BetterNB is a native macOS study application, not a browser-based notebook product. The primary experience is a fast, keyboard-friendly, local-first desktop workspace for mathematics students. Physics and computer-science fundamentals can reuse the same learning model after the math workflow is trustworthy.

The repository's current Go application has two limited roles:

1. host the public BetterNB landing page;
2. preserve interaction prototypes, such as direct image paste, until their native replacements exist.

Do not expand the current server-rendered notebook into the production product UI. New product features belong in the native macOS application unless they are explicitly part of the marketing site, sync API, or intelligence service.

## Product and interface references

[Paper](https://paper.ac/) is a useful reference for presenting notes, sources, flashcards, quizzes, and spaced review as one study workspace instead of separate tools. The supplied dashboard reference adds the desired desktop information architecture:

- a persistent left sidebar for workspace navigation and courses;
- a top bar for breadcrumbs, search, sharing, and document actions;
- a large central canvas that can contain prose, equations, boards, problems, and generated study tools;
- page-like modes such as notes, problems, flashcards, canvas, quizzes, and review;
- contextual controls close to the content rather than a dense global toolbar.

BetterNB should borrow the clarity of this workspace model, not its branding or exact layout. Its distinctive center is the student's mathematical attempt: the app should make it easy to move between course material, the current problem, step-by-step feedback, and targeted practice.

## Design goals

- Make attempting a problem the primary interaction; do not default to producing complete solutions.
- Keep course material, mathematical work, feedback, practice, and review in one navigable workspace.
- Feel native on macOS: fast launch, keyboard navigation, menus, drag and drop, paste, multiple windows, and system accessibility.
- Work offline for course organization, notes, problem attempts, and previously downloaded material.
- Persist locally first and synchronize without silently overwriting student work.
- Keep tutoring models, OCR, symbolic verification, and sync providers replaceable behind narrow interfaces.
- Preserve every attempt and correction so learning progress is explainable.
- Make asynchronous OCR, ingestion, generation, and sync work observable and retryable.

## Product surfaces

### Native macOS application

The macOS application is the product. Use the current stable Swift toolchain, SwiftUI for the main interface, and small AppKit adapters only where macOS behavior requires them.

The application owns:

- workspace and course navigation;
- notes, problems, attempts, and study-tool presentation;
- local persistence and file management;
- keyboard commands, multiple windows, paste, and drag-and-drop behavior;
- offline state and the sync outbox;
- tutoring-session state and streaming feedback presentation;
- accessibility and native platform integration.

Keep domain logic in plain Swift types and protocols rather than SwiftUI views. Views render state and emit user actions; repositories, use cases, and services own behavior.

### Public website

The Go web application owns the marketing site and temporary interaction prototypes. It should remain small and independently deployable. Once a prototype has a native replacement, remove or clearly label the prototype rather than maintaining two production interfaces.

### Sync and account service

A future Go service owns accounts, device registration, authorization, durable sync, shared server metadata, and signed attachment transfers. PostgreSQL and S3-compatible object storage remain reasonable server-side defaults when sync work begins.

### Intelligence and verification service

A Python service owns OCR post-processing, mathematical parsing, retrieval over course material, tutoring orchestration, symbolic/numeric verification, practice generation, and quality evaluations. Model and verification providers sit behind versioned interfaces.

The macOS application communicates with remote services through a small versioned HTTP/JSON contract. Stream tutoring events to the app over a transport that supports cancellation and reconnection. Do not expose provider credentials in the client.

## System shape

```text
Public browser
  -> Go marketing site

BetterNB for macOS
  -> SwiftUI feature views
  -> domain use cases and protocols
  -> local repositories
      -> SQLite study database
      -> attachment vault in Application Support
      -> durable sync outbox
  -> service clients
      -> Go account and sync API
          -> PostgreSQL
          -> object storage
      -> Python tutoring and verification API
          -> OCR / math parser
          -> retrieval
          -> symbolic and numeric verifier
          -> model gateway
```

The first native milestones should run without PostgreSQL or object storage. Local persistence is the source of truth on the device until the sync contract is deliberately introduced.

## Native application organization

Prefer feature-oriented modules with shared domain foundations:

```text
macos/
  BetterNB/
    App/                 application entry, windows, commands, dependencies
    DesignSystem/        tokens and reusable native components
    Features/
      Workspace/
      Courses/
      Notes/
      Problems/
      Tutor/
      Practice/
      Review/
      Settings/
    Domain/              records, use cases, service protocols
    Persistence/         SQLite repositories, migrations, attachment vault
    Services/            tutoring, OCR, sync, and telemetry clients
  BetterNBTests/
  BetterNBUITests/
```

Feature boundaries are more important than the exact folder names. Avoid a single global application store containing every screen. Share identifiers and domain contracts; keep transient presentation state inside the owning feature.

## Workspace information architecture

The primary window uses a native split-view structure.

### Sidebar

- Home: today's review, recent courses, and progress.
- Search: courses, notes, problems, equations, and attempts.
- Courses: expandable course workspaces such as Calculus II or Linear Algebra.
- Course tools: Overview, Materials, Notes, Problems, Practice, Flashcards, Formula Sheet, Canvas, and Review.
- Saved: bookmarked problems, explanations, and formulas.
- Settings and account status.

The sidebar is stable across modes so students always know where they are. Course tools can be reordered or hidden later, but should not become independent mini-apps.

### Main canvas

The central canvas changes with the selected mode:

- Notes supports rich text, inline and display math, images, links, and embedded problems.
- Problems shows the prompt, student attempt timeline, hint controls, and feedback.
- Materials presents PDFs, slides, images, and extracted course structure.
- Practice delivers one problem at a time with an intentional answer-reveal policy.
- Canvas supports spatial organization of formulas, diagrams, concepts, and problems.
- Review shows due items, mastery evidence, and recent misconceptions.

### Inspector or tutor panel

Use a collapsible trailing panel for context that should remain visible beside the work:

- tutor conversation and hint depth;
- step-check details;
- related course material;
- concept and mastery context;
- metadata and export actions.

The panel must be optional. Core content remains usable at narrower window sizes and in distraction-free mode.

### Native interaction expectations

- Command palette and menu commands for common navigation and creation.
- Keyboard shortcuts for new problem, check step, request hint, reveal explanation, and switch course modes.
- Direct clipboard paste for screenshots, equations, diagrams, and handwritten work.
- Drag and drop from Finder, Mail, browsers, and supported course tools.
- Quick Look where appropriate for source files.
- Multiple windows for comparing material and working a problem.
- Visible offline, processing, and sync states that never block local editing.

## Core records

- `Workspace`: user-level container and preferences.
- `Course`: title, term, subject, notation preferences, and learning settings.
- `Unit`: an ordered concept or syllabus grouping within a course.
- `Resource`: a lecture, textbook section, formula sheet, image, video transcript, or other course input.
- `ResourceFragment`: extracted text, math, or visual region with stable source location.
- `Concept`: a skill or idea such as substitution, limits, eigenvectors, or induction.
- `Problem`: prompt, constraints, expected concepts, source, and difficulty metadata.
- `Attempt`: one student's work on one problem.
- `AttemptStep`: ordered typed, drawn, pasted, or imported mathematical work.
- `TutorFeedback`: assessment of a step, error classification, explanation, and verifier result.
- `Hint`: progressive help with an explicit strength level and reveal history.
- `MasteryEvent`: immutable evidence that a concept became stronger or weaker.
- `ReviewItem`: scheduled practice derived from mastery evidence.
- `StudyArtifact`: note, formula card, flashcard set, quiz, or review plan.
- `Attachment`: locally stored image or file with checksum and processing state.
- `SyncEvent`: an idempotent local mutation awaiting acknowledgement.

Attempts, steps, feedback, hints, and mastery events are append-only learning history. Editable notes and artifacts use explicit revisions. Attachments are content-addressed. Sync must not collapse two attempts or silently replace a note revision.

## Guided-problem path

1. Load the course, current unit, notation preferences, and relevant materials.
2. Capture the problem and the student's existing attempt from text, math input, an image, or handwriting.
3. Parse expressions and diagrams into a typed intermediate representation while retaining the original input.
4. Retrieve only the course context relevant to the current method and concept.
5. Verify the latest meaningful step using symbolic, numeric, structural, or model-assisted checks as appropriate.
6. Classify the first issue as conceptual, algebraic, arithmetic, sign, notation, assumption, or presentation related.
7. Apply the tutoring policy: confirm correct reasoning, ask a diagnostic question, or provide the weakest useful hint.
8. Stream feedback to the app with verification status and uncertainty.
9. Reveal a full solution only when requested or when the selected study mode allows it.
10. Generate a transfer problem and update mastery only from observable student performance.

Model confidence is not mathematical correctness. Deterministic verification should be preferred when it applies, and the UI must distinguish verified results from model judgment.

## Local persistence and sync

Use SQLite behind repository protocols for structured local data. Store original files and large derived assets in an application-owned attachment vault rather than database blobs. Every local mutation commits in one local transaction and, when sync is enabled, appends an idempotent outbox event in the same transaction.

Synchronization rules:

- the app remains usable while offline;
- attempts and mastery events merge as immutable records;
- editable notes retain revisions and surface conflicts instead of choosing silently;
- attachments use checksums and resumable transfer;
- server acknowledgements advance checkpoints but never delete unacknowledged local work;
- deletion uses tombstones until every participating device acknowledges it;
- schema and sync protocol versions are explicit.

Cross-device support should be designed into identifiers and repositories from the start, but remote sync should be implemented only after local workflows and conflict semantics are tested.

## Math, documents, and rendering

- Preserve both original mathematical input and normalized expressions.
- Treat OCR output as a proposal the student can correct.
- Keep page, bounding-box, and equation-region locations for imported course material.
- Render math consistently in notes, problems, feedback, flashcards, and exports.
- Isolate any embedded web rendering used for math or documents behind a small adapter; it must not become the application architecture.
- Keep symbolic verification separate from tutoring language generation so either can be tested and replaced.

## Security and privacy baseline

- Use the macOS App Sandbox and request only required entitlements.
- Store account and provider credentials in Keychain, never preferences or logs.
- Use security-scoped access only when the student chooses external folders or files.
- Treat PDFs, images, extracted text, equations, and model output as untrusted input.
- Do not log course content or student work by default.
- Encrypt transport and server-side secrets.
- Enforce workspace authorization on every remote course, resource, attempt, attachment, and sync operation.
- Make deletion cover local records, cached derivatives, remote records, stored objects, and queued work.
- Make cloud processing and retention behavior visible before uploading private course material.

## Verification strategy

- Swift unit tests for domain use cases, hint policy, mastery rules, repositories, and sync conflict resolution.
- Native UI tests for sidebar navigation, keyboard commands, paste, drag and drop, problem attempts, offline editing, and accessibility.
- Migration tests that open every historical local schema fixture.
- Go tests for the marketing site and future account/sync contracts.
- Python tests for parsing, OCR normalization, tutoring orchestration, and verifier adapters.
- Contract tests generated from the versioned client/service schema.
- A versioned mathematics evaluation set containing correct steps, common misconceptions, ambiguous notation, and adversarial prompts.
- End-to-end learning evaluations that measure hint leakage, correction quality, transfer-problem validity, and false mastery updates.
- Manual macOS checks for VoiceOver, keyboard-only use, window resizing, multiple windows, sleep/wake, offline recovery, and large course libraries.

## Delivery sequence

1. Keep the Go landing page and image-chat prototype running as the public preview.
2. Scaffold the native macOS app with the sidebar, course workspace, local database, attachment vault, and no AI dependency.
3. Rebuild direct image paste natively and persist problem attempts locally.
4. Add the versioned tutoring contract and a calculus step-checking evaluation set.
5. Deliver the guided calculus loop: attempt, check, hint, retry, and transfer problem.
6. Add mastery events, targeted practice, formula cards, and review scheduling.
7. Introduce accounts and cross-device sync after conflict rules pass local simulations.
8. Expand verified learning workflows into physics and computer-science fundamentals.

The native scaffold is the next architectural milestone. Do not add production product depth to the web prototype before it exists.
