# Orbit Attempt 1 Rerun Prep

Status: Staged, lane approved, repo-root startup allowed, execution kickoff held pending AJ start approval
Owner: Samwise
Date: 2026-03-10
Intended Branch: `codex/orbit-1`
Pinned Start Point: `126dfde55b4f80ccb4872d58181203ff9f8c0f68`
Prior Attempt Branch: `codex/orbit-foundation`
Prior Retrospective: `2026-03-09-orbit-foundation-retrospective.md`

## Purpose

Stage the next fresh-`main` Orbit rerun without implying that kickoff has been
approved.

This note exists so the next run can start from a concrete token, carry-forward
contract, and evidence plan instead of reconstructing intent from thread
history.

## Current Status

The next fresh-main Orbit attempt is staged as:

- `codex/orbit-1`

This lane is already recorded as the manifest-approved next Orbit rerun lane.

Startup may verify the source-of-truth artifacts and the lane contract from the
repository root.

Do not treat this note as permission to start live execution.
Execution kickoff is still held until AJ explicitly approves starting the
attempt and the lane is materialized, bootstrapped, and preflighted in the
actual `codex/orbit-1` worktree.

## Remaining Startup Work Before Kickoff

The rerun is not ready to start until all of these are true:

1. AJ explicitly approves starting the next Orbit attempt.
2. The source-of-truth startup artifacts and lane contract are confirmed from
   the repo root.
3. The approved worktree is materialized and bootstrapped at execution kickoff.
4. Baseline validation is green in that worktree.
5. The active participants and expected evidence artifacts are recorded for the
   attempt.

## Execution Kickoff Materialization

When AJ approves live execution, materialize the lane with one explicit local
path, for example:

`Scripts/materialize-worktree-lane.sh --branch codex/orbit-1 --path /absolute/path/to/PersonaKit-orbit-1`

## First Slice Contract

The first slice remains frozen to:

1. Orbit runtime models
2. deterministic persistence
3. Studio Orbit surface shell

Do not broaden into later Orbit phases before this checkpoint is proven again.

## Carry-Forward Summary

### Keep

1. Treat the run as a comparison-grade rerun, not just "continue building
   Orbit."
2. Use the hybrid retrospective closeout:
   - `fan-out` first
   - short `roundtable` second
   - one canonical `Starfish` synthesis
3. Keep the product bar tied to the Orbit-specific command-center feel, not
   just passing builds and tests.

### Correct

1. Do not let a strong solo pass get mislabeled as a successful multiagent run.
2. Make active participants, owned scopes, and expected evidence explicit
   before implementation begins.
3. Keep feature outcome, product outcome, process outcome, and persona-fidelity
   outcome separated in closeout artifacts.

### Re-Test

1. Whether the runtime model is still appropriately minimal for the first
   checkpoint
2. Whether the deterministic participant response bridge is still the right
   checkpoint placeholder
3. Whether `.personakit/Orbit/orbit-workspace.json` remains the right
   persistence boundary for this checkpoint
4. Whether the Orbit surface now feels structurally different from generic chat

## Proposed Active Participants For Attempt 1

Record these as active only if the run actually uses them and produces role
evidence:

1. `Samwise`
   coordinator and facilitator only
2. `Senior SwiftUI Engineer`
   implementation owner
3. `Venture Product Steward`
   product review owner
4. `Studio Interaction Quality Lead`
   interaction-quality owner
5. `Studio Coverage Architect`
   validation and evidence owner

Planned roles do not count as active participation.

## Expected Evidence For Attempt 1

Before implementation begins, the run should name the artifacts expected for:

1. implementation evidence
2. product acceptance checklist result
3. interaction-quality review artifact
4. validation and evidence closeout artifact
5. participant evidence for every active role
6. owner-side red-pen evidence for every active deliverable
7. hybrid retrospective closeout artifacts
8. one canonical closeout summary separating:
   - feature outcome
   - product outcome
   - process outcome
   - persona-fidelity outcome

## Attempt 1 Output Files

Create new `orbit-1` artifacts for this attempt.
Do not edit `orbit-foundation` evidence except for explicit historical
correction.

Use this output set:

1. `Docs/Orbit/Execution/2026-03-10-orbit-1-product-acceptance.md`
2. `Docs/Orbit/Execution/2026-03-10-orbit-1-interaction-quality-review.md`
3. `Docs/Orbit/Execution/2026-03-10-orbit-1-validation-closeout.md`
4. `Docs/Orbit/Execution/2026-03-10-orbit-1-participant-evidence.md`
5. `Docs/Orbit/Execution/2026-03-10-orbit-1-red-pen-evidence.md`
6. `Docs/Orbit/Execution/2026-03-10-orbit-1-retrospective.md`
7. `Docs/Orbit/Execution/retrospectives/2026-03-10-orbit-1-evidence-packet.md`
8. `Docs/Orbit/Execution/retrospectives/2026-03-10-orbit-1-fan-out.md`
9. `Docs/Orbit/Execution/retrospectives/2026-03-10-orbit-1-roundtable.md`
10. `Docs/Orbit/Execution/retrospectives/2026-03-10-orbit-1-comparison-scorecard.md`
11. `Docs/Orbit/Execution/retrospectives/2026-03-10-orbit-1-comparison-decision.md`

## Startup Source List

When approval is given, start by loading:

1. `Docs/Orbit/Execution/Orbit-Build-Rerun-Checklist.md`
2. `Docs/Orbit/Execution/Orbit-Product-Acceptance-Checklist.md`
3. `Docs/Orbit/Planning/Orbit-Execution-Plan.md`
4. `Docs/Orbit/Planning/Orbit-First-Checkpoint-Implementation-Breakdown.md`
5. `Docs/Orbit/Execution/2026-03-09-orbit-foundation-retrospective.md`
6. `Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-evidence-packet.md`
7. `Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-comparison-decision.md`
8. this prep note

## Hold Point

Stop here until AJ approves the attempt start.
