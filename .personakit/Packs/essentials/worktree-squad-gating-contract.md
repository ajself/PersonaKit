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
3. Xcode/macOS app and CLI verification in this repo uses
   `xcodebuildmcp` for app build verification (`PersonaKitStudio`) and CLI
   build (`PersonaKitCLI`), plus `xcodebuild` with `PersonaKit` and
   `.build/DerivedData` for app launch/test coverage.
4. Package, unit, and snapshot verification in this repo uses `swift test`,
   which also writes into `.build`.
5. Samwise remains orchestration lead for agent assignment and gate decisions.
6. Worktree Squad Lead runs implementation/review acceleration inside declared gates.
7. When an assignment closes, `worktree-squad-retrospective` is required.
8. Rosie may run retrospective gardening to recommend next-iteration improvements.

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
4. Owner-side red-pen evidence for each deliverable being advanced:
  - minimum `3` self-review passes before the owner calls the deliverable done
  - pass 1 should target structure and scope discipline
  - pass 2 should target correctness, bugs, and edge cases
  - pass 3 should target clarity, product fit, or maintainability as appropriate
5. Clear note describing what changed between red-pen passes when non-trivial
   issues were found.

## Red-Pen Discipline

Treat red-pen review as required craft work, not optional polish.

1. Every squad member should red-pen their own deliverable at least three times
   before declaring it done.
2. A `deliverable` may be code, UI, plan, report, checklist, or another bounded
   artifact owned by one role.
3. If a deliverable changes materially after external review, the owner should
   run at least one fresh red-pen pass before re-submitting it.
4. The squad should not treat "first working draft" as equivalent to
   checkpoint-ready output.
5. When a review role owns its own report or assessment, that report should also
   receive the same red-pen discipline before handoff.

## Stop Conditions

Stop and request AJ direction if:

1. Active scope appears to be primary `main`.
2. Authorization mode is missing or ambiguous.
3. A blocker finding remains unresolved.
4. Required verification cannot run and no non-blocked fallback work remains.
5. Any blocker remains unresolved by the next checkpoint (escalate with
   bounded options before continuing).
6. A deliverable is being advanced without evidence that its owner completed the
   minimum red-pen passes.
