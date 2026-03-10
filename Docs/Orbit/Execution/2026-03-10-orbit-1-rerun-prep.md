# Orbit Attempt 1 Rerun Prep

Status: Staged, pending AJ approval
Owner: Samwise
Date: 2026-03-10
Intended Branch: `codex/orbit-1`
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

This token is reserved as the next attempt identifier only.

Do not treat this note as branch approval, lane creation, or permission to
start the rerun.

## Remaining Startup Work Before Kickoff

The rerun is not ready to start until all of these are true:

1. AJ explicitly approves starting the next Orbit attempt.
2. The exact lane is approved in the lane manifest or AJ explicitly chooses the
   per-commit approval path for the run.
3. The approved worktree is created and bootstrapped.
4. Baseline validation is green in that worktree.
5. The active participants and expected evidence artifacts are recorded for the
   attempt.

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
