# Orbit Rerun Execution Map

Use this essential when Samwise is running an approved Orbit rerun lane as a
real multiagent delivery loop instead of as a startup-only pass.

## Purpose

1. Split Orbit reruns into a deterministic startup surface and a deterministic
   execution surface.
2. Force explicit session routing before implementation begins.
3. Prevent Samwise from doing substantive Orbit implementation solo unless AJ
   explicitly allows fallback.
4. Make external-worktree approval prompts an expected environment note instead
   of a surprise during execution.

## Session Split

Use the Orbit sessions in this order:

1. `samwise-orbit-rerun-startup`
   startup and staging only
2. `samwise-orbit-rerun-execution`
   active lane orchestration only

Do not let the startup session stand in for a claimed multiagent execution run.

## Default Specialist Session Map

When `samwise-orbit-rerun-execution` is active, route work through these
session surfaces unless AJ explicitly approves a different map:

1. implementation owner
   `worktree-squad-delivery`
2. product review
   `venture-product-tracking`
3. interaction-quality review
   `studio-interaction-quality`
4. validation and evidence review
   `studio-coverage`
5. retrospective closeout
   `worktree-squad-retrospective`

If one of these sessions is missing or no longer fits the active Orbit scope,
stop and repair the routing before implementation begins.

## Handoff Conditions

Only hand Orbit from startup into live execution when all are true:

1. the exact lane branch is manifest-approved
2. the worktree exists
3. `Scripts/bootstrap-worktree-lane.sh` passed
4. `Scripts/check-worktree-lane.sh` passed
5. baseline validation passed
6. participant ownership is explicit
7. attempt-specific evidence paths are explicit

## Execution Rules

Once `samwise-orbit-rerun-execution` begins:

1. Samwise remains coordinator, gatekeeper, and synthesis owner.
2. Samwise must activate the implementation session before any substantive code
   work is treated as valid rerun execution.
3. Samwise must not do substantive implementation solo unless AJ explicitly
   approves solo fallback for the current checkpoint.
4. Planned roles do not count as active participants.
5. A valid rerun must include:
   - at least one persona-backed implementation session
   - at least two distinct non-implementation review sessions
   - participant evidence for every active role
6. Product acceptance, interaction-quality review, validation closeout, and
   retrospective closeout are required evidence, not optional polish.

## External Worktree Approval Note

If the active Orbit worktree lives outside the primary repository root, command
execution in this desktop environment may trigger approval prompts for
bootstrap, build, test, or file-writing commands.

Treat that as an environment-scope warning, not as a product or process
failure. Samwise should surface the note early in the run so AJ knows approval
prompts are expected before the implementation loop deepens.

## Non-Goals

- Do not treat one strong solo Samwise code pass as a successful multiagent
  Orbit rerun.
- Do not let implicit role assumptions replace explicit session routing.
- Do not hide environment approval friction until it interrupts the run.
