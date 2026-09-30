# Feature-session development model

BetterNB uses one long-lived integration thread for product coherence and one isolated worktree and agent session for each independent feature.

## Roles

### Integration session

The integration session owns the product brief, architecture boundaries, roadmap, cross-feature decisions, and final review. It keeps a broad view and avoids becoming a second implementation owner for an active feature.

### Feature session

A feature session owns one observable outcome in one worktree and branch. It maintains its execution plan, tests its behavior, reviews its final diff, and hands back the worktree path, branch, verification evidence, and known risks.

### Short-lived specialist agents

A feature session may use bounded specialist agents for independent work such as documentation research, evaluating two designs, reviewing security, or finding missing tests. Specialists should return findings to the feature owner. They should not concurrently edit the same worktree.

Use multi-agent execution when work is genuinely independent. Keep ordered design and implementation decisions with one owner, especially while schemas and interfaces are moving.

## Feature lifecycle

1. Define the user-visible outcome and acceptance criteria in `.agent/plans/<feature>.md`.
2. Confirm dependencies and stable contracts with the integration session.
3. Create a dedicated worktree and task branch.
4. Establish a failing behavior test or another concrete baseline when feasible.
5. Implement and verify the smallest complete vertical slice.
6. Run a separate review pass for correctness, security, missing tests, and integration risk.
7. Hand the worktree back to the integration session.
8. Review and revise with the user before committing, merging, or deploying.
9. Merge only after the feature's contracts, migrations, and verification evidence are accepted.
10. Remove the worktree only after the user requests cleanup.

## Branch and worktree identity

Use feature identifiers so conversations, plans, branches, and worktrees remain easy to match:

```text
F001 grounded notebook
plan:     .agent/plans/F001-grounded-notebook.md
branch:   feat/F001-grounded-notebook
worktree: <worktree-root>/F001-grounded-notebook
```

A new session continuing `F001` reuses that worktree. A separate feature receives a new identifier and worktree.

## When to run features in parallel

Start parallel work only when each feature has an independent acceptance boundary and depends on stable shared contracts. Good examples include a source viewer built against an accepted citation schema and a notes editor built against an accepted notes API.

Keep work sequential when tasks both change authentication, shared database tables, public API schemas, design tokens, or deployment infrastructure. Parallel research is still useful in those cases; concurrent implementation usually is not.

Begin with at most two implementation features at once. Add a third only after integration remains routine and the test suite catches contract drift reliably.

## Handoff packet

Every feature handoff includes:

- feature identifier, worktree path, and branch;
- user-visible behavior delivered;
- best file or component for review to start;
- tests and checks run with results;
- schema, API, migration, security, and operational impacts;
- screenshots or a short manual verification path for UI work;
- unresolved risks and the rollback or removal path.
