# Rerun Execution Contract

Status: Draft
Milestone: `M2`
Owner: `samwise`
Execution Owner: `senior-swiftui-engineer`
Last Updated: 2026-03-18

## Purpose

Define how a serious `M2` attempt should run.

This is not just a feature checklist.
It is a comparison-grade rerun contract for proving the first Orbit room with
enough quality and evidence to be worth trusting.

## Starting Rule

An `M2` attempt should start from the Orbit rerun stack, not from memory.

Required startup order:

1. `Docs/Orbit/Execution/Orbit-Build-Rerun-Checklist.md`
2. `Docs/Orbit/Execution/Orbit-Product-Acceptance-Checklist.md`
3. latest rerun-prep and retrospective artifacts
4. `Docs/Orbit/Planning/Orbit-Agentic-Milestone-Roadmap.md`
5. `Docs/Orbit/Planning/Orbit-Execution-Plan.md`
6. `Docs/Orbit/Planning/Orbit-First-Checkpoint-Runtime-Model.md`
7. `Docs/Orbit/Planning/Orbit-First-Checkpoint-Implementation-Breakdown.md`
8. this dossier set

## Required Active Participants

An `M2` attempt is not valid unless these roles actually participate:

1. `samwise`
   orchestration, scope discipline, and closeout synthesis only
2. `senior-swiftui-engineer`
   implementation owner
3. `venture-product-steward`
   product acceptance owner
4. `studio-interaction-quality-lead`
   interaction-quality review owner
5. `studio-coverage-architect`
   validation and evidence owner

Planned roles do not count as active participation.
The attempt should produce evidence for each active role used to justify the run.

## Packet Sequence

### Packet 1. Runtime And Persistence Re-Verification

Owner:

- `senior-swiftui-engineer`

Review ring:

- `studio-coverage-architect`

Outcome:

- the first-checkpoint data and persistence boundary are still minimal and
  trustworthy

Required proof:

- runtime entity alignment against the runtime-model note
- deterministic local persistence behavior
- sample/default workspace data still fits the checkpoint

### Packet 2. Command-Center Shell Re-Proof

Owner:

- `senior-swiftui-engineer`

Review ring:

- `venture-product-steward`
- `studio-interaction-quality-lead`

Outcome:

- Orbit is visible as a room with workspace context, roster, and active thread

Required proof:

- first-open screenshots or snapshots
- product review against the experience bar
- evidence that empty and seeded first-open states still preserve the same room
  model

### Packet 3. Durable Conversation Re-Proof

Owner:

- `senior-swiftui-engineer`

Review ring:

- `studio-coverage-architect`

Outcome:

- a thread can begin, persist, and survive restart with visible attribution

Required proof:

- restart verification
- deterministic persistence checks
- tests or validation notes for creation, loading, and speaker attribution

### Packet 4. Participant Addressing And Lightweight Exchange Re-Proof

Owner:

- `senior-swiftui-engineer`

Review ring:

- `venture-product-steward`
- `studio-interaction-quality-lead`
- `studio-coverage-architect`

Outcome:

- direct address and minimal multi-participant behavior feel intentional and
  reviewable

Required proof:

- one direct-address example
- one lightweight multi-participant example
- explanation of why the response bridge is still narrow and inspectable

### Packet 5. Activation Trace Visibility Re-Proof

Owner:

- `senior-swiftui-engineer`

Review ring:

- `venture-product-steward`
- `studio-interaction-quality-lead`
- `studio-coverage-architect`

Outcome:

- trace visibility meaningfully supports Orbit's explainable-collaboration claim

Required proof:

- operator-visible trace example
- mapping between visible trace and durable activation records
- review feedback on weight, clarity, and usefulness
- proof that trace inspection is available from the product surface rather than
  debug-only tooling

### Packet 6. Checkpoint Closeout

Owner:

- `samwise`

Review ring:

- all active reviewers

Outcome:

- the checkpoint closes with evidence, not optimism

Required proof:

- product acceptance artifact
- interaction-quality review artifact
- validation closeout artifact
- participant-evidence artifact
- red-pen evidence artifact
- retrospective closeout artifacts

## Stop Conditions

Stop the attempt if any of these become true:

- the room still reads more like chat than Orbit after packet 2
- persistence is unreliable after packet 3
- multi-participant behavior is not explainable after packet 4
- trace visibility is technically present but product-useless after packet 5
- implementation begins drifting into `M3` or later milestone concerns

## Attempt Output Rule

Each `M2` attempt should create new attempt-specific evidence artifacts under
`Docs/Orbit/Execution/` rather than rewriting older attempt evidence.

The required output shape should include at least:

- product acceptance
- interaction-quality review
- validation closeout
- participant evidence
- red-pen evidence
- retrospective closeout and supporting synthesis artifacts

Expected attempt-specific artifact pattern for the active rerun should align with
the Orbit rerun checklist, including files such as:

- `<attempt>-product-acceptance.md`
- `<attempt>-interaction-quality-review.md`
- `<attempt>-validation-closeout.md`
- `<attempt>-participant-evidence.md`
- `<attempt>-red-pen-evidence.md`
- `<attempt>-retrospective.md`

## Red-Pen Minimum

Each active owner should complete at least three red-pen passes on their
deliverable before the checkpoint is described as `review-ready` or `MVP
candidate`:

1. structural and scope red-pen
2. correctness and edge-case red-pen
3. clarity, product-fit, or maintainability red-pen

If external review causes material changes, one fresh red-pen pass should run
before re-submitting the deliverable.

## Retrospective Method Rule

Checkpoint closeout should follow the current Orbit retrospective policy:

1. `fan-out` first
2. short `roundtable` second
3. one canonical `Starfish` synthesis at the end

## Quality Rule

This contract is successful only if it makes the next `M2` attempt harder to
rush through.

If a lane can still claim success with thin evidence or generic-chat product
quality, the contract is not strong enough.
