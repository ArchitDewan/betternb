---
name: reviewable-delivery
description: Deliver software changes that are easy to review and safe to ship. Use when implementing a feature, fixing a bug, refactoring behavior, or preparing a deployment.
---

# Reviewable Delivery

Complete the requested outcome and leave the human with clear evidence that it works. Scale the ceremony to the risk and size of the change.

## Establish the contract

- Read the applicable repository instructions and inspect the current working tree before editing.
- Translate the request into observable acceptance criteria. Resolve routine implementation choices from repository conventions; ask only when a missing choice would materially change the product or risk.
- Find the project's real build, test, lint, typecheck, and run commands from its manifests and CI configuration. Do not invent commands.
- Preserve unrelated work already in the tree. Keep the requested change separate from unrelated cleanup.

For work spanning several components, a risky migration, or multiple milestones, create or maintain the repository's execution plan if it defines one. Keep the plan focused on decisions, progress, validation, and recovery.

## Isolate independent work

Use the task, rather than the conversation, as the isolation boundary. Before editing, inspect the active branch, working-tree status, and existing worktrees.

- Give every independent or concurrently active task its own Git worktree and task branch.
- Reuse the same worktree when a new or resumed session continues that task.
- Read-only investigation does not need a new worktree.
- If the current checkout is already clean and dedicated to the task, keep using it. If it contains another task or unrelated uncommitted work, create or select a separate worktree before editing.
- Do not copy, move, stash, discard, or commit existing uncommitted changes merely to create isolation. Ask for direction if the new task depends on those changes.
- Do not remove a task worktree or branch at handoff. Report its path and branch and leave cleanup to an explicit user request.

When a repository has no initial commit, Git cannot create an additional worktree. Keep initial setup in the primary checkout and do not create a baseline commit unless the user requests it.

## Drive behavior with evidence

For a bug, first reproduce it with the smallest useful test or command when feasible. Confirm that the new test fails for the expected reason before changing the implementation.

For new behavior, add or adjust an automated test first when it expresses a stable user-visible contract. Prefer tests at the lowest level that proves the behavior, plus an integration or end-to-end test only when the boundary itself matters.

Do not add tests that merely repeat implementation details, snapshot volatile output without value, or create more maintenance cost than confidence. For visual-only, documentation, generated, or configuration changes where test-first work is not useful, state the concrete verification method and proceed.

Implement the smallest coherent change that satisfies the contract. Keep interfaces and names consistent with the surrounding code. Update documentation, examples, fixtures, schemas, and generated artifacts only when the changed behavior requires them.

## Verify before handoff

Run the narrowest relevant checks while iterating. Once the change is coherent, run the repository's standard affected checks. For a deployable change, also build or package the same artifact the deployment path will use when practical.

Inspect the final diff as a reviewer. Check for:

- missed acceptance criteria and error paths;
- regressions, unsafe defaults, secrets, and privacy issues;
- compatibility, migrations, accessibility, and operational impact when relevant;
- accidental files, debug output, broad formatting churn, and stale documentation.

Fix issues caused by the change and rerun the checks they affect. Do not claim a check passed unless it ran successfully. If a check cannot run, give the exact blocker and the strongest substitute evidence.

## Prepare and perform deployment

Treat production deployment as a distinct action. Prepare the artifact, migration order, smoke checks, observability checks, and rollback path before requesting or performing that action.

When the user asks for a deployment, prefer a preview or staging environment first when the project supports one. Verify the release identifier and target environment, deploy, run the planned smoke checks, inspect relevant health signals, and report the exact result. Stop and roll back or ask for direction when the release violates an acceptance criterion or its recovery path is uncertain.

## Hand off for human review

Lead with the behavior now available. Include:

- the worktree path and task branch;
- the main files or components changed and why;
- the exact verification performed and its result;
- any manual check that is still useful;
- material risks, assumptions, migration or rollback notes;
- where the reviewer should start reading when the diff is substantial.

Leave the working tree in a reviewable state. Do not commit, push, merge, or deploy unless the user requested that action.
