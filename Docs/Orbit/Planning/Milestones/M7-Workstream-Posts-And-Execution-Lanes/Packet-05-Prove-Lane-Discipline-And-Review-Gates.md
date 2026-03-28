# M7 Packet 5: Prove Lane Discipline And Review Gates

Status: Accepted
Packet Id: `M7-P5`
Milestone: `M7`
Execution Owner: `worktree-squad-lead`
Review Personas: `samwise`, `venture-product-steward`, `studio-integration-coordinator`, `studio-coverage-architect`
Last Updated: 2026-03-27

## Header

- status: `done`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Freeze the first-pass proof contract showing that `M7` execution remains
  bounded, inspectable, and reviewable under the already accepted `M7-P1`
  through `M7-P4` rules.
- This packet exists now because owner authority, runtime shape, handoff, and
  return posture are already frozen, but the milestone still needs one explicit
  proof plan for demonstrating that those rules hold together without hidden
  autonomy.
- This is the right slice size because it freezes proof scenarios, evidence
  expectations, and review gates without broadening into runtime implementation,
  UI design, or schema work.

## Quality Bar

- the operator can tell why a workstream did or did not begin execution
- review gates stay visible at launch, during progress, and at closeout
- the source context and workstream thread together tell a coherent story
  without hidden state reconstruction
- proof artifacts show the accepted contract working under realistic examples
  rather than optimistic prose alone

## Preconditions

- `M7-P1` is accepted and remains the governing owner and approval contract
- `M7-P2` is accepted and remains the governing runtime-model contract
- `M7-P3` is accepted and remains the governing handoff contract
- `M7-P4` is accepted and remains the governing progress, artifact, and
  closeout-return contract
- `M5` and `M6` remain the governing continuity and structured-object baselines
  for visible source-context behavior

## Grounding Requirements

- local `personakit` CLI grounding for `samwise` with directive `apply-style`
- `README.md`
- `Packet-01-Freeze-Workstream-Ownership-And-Contract.md`
- `Packet-02-Freeze-Workstream-Runtime-Model.md`
- `Packet-03-Freeze-Handoff-From-Discussion-To-Execution.md`
- `Packet-04-Freeze-Progress-And-Artifact-Return.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- `Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/README.md`
- `Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/Product-And-Interaction-Review-Artifact.md`
- `Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/README.md`
- `Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/Product-And-Interaction-Review-Artifact.md`
- `Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md`
- live grounding required: `yes`
- PersonaKit MCP grounding allowed: `no`

## Exact Scope

Include:

- the proof scenarios required to demonstrate `M7` lane discipline under the
  accepted contracts
- the review-gate evidence that must be visible at launch, during progress, and
  at closeout
- the validation artifact set later implementation or review passes must
  produce for `M7`
- the explicit pass/fail posture for proving bounded execution rather than
  hidden background magic

Exclude:

- new runtime behavior, hidden execution helpers, or lane-owner broadening
- final UI layout, component hierarchy, or interaction design
- final schema, event payload, or API decisions
- `M8` journaling or memory behavior
- any attempt to reopen accepted `M7-P1` through `M7-P4` contracts without an
  explicit blocker

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/`
- may create: packet-local proof examples and validation artifacts inside the
  `M7` dossier
- must not edit: runtime source paths, `M5` or `M6` dossier files, or later
  milestone dossiers in this packet

## Ordered Work

1. Freeze the minimum proof scenarios needed to demonstrate lane discipline.
2. Freeze the evidence package and review artifacts required to inspect those
   scenarios.
3. Freeze pass/fail criteria so `M7` cannot claim success through prose alone.

## Validation And Evidence

- updated `M7` milestone README aligned with `M7-P5` acceptance and milestone
  closeout-review readiness
- packet note naming proof scenarios, required evidence, and pass/fail posture
- explicit language preventing proof-by-assertion, hidden autonomy, or silent
  contract weakening

## Packet 5 Closure Position

- `M7-P5` does not add new execution behavior; it proves the accepted behavior
  can be reviewed honestly
- the milestone is not ready to close out until proof artifacts show launch,
  progress, blocker, artifact, and closeout visibility working together
- later implementation or review work may choose concrete formats for those
  artifacts, but it must preserve the proof floor frozen here or reopen
  `M7-P5`

## Packet 5 Working Contract

### Required Proof Scenarios

The first proof slice should include, at minimum:

- one approved launch example showing:
  - explicit source post eligibility
  - explicit owner and review visibility
  - launch into `draft` or `pending` rather than hidden execution
- one blocked pre-launch example showing:
  - missing approval, owner, or required context
  - visible non-launch posture from preserved source context
