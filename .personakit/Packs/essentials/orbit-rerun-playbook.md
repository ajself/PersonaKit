# Orbit Rerun Playbook

Use this runtime playbook when Samwise is staging or resuming a fresh Orbit attempt from `main`.
For extended workflow detail, see `orbit-rerun-playbook-reference`.

## Core Rules

1. Treat the approved lane contract as the durable identity of the attempt.
2. Keep startup and execution as separate session surfaces:
   - `samwise-orbit-rerun-startup` for staging and contract freeze
   - `samwise-orbit-rerun-execution` for live lane orchestration
3. Do not rebuild the rerun from thread memory alone; start from the named execution artifacts.

## Startup Checklist

Before the first code slice:

1. Confirm the active attempt branch, worktree path, and commit authorization mode.
2. Confirm the lane contract from the repo root.
3. Materialize and preflight the approved worktree only when live execution is approved.
4. Freeze the first slice, required participants, and expected evidence paths.
5. Hand the live lane contract to `samwise-orbit-rerun-execution` before substantive implementation begins.

## Review Gates

Do not claim `review-ready` or `MVP candidate` until:

1. Required implementation and review sessions contributed evidence.
2. Product, interaction, validation, and retrospective artifacts exist at the declared attempt-specific paths.
3. Active participants are supported by participant evidence.
4. AJ reviewed any success claim or promotion recommendation.
