# Worktree Lane Approvals

Status: Active  
Owner: AJ + Samwise  
Last Reviewed: 2026-03-10

## Purpose

Provide the machine-readable approval source for named lanes that AJ has
already approved.

This exists for the case where:

1. AJ stages or approves a lane before a local execution worktree exists.
2. Samwise later verifies the lane contract from the repo root.
3. Live execution materializes a dedicated worktree only when kickoff begins.
4. The repo needs a deterministic way to answer whether standing authority
   applies in that exact lane.

## Canonical Files

1. `Docs/PersonaKit/Development/worktree-lane-approvals.json`
2. `Scripts/check-worktree-lane.sh`
3. `Scripts/bootstrap-worktree-lane.sh`
4. `Scripts/check-worktree-lane-approvals.sh`

## Rules

1. The manifest defines lane identity; it does not make a local worktree the
   source of truth.
2. The manifest does not create worktrees or branches by itself.
3. The manifest does not authorize repository `main`.
4. Approval applies only to the exact named non-`main` lane in the manifest.
5. If a branch is missing from the manifest, fall back to per-commit AJ
   approval.
6. An executable lane may optionally pin `startPoint` so startup and execution
   materialize the same base even if `main` moves later.
7. Promotion, destructive git actions, and scope changes outside the approved
   lane still escalate to AJ.

## Standard Use

1. AJ records or approves the lane in the manifest and any attempt-specific
   prep artifact.
2. Samwise verifies the lane contract from the repo root:
   - `Scripts/check-worktree-lane.sh --mode contract --branch <branch>`
3. When live execution is approved, materialize the lane into a dedicated
   worktree:
   - `Scripts/materialize-worktree-lane.sh --branch <branch> --path /absolute/path/to/worktree`
4. Inside the materialized worktree, run `Scripts/check-worktree-lane.sh`
   before relying on standing commit authority.
5. If any step fails, stop and ask AJ.

## AJ In Codex

Use this flow when AJ is still the one clicking the worktree UI:

1. Confirm the approved lane from the repo root:
   - `Scripts/check-worktree-lane.sh --mode contract --branch <branch>`
2. Materialize the approved lane into the new worktree:
   - `Scripts/materialize-worktree-lane.sh --branch <branch> --path /absolute/path/to/worktree`
3. Open the new worktree thread.
4. Re-run `Scripts/check-worktree-lane.sh` if needed.
5. Start work only after the standing-authority check passes.

## Current Named Lanes

1. `main`
   - protected, manual review only
2. `codex/orbit-1`
   - current manifest-approved fresh-main Orbit rerun lane
3. `codex/orbit-foundation`
   - historical first-run Orbit MVP lane
4. `codex/orbit-learning-loop`
   - historical exploratory post-MVP lane from the first Orbit exercise

## Orbit Attempt Naming Rule

For future fresh-main Orbit reruns, use a simple incrementing integer branch
name:

1. `codex/orbit-1`
2. `codex/orbit-2`
3. `codex/orbit-3`

Rules:

1. increment the integer for each new fresh-main Orbit attempt
2. do not reuse an older Orbit attempt branch name
3. keep the integer as the attempt number, not as a milestone label
4. recording the next integer in a prep note does not approve or create that
   lane by itself

The original named Orbit lanes remain valid historical branches, but new Orbit
reruns should follow the integer pattern.

For the current next attempt, use `codex/orbit-1`.
Orbit rerun startup may verify that lane contract from the repo root before a
worktree exists; live execution begins only after the lane is materialized and
the worktree preflight passes.

## Notes

- Lane notes are generated from the manifest so a materialized execution
  worktree has a local, readable scope brief.
- The generated note is deterministic, includes a manifest digest, and can be
  recreated from the manifest.
- `Scripts/check-worktree-lane.sh --mode contract` allows repo-root startup to
  verify the lane without requiring a materialized worktree.
- `Scripts/check-worktree-lane.sh` in default authority mode still treats a
  missing or stale lane note as a failing preflight for executable lanes.
