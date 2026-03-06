# PersonaKit Studio Multi-Agent Acceleration Plan

Date: 2026-03-06

## Summary

This plan defines a pragmatic, architecture-safe way to accelerate PersonaKit Studio work using multiple agents in parallel.

Plan dependency:

1. Execute `Docs/Plan/personakit-pack-expansion-plan.md` first.
2. Start this Studio acceleration plan only after that pack-expansion plan is complete and validated.
3. The required pack artifacts are now present and committed (`2f1e0c7`, `88c702f`).

Core objectives:

1. Stabilize concurrency reliability before parallel polish work.
2. Preserve architectural invariants (actor isolation, explicit IO boundaries, deterministic mutation).
3. Increase delivery throughput with disjoint, multi-agent lanes.
4. Keep human review at explicit stop points.

## Phase 0 Closeout Status

Updated: March 6, 2026

Status: Phase 0 reliability gate implementation and verification complete in this worktree.

Evidence:

1. Former flaky test (`refreshPreviewRestartsAfterCancellationForSameSession`) was stabilized and passed 20 consecutive runs.
2. Full test suite passed twice back-to-back:
   - `swift test` -> pass
   - `swift test` -> pass
3. Adjacent Studio async suites passed:
   - `swift test --filter WorkspaceSessionFeatureModelMapTests` -> pass
   - `swift test --filter WorkspaceStoreSessionActionsTests` -> pass
   - `swift test --filter WorkspaceStoreWorkspaceFlowTests` -> pass
4. Parallel-safe validation gate passed:
   - `TMPDIR=/tmp/personakit-$USER-phase0 ./Scripts/validate-repo.sh` -> pass

Phase 0 exit criteria are satisfied.

Stop point status:

1. Human review sign-off is still required before any Phase 1 lane work starts.

## Active PersonaKit Sessions

Use these sessions to ground each lane:

1. Phase 0 / Reliability lane:
   - Session: `studio-reliability`
   - Persona: `studio-reliability-engineer`
   - Directive: `stabilize-preview-cancellation`
2. Lane B / Boundary hardening:
   - Session: `studio-boundary`
   - Persona: `studio-boundary-guardian`
   - Directive: `harden-session-boundaries`
3. Lane C / Coverage expansion:
   - Session: `studio-coverage`
   - Persona: `studio-coverage-architect`
   - Directive: `expand-core-coverage`
4. Lane D / Workflow polish:
   - Session: `studio-workflow`
   - Persona: `studio-workflow-operator`
   - Directive: `harden-validation-workflow`
5. Integration lane:
   - Session: `studio-integration`
   - Persona: `studio-integration-coordinator`
   - Directive: `integrate-lanes-with-stop-points`

Required grounding format:

1. `Ground with PersonaKit session: <session-id>; root: <absolute-worktree-path>; no scope expansion; stop at review point.`

## Mandatory Working Model

All implementation in this plan MUST be performed in a dedicated git worktree, not in the primary checkout.

Required worktree rules:

1. Create or use a dedicated worktree under `~/.codex/worktrees/...` for this effort.
2. Run all edits, tests, and validation from that worktree path.
3. Keep one branch per lane (or one lane per worktree) to prevent cross-lane mutation conflicts.
4. Do not mix unrelated lane changes in a single branch.

## Worktree Setup

Use this naming convention:

1. Branch: `codex/<lane>-<yyyy-mm-dd>`
2. Worktree path: `~/.codex/worktrees/<ticket-or-shortname>/<lane>`

Example setup commands:

```bash
git worktree add ~/.codex/worktrees/studio-accel/reliability -b codex/reliability-2026-03-06
git worktree add ~/.codex/worktrees/studio-accel/boundary -b codex/boundary-2026-03-06
git worktree add ~/.codex/worktrees/studio-accel/coverage -b codex/coverage-2026-03-06
git worktree add ~/.codex/worktrees/studio-accel/workflow -b codex/workflow-2026-03-06
```

Execution rule:

1. Each lane runs only inside its assigned worktree path.
2. Coordinator integration happens in a dedicated integration worktree or after lane PR approval.

## Conflict Policy

1. No rebases during active lane implementation.
2. Coordinator-only integration order is required.
3. Integration order is fixed: `Phase 0` first, then `Lane D`, then `Lane B`, then `Lane C`.
4. If a lane needs files owned by another active lane, it must stop and request reassignment.
5. If merge conflicts arise, coordinator resolves them after freezing conflicting lanes.

## Success Criteria

1. `swift test` passes twice back-to-back in the worktree.
2. No new violations of architectural invariants:
   - No IO from SwiftUI Views.
   - No global mutable singleton/state creep.
   - No off-main mutation of UI-observable state.
3. Final validation passes with parallel-safe temp path usage:
   - `TMPDIR=/tmp/personakit-$USER-$AGENT Scripts/validate-repo.sh`

## Phase Plan

### Phase 0: Reliability Gate (blocking)

Owner: Agent A (Reliability)

Scope:

1. Stabilize cancellation/restart behavior around session preview loading.
2. Remove timing fragility from affected async tests.
3. Preserve user-visible behavior while making state transitions deterministic.

Allowed files:

