# AI development workflow

This setup separates durable personal preferences from project facts.

## What carries over

### Every Codex project

`~/.codex/AGENTS.md` is the global Codex instruction file. It asks Codex to use the `reviewable-delivery` workflow for software changes and to leave code uncommitted, reviewable, and verified unless you explicitly request a later Git or deployment action.

Repository `AGENTS.md` files add more specific instructions. A nested `AGENTS.md` can refine the rules for one part of a large repository.

### Codex, Claude Code, and OpenCode

The following global skills are installed for all three agents currently present on this machine:

- `reviewable-delivery` turns a coding request into acceptance criteria, useful tests, an implementation, verification, self-review, and a concise handoff.
- `herdr` lets an agent inspect and control Herdr panes when the agent is running inside Herdr.

An agent first sees a skill's name and description. It loads the full `SKILL.md` only when the request matches, or when you invoke the skill explicitly. Use `$reviewable-delivery` when you want to force that workflow for a task.

Global skills apply across projects and fresh sessions. Project skills apply only where that agent discovers them. A skill does not retain facts from an old conversation; persistent project facts belong in `AGENTS.md`, documentation, tests, or the code itself.

The isolation boundary is a task, not a chat window. Each independent or concurrent task gets its own Git worktree and branch. A later session continuing that task reuses its worktree, while read-only investigation needs no additional checkout. Agents leave worktrees in place for your review and report the path and branch at handoff.

### BetterNB only

[`AGENTS.md`](AGENTS.md) defines this repository's working agreement. [`.agent/PLANS.md`](.agent/PLANS.md) defines the living plan format used only for complex features, architectural changes, risky migrations, or work that spans sessions.

The editable source for the custom global skill is [`skills/reviewable-delivery/SKILL.md`](skills/reviewable-delivery/SKILL.md). After changing it, rerun:

```bash
./scripts/install-ai-workflow.sh
```

That copies the current skill to the global agent locations and refreshes the Herdr integrations.

## Daily loop

From a project directory, run:

```bash
herdr
```

Then start `codex`, `claude`, or `opencode` in a pane. Herdr keeps the pane alive when you detach and shows which agents are working, blocked, or done. Use `ctrl+b`, then `q`, to detach; run `herdr` again to reattach.

For an ordinary task, describe the desired outcome and constraints. The delivery loop is:

1. Create or reuse the dedicated worktree and task branch.
2. Turn the request into observable acceptance criteria.
3. Reproduce a bug or write a useful behavior test first when feasible.
4. Implement the smallest coherent change.
5. Run affected tests, lint, type checks, and the deployable build that the repository actually defines.
6. Review the final diff for correctness, security, compatibility, and accidental files.
7. Hand the code back with the worktree, branch, changed behavior, files, verification evidence, risks, and the best review starting point.
8. Prepare preview, smoke, observability, migration, and rollback steps before production deployment. Deploy production only after an explicit request.

You can steer at any point: ask for a different design, request another test case, or edit the code yourself and ask the agent to continue from your changes. The agent is instructed to preserve unrelated work in the tree.

## Project hardening when the stack exists

This repository does not have an application stack yet, so setup stops before inventing toolchain-specific commands. Once the stack is chosen, add its canonical commands to `AGENTS.md` and automate the same checks in CI. A strong default pipeline is formatting and static analysis, unit and integration tests, a production build, dependency and secret checks, a preview deployment, smoke tests, and a production release with health checks and a tested rollback path.

Keep those checks proportional to the project. The goal is fast evidence and reversible delivery, not process for its own sake.
