# Execution plans

Use an execution plan for work that spans several components, has meaningful architectural uncertainty, changes persistent data, or is likely to take multiple work sessions. Small, well-bounded changes do not need one.

Store active plans in `.agent/plans/<short-task-name>.md`. A plan is a living handoff document: someone with only the repository and the plan must be able to understand the intended outcome, continue the work, and verify it.

Each plan must contain:

## Purpose and acceptance

Describe what changes for the user and how a human can observe success. State concrete acceptance criteria.

## Context

Name the relevant files, components, interfaces, and constraints. Explain only the repository-specific context needed to continue the task.

## Plan

Describe the implementation in independently verifiable milestones. Include migrations, compatibility concerns, and rollout order when relevant.

## Progress

Maintain timestamped checkboxes for completed and remaining work. Update this section whenever work pauses or the approach changes.

## Decisions and discoveries

Record decisions that constrain later work, their rationale, and evidence from prototypes, tests, logs, or documentation. Capture surprises that changed the plan.

## Validation

List exact automated and manual checks, expected behavior, and the evidence collected. Include deployment smoke checks when applicable.

## Recovery

Explain how interrupted steps can resume safely and how risky changes or deployments can be rolled back.

## Outcome

At completion, compare the delivered behavior with the acceptance criteria and note any remaining work.