1. `Sources/Features/Studio/Presentation/FeatureModels/WorkspaceSessionFeatureModel+PreviewLifecycle.swift`
2. `Tests/Features/Studio/WorkspaceSessionFeatureModelMapTests.swift`
3. Studio test support files only if needed for deterministic synchronization.

Forbidden files:

1. SwiftUI view files.
2. CLI/MCP implementation files.

Exit criteria:

1. Formerly flaky preview cancellation test passes 20 consecutive runs.
2. `swift test` passes twice back-to-back in the same worktree.
3. No new timing-based flakes are introduced in adjacent Studio async tests.

Stop point:

1. Human review required before starting Phase 1.

### Phase 1: Parallel Lanes (start only after Phase 0 passes)

#### Lane B: Boundary Hardening

Owner: Agent B

Scope:

1. Remove direct UI access to feature-model internals.
2. Route session interactions through `WorkspaceStore` APIs only.
3. Keep behavior unchanged.

Allowed files:

1. `Sources/Features/Studio/UI/SessionsPanelView.swift`
2. `Sources/Features/Studio/Presentation/Store/WorkspaceStore+SessionActions.swift`
3. Related Studio session/store tests.

Forbidden files:

1. Shared core modules.
2. CLI/MCP features.

Exit criteria:

1. No direct UI calls into `workspaceStore.sessionFeatureModel` internals.
2. Session/store tests pass.

#### Lane C: Coverage Expansion for Core Risk Areas

Owner: Agent C

Scope:

1. Add dedicated tests for workspace relationship map correctness.
2. Add path/scope edge-case tests for lookup/resolver behavior.

Allowed files:

1. Tests for relationship map and resolver/scope behavior.
2. Source fixes only if tests expose real defects.

Forbidden files:

1. Studio UI presentation files.

Exit criteria:

1. Deterministic tests added for merge/order/missing-node/edge dedupe behavior.
2. New scope/path edge-case tests pass.

#### Lane D: Multi-Agent Workflow Polish

Owner: Agent D

Scope:

1. Make validation workflow parallel-safe for multi-agent use.
2. Reduce accidental local churn from mutating check workflows.
3. Align contributor command guidance.

Allowed files:

1. `Scripts/validate-repo.sh`
2. `Makefile`
3. `Docs/Development/README.md`

Forbidden files:

1. Studio feature implementation files.

Exit criteria:

1. Validation script supports concurrent runs safely.
2. Docs clearly describe worktree-first and parallel-safe validation workflow.

Stop point:

1. Human review required after each lane is complete, before final integration.

## No-Overlap Matrix

Lane ownership is strict. Lanes may not edit outside their assigned paths without coordinator approval.

| Lane | Primary Scope | Allowed Paths |
| --- | --- | --- |
| Phase 0 / Agent A | Preview cancellation reliability | `Sources/Features/Studio/Presentation/FeatureModels/WorkspaceSessionFeatureModel+PreviewLifecycle.swift`, `Tests/Features/Studio/WorkspaceSessionFeatureModelMapTests.swift`, Studio test support files only |
| Lane B / Agent B | UI-to-store boundary hardening | `Sources/Features/Studio/UI/SessionsPanelView.swift`, `Sources/Features/Studio/Presentation/Store/WorkspaceStore+SessionActions.swift`, related Studio session/store tests |
| Lane C / Agent C | Graph and scope test coverage | Relationship-map and resolver/scope tests, plus minimal source fixes only if tests prove a defect |
| Lane D / Agent D | Validation workflow and docs | `Scripts/validate-repo.sh`, `Makefile`, `Docs/Development/README.md` |

## Rollback and Abort Criteria

A lane must stop immediately and hand back to coordinator when any of the following occur:

1. Invariant breach risk appears (IO drifting into Views, off-main UI-state mutation, new global mutable state).
2. Non-deterministic output appears in export/graph/validation checks.
3. Lane requires edits in another lane's owned files.
4. Merge conflict blocks clean lane integration.
5. A change weakens an existing mutation boundary or introduces a second mutation path.

Coordinator actions on abort:

1. Freeze affected lane branch.
2. Capture failing evidence and reproduction commands.
3. Decide between revert-and-retry or lane scope split.

## Agent Operating Protocol

Coordinator responsibilities:

1. Assign non-overlapping write scopes.
2. Enforce invariant checks before merge.
3. Merge only after lane-level tests pass.
4. Keep a strict stop-review cadence.

Required handoff format from every agent:

1. Task slice completed.
2. Files changed.
3. Checks run.
4. Residual risks.
5. Stop point reached.

Required grounding line for each agent prompt:

`Ground with PersonaKit session: <session-id>; root: <absolute-worktree-path>; no scope expansion; stop at review point.`

## Test and Validation Plan

Per lane:

1. Run targeted tests first.
2. Run relevant module/feature tests before handoff.

Global gates:

1. `swift test` (twice) in the worktree.
2. `TMPDIR=/tmp/personakit-$USER-$AGENT Scripts/validate-repo.sh`

## Decision Capture Rule

If this effort introduces durable standards (for example, unified async freshness/cancellation policy or stricter store boundary APIs), capture them in an ADR or architecture note before closing the effort.

## Assumptions

1. This is architecture-preserving work, not product redesign.
2. Swift 6 strict concurrency remains fully enabled.
3. Work continues with human-in-the-loop reviews at phase stop points.
