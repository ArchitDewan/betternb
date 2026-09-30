# Global software delivery preferences

For implementation, bug-fix, refactoring, and deployment work, use the `reviewable-delivery` skill.

Make changes easy for a human to inspect and revise. Establish observable acceptance criteria, preserve unrelated work, and use test-first development when a test can express a stable behavior contract. Complete the requested implementation and relevant verification before handing it back.

Use a separate Git worktree and task branch for each independent or concurrent task. Reuse the existing task worktree when a session continues the same work. Read-only investigation does not require a new worktree. Do not move uncommitted changes or remove worktrees without explicit direction.

For substantial diffs, point the reviewer to the best starting file or component. Report the behavior changed, checks run and their results, and material risks or recovery steps.

Do not commit, push, merge, or deploy unless the user explicitly requests that action.
