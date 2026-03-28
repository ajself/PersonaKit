# Worktree Squad Gating Contract

Use this runtime contract for `worktree-squad-delivery` loops.
For expanded gate detail, see `worktree-squad-gating-contract-reference`.

## Scope Rules

1. Primary repository `main` is protected.
2. Execution happens only in the declared isolated non-`main` worktree.
3. The active loop must record branch, worktree path, and authorization mode before editing.

## Authorization Modes

1. `per-commit-approval`:
   - no commit without explicit AJ approval for that commit
2. `worktree-auto-commit-approved`:
   - valid only when AJ explicitly approved standing authority for that exact worktree scope

## Required Loop Evidence

Each loop should record:

1. One bounded work item.
2. Acceptance criteria and verification commands.
3. Verification outcomes.
4. Review findings with blocker / major / minor severity.
5. Residual risks and next actions.

## Stop Conditions

Stop and ask AJ if:

1. The active scope appears to be primary `main`.
2. Authorization mode is missing or ambiguous.
3. A blocker remains unresolved.
4. Required verification cannot run and no bounded fallback remains.
5. A gate crossing, scope expansion, or destructive git action is proposed.
