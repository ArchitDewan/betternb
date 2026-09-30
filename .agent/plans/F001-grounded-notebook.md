# F001: Grounded-notebook vertical slice — superseded

Status: superseded on 2026-09-30 by the accepted math-first native macOS direction. Do not continue this plan.

## Purpose and acceptance

F001 originally proposed a browser-based research notebook centered on PDF ingestion and cited answers. The user subsequently chose a different product: a native macOS active study workspace for mathematics, later extending into physics and computer-science fundamentals.

The active product contract now lives in `docs/PRODUCT.md` and the native system direction in `docs/ARCHITECTURE.md`. Any new execution plan must derive acceptance criteria from those documents rather than from the original F001 scope.

## Context

This file remains only to preserve the decision history and prevent a later session from accidentally resuming the obsolete plan. The Go application created after F001 is limited to the public landing page and temporary interaction prototypes.

## Plan

No remaining milestones are active. The next architectural milestone is a native macOS workspace scaffold with local persistence, course navigation, and no required AI dependency.

## Progress

- [x] (2026-09-29) Record the original research-notebook direction.
- [x] (2026-09-30) Supersede the web-product plan after the user selected a math-first native macOS application.

## Decisions and discoveries

- Decision: Do not implement the original Go web product, grounded-answer path, PDF ingestion pipeline, or citation-first vertical slice as F001.
  Rationale: They optimize for the wrong product and platform. BetterNB now centers on mathematical attempts, progressive hints, step checking, targeted practice, and mastery inside a native desktop workspace.
  Date/Author: 2026-09-30 / User and Codex.

## Validation

Confirm that `docs/PRODUCT.md` identifies the math-first learner and guided-problem loop, and that `docs/ARCHITECTURE.md` identifies the native macOS application as the product while limiting the Go web surface to marketing and prototypes.

## Recovery

No F001 application implementation or migration exists to recover or roll back. Historical details remain available in Git history.

## Outcome

F001 is closed without implementation. A future native-workspace feature should receive a new identifier and execution plan.
