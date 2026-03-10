# Orbit Build Rerun Playbook

Use this essential when Samwise is starting or resuming a fresh Orbit build
attempt from `main`.

## Purpose

1. Make the Orbit rerun executable from stable source-of-truth artifacts.
2. Keep the first checkpoint bounded to the approved MVP slice.
3. Prevent a strong solo build from being mislabeled as a successful
   multiagent rerun.
4. Keep product gates, evidence gates, and retrospective gates explicit from
   the start.

## Source Of Truth

When running the Orbit rerun, treat these as the active source of truth:

1. `Docs/Orbit/Execution/Orbit-Build-Rerun-Checklist.md`
2. `Docs/Orbit/Execution/Orbit-Product-Acceptance-Checklist.md`
3. `Docs/Orbit/Planning/Orbit-Execution-Plan.md`
4. `Docs/Orbit/Planning/Orbit-First-Checkpoint-Implementation-Breakdown.md`
5. `Docs/Orbit/Execution/Orbit-Retrospective-Policy.md`

Do not reconstruct the rerun from thread memory alone.

## Required Startup Discipline

Before the first code change in a fresh worktree:

1. Confirm `main` already contains the lane-tooling and retrospective-contract
   changes required by the rerun checklist.
2. Choose the next integer branch name for the attempt:
   - `codex/orbit-1`
   - `codex/orbit-2`
   - `codex/orbit-3`
3. Record the selected attempt token in the active rerun-prep note.
4. If AJ is holding approval, stop after staging the token and do not create or
   bootstrap the lane yet.
5. Create and bootstrap the approved Orbit lane.
6. Run baseline validation before coding.
7. Record the required active participants and expected evidence artifacts.
8. Freeze the first slice:
   - Orbit runtime models
   - deterministic persistence
   - Studio Orbit surface shell

Use the integer as the attempt number.
Do not reuse an older Orbit attempt branch name for a fresh rerun.
A selected token is not an approved lane by itself.

## Required Review Gates

Do not describe the branch as `review-ready` or `MVP candidate` until all are
true:

1. Each active owner has red-penned their deliverable at least three times and
   recorded the resulting changes or "no further material issues found" note.
2. The product acceptance checklist is run.
3. The interaction-quality review pass is recorded.
4. Feature, product, process, and persona-fidelity confidence are scoped
   separately.
5. Hybrid retrospective closeout is complete:
   - `fan-out` first
   - short `roundtable` second
   - one canonical `Starfish` synthesis

## Red-Pen Expectations By Role

Before an owner calls a deliverable done, at minimum:

1. implementation owners should red-pen for structure, correctness, and code
   clarity
2. product and interaction reviewers should red-pen for judgment quality,
   specificity, and actionability
3. validation owners should red-pen for evidence quality, finding discipline,
   and confidence scoping
4. Samwise should red-pen synthesis artifacts for truthfulness, boundary
   discipline, and continuity value

Required evidence may be brief, but it must exist.

## Required Participants

Minimum valid rerun participants:

1. `Samwise`
   coordinator and facilitator only
2. `Senior SwiftUI Engineer`
   required implementation agent
3. `Venture Product Steward`
   required product reviewer
4. `Studio Interaction Quality Lead`
   required interaction-quality reviewer
5. `Studio Coverage Architect`
   required validation and evidence reviewer

Minimum valid rerun structure:

1. at least one persona-backed implementation sub-agent
2. at least two distinct non-implementation review passes
3. explicit participant evidence for each active role

Planned roles do not count as active participants.

## Guardrails

- Do not broaden past the first checkpoint slice before it is proven again.
- Do not let test success stand in for product acceptance.
- Do not let participant labels stand in for actual multiagent evidence.
- Do not promote back toward `main` until the rerun checklist says the lane is
  ready.
