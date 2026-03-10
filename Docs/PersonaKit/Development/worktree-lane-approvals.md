# Worktree Lane Approvals

Status: Active  
Owner: AJ + Samwise  
Last Reviewed: 2026-03-10

## Purpose

Provide the machine-readable approval source for named worktree lanes that AJ
has already approved.

This exists for the case where:

1. AJ creates a branch/worktree manually in the Codex UI.
2. Samwise later resumes inside that worktree without AJ present.
3. The repo needs a deterministic way to answer whether standing authority
   applies in that exact lane.

## Canonical Files

1. `Docs/PersonaKit/Development/worktree-lane-approvals.json`
2. `Scripts/check-worktree-lane.sh`
3. `Scripts/bootstrap-worktree-lane.sh`
4. `Scripts/check-worktree-lane-approvals.sh`

## Rules

1. The manifest does not create worktrees or branches.
2. The manifest does not authorize repository `main`.
3. Approval applies only to the exact named non-`main` lane in the manifest.
4. If a branch is missing from the manifest, fall back to per-commit AJ
   approval.
5. Promotion, destructive git actions, and scope changes outside the approved
   lane still escalate to AJ.

## Standard Use

1. AJ creates the branch/worktree in the Codex UI.
2. Samwise runs `Scripts/bootstrap-worktree-lane.sh` inside that worktree.
3. Samwise runs `Scripts/check-worktree-lane.sh` before relying on standing
   commit authority.
4. If either script fails, stop and ask AJ.

## AJ In Codex

Use this flow when AJ is still the one clicking the worktree UI:

1. Create the approved branch/worktree in Codex.
2. Open the new worktree thread.
3. Run `Scripts/bootstrap-worktree-lane.sh`.
4. Run `Scripts/check-worktree-lane.sh`.
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
Orbit rerun startup should begin only after that exact lane is present in the
manifest and the worktree preflight passes.

## Notes

- Lane notes are generated from the manifest so the active worktree has a local,
  readable scope brief.
- The generated note is deterministic, includes a manifest digest, and can be
  recreated from the manifest.
- `Scripts/check-worktree-lane.sh` treats a missing or stale lane note as a
  failing preflight for executable lanes.
