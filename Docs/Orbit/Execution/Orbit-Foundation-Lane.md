# Orbit MVP Lane

Status: Active
Owner: Samwise
Branch: `codex/orbit-foundation`
Authorization Mode: `worktree-auto-commit-approved`
Workspace Scope: Orbit
Source Branch: `main`
Promotion Target: `main`
Manifest Digest: `443d373f9733`

## Purpose

Keep the approved lane scope visible inside the worktree so Samwise can resume
execution without re-asking whether standing authority applies here.

## Scope Boundary

Phase 1, Phase 2, and minimal Phase 3 only.

## Plan References

- `Docs/Orbit/Planning/Orbit-Execution-Plan.md`
- `Docs/Orbit/Planning/Orbit-First-Checkpoint-Runtime-Model.md`
- `Docs/Orbit/Planning/Orbit-macOS-Command-Center.md`

## Stop And Ask AJ When

- promotion to main
- scope expansion beyond the MVP boundary
- major architecture change outside the approved Orbit plan
- destructive git actions

## Startup Checklist

1. Run `Scripts/check-worktree-lane.sh`.
2. Re-read the plan references listed above.
3. Confirm the next bounded work item still fits the lane scope boundary.
4. Run baseline validation before broad implementation changes when code work is
   about to begin.

## Promotion Rule

This lane does not promote itself. AJ decides when or whether work moves beyond
this lane or back toward `main`.
