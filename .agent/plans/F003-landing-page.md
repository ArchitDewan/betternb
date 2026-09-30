# F003: Interactive BetterNB landing page

This plan follows `.agent/PLANS.md` and stays current while the feature is active.

## Purpose and acceptance

Create a high-quality public landing page for BetterNB that communicates the product in a few seconds and rewards scrolling with meaningful interaction. The visual direction takes inspiration from Meuze's confident editorial storytelling and product-led motion while remaining original and specific to active mathematics study.

Acceptance criteria:

- `/` renders a complete BetterNB landing page rather than redirecting immediately into the app.
- The hero clearly explains the math-first product and offers a primary route into the existing prototype plus a secondary jump to the learning story.
- A sticky scroll sequence moves from course context to attempting a problem, checking a step, and strengthening a weak concept.
- The page showcases pasted mathematical work, guided hints, step checking, targeted practice, mastery tracking, and cross-device continuity without claiming later capabilities are already implemented.
- Motion is progressively enhanced, keyboard-safe, and disabled or simplified when `prefers-reduced-motion` is enabled.
- The experience remains usable and visually intentional on desktop and mobile.
- Existing notebook chat routes and tests continue to work.

## Context

F002 established a Go standard-library web server with embedded templates and assets. The landing page will extend that surface without adding a frontend framework or external runtime dependency. The user supplied `https://www.meuze.ai/` as a quality and interaction reference. Its live browser choreography was not available to inspect in the connected browser, so only its publicly readable editorial/product structure and the user's requested scroll-linked interaction are treated as inspiration.

## Plan

1. Add a failing root-route test for the landing-page contract.
2. Add an original server-rendered landing template and route.
3. Build the responsive visual system and product mockups in HTML/CSS.
4. Add a small JavaScript motion controller for scroll progress, sticky story state, counters, pointer depth, and mobile navigation.
5. Verify accessibility fallbacks, existing chat behavior, build checks, and rendered desktop/mobile states.

## Progress

- [x] (2026-09-30) Define the visual concept and acceptance criteria.
- [x] (2026-09-30) Create `feat/F003-landing-page` in a dedicated worktree.
- [x] (2026-09-30) Add and observe the failing landing-page test.
- [x] (2026-09-30) Implement the landing route, visual system, and motion layer.
- [x] (2026-09-30) Verify automated checks and live HTTP delivery.
- [x] (2026-09-30) Complete reviewer handoff; interactive visual review remains manual because no browser connection was available.

## Decisions and discoveries

- Decision: Use an editorial light canvas with deep ink, ultraviolet, coral, and acid-lime accents.
  Rationale: It retains BetterNB's existing purple identity while giving the marketing surface a more distinctive, premium study-tool character.
  Date/Author: 2026-09-30 / Codex.

- Decision: Make scroll motion explain the product rather than act as decoration.
  Rationale: Each motion state maps to a real step in the active-learning loop, so the interaction reinforces comprehension.
  Date/Author: 2026-09-30 / Codex.

- Decision: Keep all artwork code-native.
  Rationale: CSS and inline semantic elements load quickly, scale crisply, avoid licensing risk, and remain easy to revise with the product.
  Date/Author: 2026-09-30 / Codex.

- Decision: Reposition BetterNB from a generic inspectable research notebook to a math-first active study workspace.
  Rationale: The user intends to serve engineering students broadly through shared foundations in mathematics, physics, and computer science, with mathematics as the first focus.
  Date/Author: 2026-09-30 / User and Codex.

- Decision: Make the production product a native, local-first macOS application; keep the current Go surface for marketing and temporary prototypes only.
  Rationale: The desired experience is a desktop study workspace with persistent course navigation, a large content canvas, keyboard-first interactions, and native file and clipboard behavior.
  Date/Author: 2026-09-30 / User and Codex.

## Validation

Validation completed on 2026-09-30:

- `go test ./...` passed.
- `go test -race ./...` passed.
- `go vet ./...` passed.
- `go build -o /private/tmp/betternb-F003 ./cmd/betternb` passed.
- `node --check internal/web/assets/landing.js` and the existing chat script check passed.
- A built local server returned `200` with the expected content types for `/`, `/assets/landing.css`, `/assets/landing.js`, and `/notebooks/research`.

The in-app browser connection was unavailable, so automated desktop/mobile screenshots and live scroll-state inspection could not be completed. Manual review should exercise the hero pointer depth, four sticky story states, mobile navigation, reduced-motion mode, and the link into `/notebooks/research`.

## Recovery

All work is isolated in the F003 worktree and branch. No database, migration, or external service is involved. The landing route can be reverted independently; the existing notebook route remains directly accessible throughout development.

## Outcome

The landing page now replaces the root redirect with an original BetterNB marketing experience: a clear math-first hero, honest product-status language, scroll-linked learning story, product-horizon bento grid, cross-device scene, and prototype CTA. It uses embedded HTML/CSS/JavaScript only, preserves the existing notebook route, and includes progressive no-JavaScript and reduced-motion behavior. The product and architecture briefs now define BetterNB as a native, local-first macOS study workspace and limit the Go web surface to marketing and temporary prototypes.

The remaining review risk is visual rather than functional: rendered screenshots could not be captured through the unavailable browser connection. No external assets, database changes, migrations, or deployment changes were introduced.
