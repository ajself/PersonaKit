# Orbit M4 preflight Lane

Status: Active
Owner: Samwise
Branch: `codex/m4-preflight`
Authorization Mode: `per-commit-approval`
Workspace Scope: Orbit
Source Branch: `main`
Promotion Target: `main`
Manifest Digest: `b4da4b7f4765`

## Purpose

Keep the approved lane scope and approval mode visible inside the worktree so
Samwise can resume execution without re-asking what contract applies here.

## Scope Boundary

M4 dossier hardening, preflight review, and bounded packet-kickoff preparation only. No runtime-facing implementation, M5 meeting promotion, or M7 workstream behavior.

## Plan References

- `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/README.md`
- `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/Decision-Register.md`
- `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/Validation-And-Review-Matrix.md`

## Stop And Ask AJ When

- promotion to main
- runtime-facing M4 packet work before AJ explicitly authorizes the packet
- scope expansion into M5 meeting promotion or M7 workstream behavior
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
