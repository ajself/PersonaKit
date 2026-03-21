# Orbit M4 Lane

Status: Active
Owner: orbit-meeting-coordinator
Owner Session: `orbit-meeting-coordinator-delivery`
Branch: `codex/m4`
Authorization Mode: `per-commit-approval`
Workspace Scope: Orbit
Source Branch: `main`
Promotion Target: `main`
Manifest Digest: `0002b494d920`

## Purpose

Keep the approved lane scope and approval mode visible inside the worktree so
orbit-meeting-coordinator can resume execution without re-asking what contract applies here.

## Scope Boundary

M4 milestone execution only. Work packets `M4-P1` through `M4-P5` in order inside this single lane/worktree, stop at packet review gates, and do not expand into M5 meeting promotion or M7 workstream behavior.

## Plan References

- `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/README.md`
- `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/Decision-Register.md`
- `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/Quality-Bar.md`
- `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/Validation-And-Review-Matrix.md`

## Stop And Ask AJ When

- promotion to main
- scope expansion beyond M4 or out-of-order packet execution without AJ approval
- runtime behavior that depends on M5 meeting promotion or M7 workstream semantics
- destructive git actions

## Startup Checklist

1. Run `Scripts/check-worktree-lane.sh --mode contract`.
2. Re-read the plan references listed above.
3. Confirm the next bounded work item still fits the lane scope boundary.
4. Run baseline validation before broad implementation changes when code work is
   about to begin.

## Promotion Rule

This lane does not promote itself. AJ decides when or whether work moves beyond
this lane or back toward `main`.
