# Worktree Squad Gating Contract

Use this contract for `worktree-squad-delivery` loops.

## Scope Rules

1. Primary repository `main` is protected and never mutated without explicit AJ permission.
2. Isolated worktrees are allowed execution scopes.
3. A worktree branch named `main` is valid only when it is isolated from primary `main`.

## Authorization Modes

1. `per-commit-approval` (default):
  - No commit without explicit AJ approval for that commit.
2. `worktree-auto-commit-approved`:
  - Allowed only when AJ explicitly approved auto-commit for the exact isolated worktree scope.
  - Scope approval is not transferable across worktrees.

## Loop Contract

1. One bounded work item per loop unless AJ expands scope.
2. Every loop records:
  - active scope (`branch`, `worktree`)
  - authorization mode
  - acceptance criteria
  - verification commands and outcomes
  - residual risks
  - next 3 queued actions
3. Samwise remains orchestration lead for agent assignment and gate decisions.
4. Worktree Squad Lead runs implementation/review acceleration inside declared gates.
5. When an assignment closes, `worktree-squad-retrospective` is required.
6. Rosie may run retrospective gardening to recommend next-iteration improvements.

## Gate Evidence

Before crossing a gate, evidence must include:

1. Staff-level code review note with severity classes:
  - blocker
  - major
  - minor
2. Verification outcomes for required checks (build/test/snapshot or equivalents).
3. Explicit disposition for each non-blocker finding:
  - `fix-now`
  - `accept`
  - `defer`

## Stop Conditions

Stop and request AJ direction if:

1. Active scope appears to be primary `main`.
2. Authorization mode is missing or ambiguous.
3. A blocker finding remains unresolved.
4. Required verification cannot run and no non-blocked fallback work remains.
5. Any blocker remains unresolved by the next checkpoint (escalate with
   bounded options before continuing).
