# BetterNB product brief

Status: math-first direction, intended for review and revision.

## Product thesis

BetterNB is an active study workspace for technical subjects, starting with mathematics. It turns lecture material, equations, diagrams, problem sets, and a student's own work into guided practice that builds problem-solving ability instead of simply producing answers.

The first product promise is simple: when a student is stuck on a math problem, BetterNB helps them identify the next useful step, understand where their reasoning broke, and practice the underlying concept until they can solve a new problem independently.

## Initial user

The first user is a university student studying calculus, linear algebra, or other foundational mathematics for engineering, physics, computer science, or mathematics itself.

The product should eventually support physics and computer-science fundamentals, but the first learning interactions should be excellent for math before broadening into adjacent technical domains.

## Product form

BetterNB is primarily a native macOS application with a local-first course workspace. The public website explains the product and may host temporary interaction prototypes, but the browser is not the production study interface. Cross-device synchronization is a later service capability built on top of trustworthy local persistence.

## Core loop

1. Bring in course context such as lecture notes, textbook sections, formula sheets, worked examples, and problem sets.
2. Attempt a problem independently, typing steps or pasting an equation, diagram, or handwritten solution into chat.
3. Receive feedback on the reasoning so far without being handed the complete answer by default.
4. Request progressively stronger hints when needed.
5. Finish the solution and explain the concept in the student's own words.
6. Practice a targeted variation and schedule review based on demonstrated mastery.

## Baseline capabilities

- Create and organize course notebooks by subject and unit.
- Add PDFs, text, equations, diagrams, code snippets, and pasted images.
- Recognize mathematical notation in typed and visual work.
- Check intermediate steps, assumptions, algebra, and final results.
- Offer a configurable hint ladder before revealing a full solution.
- Generate practice problems aligned with course material and current ability.
- Create formula cards, conceptual flashcards, and short quizzes.
- Track concept mastery and revisit weak skills through spaced review.
- Preserve a student's attempts and corrections so progress is visible.

Generic document summaries and generated artifacts are not the core product. They are useful only when they improve technical understanding or practice.

## First differentiator: guided problem solving

BetterNB should behave like a patient technical tutor rather than an answer generator:

- ask what the student has tried before solving the problem;
- validate each meaningful step and identify the first point where reasoning diverges;
- distinguish conceptual errors, algebra mistakes, notation issues, and arithmetic slips;
- adapt hints from a light nudge to a worked explanation under the student's control;
- use the notation and methods taught in the student's course;
- generate a nearby problem that tests the same idea in a different form;
- treat independent success on a new problem as stronger evidence of mastery than reading an explanation.

The experience fails if it produces a polished solution that the student can copy without learning how to reproduce the reasoning.

## First learning vertical slice

A single student can:

1. open a calculus notebook;
2. paste or upload a calculus problem and optionally add relevant course notes;
3. submit an attempted first step;
4. receive a correct assessment of that step and a focused explanation when it is wrong;
5. ask for a hint that does not reveal the remaining solution;
6. complete the problem through multiple checked steps;
7. receive one targeted follow-up problem covering the same concept;
8. see the relevant concept marked for future review.

The slice is complete only when the tutor's mathematical feedback is correct, the hint sequence genuinely preserves productive struggle, and the follow-up problem tests transfer rather than superficial repetition.

The workflow to finish that notebook — what is already shipped, the remaining feature sequence, and the “done” bar — lives in [MATH-NOTEBOOK.md](MATH-NOTEBOOK.md).

## Later feature tracks

- Mathematics: algebra, calculus, linear algebra, differential equations, probability, discrete math, and proof practice.
- Physics: unit-aware calculations, diagrams, vector reasoning, mechanics, electricity and magnetism, and simulation.
- Computer science: algorithms, data structures, discrete mathematics, code tracing, debugging, and complexity analysis.
- Active learning: adaptive practice, spaced repetition, mastery maps, exam modes, and study planning.
- Course context: textbook and lecture ingestion, notation alignment, cited explanations, and instructor-specific methods.
- Interactive tools: graphing, symbolic manipulation, numerical experiments, code execution, and parameter exploration.
- Collaboration: shared courses, study groups, instructor feedback, and classroom assignments.
- Control: model selection, private or local execution, retention policies, and cost budgets.

## Decisions still open

- Which first mathematics course should shape the initial problem set and evaluation suite.
- How symbolic computation should be used without hiding reasoning from the student.
- What evidence is sufficient to update a concept's mastery level.
- Which macOS versions and Apple-device companions belong in the first supported platform matrix.
- Initial model, vision, OCR, and mathematical-verification providers.
