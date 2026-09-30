# BetterNB product brief

Status: initial direction, intended for review and revision.

## Product thesis

BetterNB is an inspectable AI research notebook. It turns a collection of sources into grounded answers, connected notes, and reusable outputs while keeping the evidence behind every result easy to inspect.

The first product promise is simple: a user can ask a question about their material, receive a useful answer, and immediately verify each important claim against the exact source passage.

## Initial user

The working assumption is an individual student, researcher, analyst, or knowledge worker handling a focused body of material. Team collaboration can follow after the single-user research loop is trustworthy.

## Core loop

1. Collect sources into a notebook.
2. Understand them through summaries, search, and grounded conversation.
3. Save useful findings as editable notes.
4. Create outputs such as study guides, reports, comparisons, and timelines.
5. Verify the result by tracing claims back to source passages.

## Baseline capabilities

- Create and organize notebooks.
- Add PDFs, text, and web sources, with visible processing state and errors.
- Ask questions across selected sources.
- Return answers with citations that open the supporting passage in context.
- Save answers, excerpts, and original writing as notes.
- Generate structured outputs from notebook sources.
- Export or delete user content predictably.

These capabilities establish the category baseline. Current Gemini Notebook also includes source discovery, code-backed analysis, audio and video summaries, and many generated output formats. BetterNB should not attempt all of that in its first release.

## First differentiator: inspectable evidence

BetterNB should make grounding clearer than a simple citation badge:

- break an answer into claims and show which source passages support each claim;
- distinguish direct support, weak support, and model inference;
- expose the retrieved context used to answer the question;
- warn when sources disagree or a claim lacks sufficient evidence;
- let a user turn a cited passage into a note without losing provenance.

This differentiator is useful before the product has a large feature count and gives us measurable quality criteria.

## First vertical slice

A single user can:

1. create a notebook;
2. upload one PDF;
3. see ingestion progress and a useful failure message;
4. ask a question about the PDF;
5. receive a streamed answer with at least one valid citation;
6. open the cited page and highlighted passage;
7. save the answer as an editable note;
8. delete the notebook and its stored source data.

The slice is complete only when the citation points to text that actually supports the answer. A plausible answer with a decorative or incorrect citation is a failure.

## Later feature tracks

- Source types: websites, pasted text, video transcripts, cloud documents, and datasets.
- Research: source discovery, cross-notebook search, evidence graphs, and disagreement detection.
- Learning: flashcards, quizzes, spaced repetition, and adaptive study plans.
- Creation: reports, presentations, data visualizations, audio, and reusable output recipes.
- Collaboration: shared notebooks, comments, roles, and review history.
- Control: model selection, private or local execution, retention policies, and cost budgets.

## Decisions still open

- Which user group should shape the first release most strongly.
- Hosted-only, local-first, or hybrid deployment.
- Initial model and embedding providers.
- Whether collaboration belongs before richer individual workflows.
- Which differentiator should follow inspectable evidence.