- one active progress example showing:
  - transition into `in_progress`
  - bounded returned checkpoint visibility to source context
- one artifact-return example showing:
  - artifact availability visible from source context
  - workstream post retained as durable source of truth
- one terminal closeout example showing:
  - explicit `completed`, `failed`, or `cancelled` outcome
  - closeout summary and residual follow-up truth

### Review-Gate Proof Requirements

- proof must show that execution does not start without satisfying the accepted
  `M7-P1` approval contract
- proof must show that the accepted `M7-P2` owner, state, and linkage posture
  stays visible throughout the lifecycle
- proof must show that the accepted `M7-P3` source continuity rules still hold
  when handoff blocks, fails, or partially succeeds
- proof must show that the accepted `M7-P4` return posture does not flood the
  source context or silently duplicate artifacts
- proof must make it possible for a reviewer to tell:
  - who owns the lane
  - what state the workstream is in
  - whether execution actually began
  - what came back to the source context
  - whether closeout was explicit

### Evidence Package Contract

The first proof pass should prepare, at minimum:

- one example launch packet
- one workstream lifecycle example
- one progress and artifact return example
- one closeout and validation artifact set
- one reviewer-facing note describing whether the examples prove bounded
  execution or expose a contract gap

### Validation Posture

- examples may be narrative, structured, or mixed, but they must stay grounded
  in the accepted `M7-P1` through `M7-P4` contracts
- proof artifacts should be legible enough that a reviewer can inspect them
  without reconstructing hidden runtime state
- validation should reject any example that depends on:
  - implicit owner authority
  - silent start of execution
  - silent dual-write artifact behavior
  - inferred closeout from silence alone

### Pass Criteria

- `M7` may claim bounded first-slice coherence only if the proof set shows:
  - explicit launch authority
  - preserved source continuity
  - bounded progress return
  - clear artifact source of truth
  - explicit terminal closeout or blocker truth
- if any of those conditions can be satisfied only by inventing new runtime,
  UI, or schema behavior, the proof fails and the milestone must stop rather
  than improvise

### Boundary To Milestone Closeout

- `M7-P5` is the final bounded packet for the milestone
- successful `M7-P5` should make it possible to prepare milestone closeout
  review without reopening owner, runtime, handoff, or return semantics
- `M8` remains out of scope unless a later milestone explicitly adopts the
  proved `M7` outputs into journaling or memory policy

### Explicitly Deferred

- exact UI screenshots, controls, or interaction choreography
- exact schema, event payload, or storage representation
- automated test harness details beyond the proof scenarios frozen here
- any extension of owner identity beyond `worktree-squad-lead`
- any broadening into connector automation, background processing, or memory
  ingestion

## Open Risks And Review Decisions Needed

- the proof examples must be concrete enough to expose hidden-autonomy drift
  without accidentally becoming a quiet runtime design exercise
- the validation artifact set must be strong enough to show real lane
  discipline, not just happy-path storytelling
- artifact-return proof must preserve the accepted anti-duplication posture from
  `M7-P4`
- milestone closeout should stop if reviewers still need to infer execution
  state or closeout truth from scattered clues

## Failure Dispositions

- `blocked`
  proof scenarios or evidence expectations are still too weak to show real
  lane discipline
- `needs-review`
  the proof contract is coherent but not yet accepted for milestone closeout
- `grounding-blocked`
  required local PersonaKit grounding or repo-local authority evidence is not
  available
- `failed`
  `M7` still reads as hidden background execution unless new runtime, UI, or
  schema invention is added

## Stop Points

- stop if proof requires hidden autonomy to make the lifecycle look coherent
- stop if reviewers cannot tell whether execution began, blocked, or closed out
  without reconstructing hidden state
- stop if proof depends on silent dual-write artifacts or implied closeout
- stop if milestone closeout would require reopening accepted `M7-P1` through
  `M7-P4` contracts instead of proving them

## Closeout Return Format

- proof scenarios frozen or explicitly blocked
- evidence package and review-gate posture named
- pass/fail criteria named
- open risks
- next recommended step: milestone closeout review if proof succeeds

## AJ Review Outcome

- AJ approved `M7-P5` as the proof baseline for milestone closeout.
- `M7` closeout now depends on reviewer-visible evidence that launch,
  lifecycle, artifact return, and closeout obey the accepted `M7-P1` through
  `M7-P4` contracts.
- The milestone may not claim coherence through prose alone, happy-path-only
  examples, or hidden-autonomy assumptions.
- Any proof gap that requires new runtime behavior, UI invention, schema
  broadening, or widened owner authority should block milestone closeout rather
  than being improvised inside the proof pass.
