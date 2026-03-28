# M7 Workstream Posts And Execution Lanes

Status: Closed for M7 Closeout
Primary Owner: `worktree-squad-lead`
Supporting Personas: `samwise`, `venture-product-steward`, `studio-integration-coordinator`, `studio-coverage-architect`
Last Updated: 2026-03-27

## Purpose

Bridge discussion to execution without collapsing execution into chat.

## Quality Standard

`M7` is not successful because a discussion can technically launch a workstream.

`M7` is successful only when workstream execution remains:

- explicit about who owns the lane and why that owner is authorized
- reviewable enough that launch, progress, and closeout do not read as hidden
  background magic
- bounded enough that later runtime, UI, and schema work can build on one
  frozen contract instead of re-arguing lane authority

The bare minimum is not a milestone win.

`M7` is closed for first-slice workstream planning and proof.
The current dossier evidence is sufficient to hand forward to later
implementation work without reopening the accepted `M7` packet set.

## Current Milestone Position

- `M7-P1` is accepted: the owner decision and handoff contract are now frozen
  as the planning baseline for the milestone
- `M7-P2` is accepted: the runtime record and lifecycle contract are now frozen
  as the implementation boundary for later packets
- `M7-P3` is accepted: the handoff contract from discussion into execution is
  now frozen as the launch boundary for later packets
- `M7-P4` is accepted: the progress, artifact, and closeout return contract is
  now frozen as the return boundary for later packets
- `M7-P5` is accepted: the proof and review-gate contract is now frozen as the
  closeout baseline for the milestone
- `M7` proof artifacts were prepared under the accepted packet set without
  widening scope
- `M7` milestone closeout is accepted on the prepared dossier

## File Map

- `README.md`
  milestone overview, packet order, and top-level guardrails
- `Packet-01-Freeze-Workstream-Ownership-And-Contract.md`
  first-pass owner and handoff contract for `M7-P1`
- `Packet-02-Freeze-Workstream-Runtime-Model.md`
  first-pass runtime record and lifecycle contract for `M7-P2`
- `Packet-03-Freeze-Handoff-From-Discussion-To-Execution.md`
  first-pass launch and failure-visibility contract for `M7-P3`
- `Packet-04-Freeze-Progress-And-Artifact-Return.md`
  first-pass return contract for progress, artifacts, and closeout in `M7-P4`
- `Packet-05-Prove-Lane-Discipline-And-Review-Gates.md`
  first-pass proof contract and validation floor for `M7-P5`
- `Example-Launch-Packet.md`
  concrete approved-launch and blocked-non-launch examples for `M7` closeout review
- `Workstream-Lifecycle-Example.md`
  concrete lifecycle examples for launched workstreams across active, blocked, and terminal states
- `Progress-And-Artifact-Return-Example.md`
  concrete bounded-return and artifact-source-of-truth example for `M7`
- `Validation-Review-Artifact.md`
  validation note for the prepared `M7` proof package
- `Milestone-Closeout-Review-Artifact.md`
  AJ-facing milestone closeout note for the full `M7` dossier
- `AJ-Closeout-Review-Artifact.md`
  AJ-facing planning closeout note for the `M7-P1` owner and handoff contract

## Preconditions

- `M5` meeting continuity is stable enough to hand work forward
- `M6` structured objects can capture context and evidence
- `M0` owner coverage still supports `worktree-squad-lead` for the first cut
  of `M7`

## Scope Freeze

In scope:

- workstream posts
- workstream state and assignment records
- linked handoff from message posts and meeting posts
- progress, artifact, and closeout return into Orbit
- visible execution status separate from source discussion

Out of scope:

- hidden autonomous loops
- unconstrained repo execution without review gates
- broad workflow marketplace features

## Required Inputs

- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- `M5` meeting continuity evidence
- `M6` structured output evidence

## Execution Packets

### Packet 1. Freeze Workstream Ownership And Contract

Outcome:

- one explicit identity and launch contract own first-cut execution-lane
  behavior

Work:

- confirm whether `worktree-squad-lead` is sufficient for bounded reviewed
  execution lanes
- record the explicit reopen criteria for `orbit-workstream-runner`
- define workstream handoff packet shape, approval rules, review gates, and
  stop points

Done when:

- no workstream lane starts with fuzzy authority, implicit autonomy, or an
  underspecified handoff packet

### Packet 2. Freeze Workstream Runtime Model

Outcome:

- workstream posts have one accepted first-pass runtime model with explicit
  state, roster, and linkage rules

Work:

- freeze the required runtime record set for a workstream post
- freeze the lifecycle and assignment contract later packets must preserve
- freeze explicit deferred items so launch plumbing and UI do not leak into the
  runtime-model slice

Done when:

- later implementation work can create workstream posts as first-class runtime
  objects without relitigating the record boundary

### Packet 3. Freeze Handoff From Discussion To Execution

Outcome:

- a source post can hand off into a bounded workstream intentionally and
  inspectably

Work:

- freeze handoff eligibility from message and meeting posts
- freeze the minimum launch payload carried into a workstream
- freeze blocked, failed, and partial-creation visibility rules

Done when:

- later implementation work can create linked workstream posts without hidden
  launch authority or ambiguous failure handling

### Packet 4. Freeze Progress And Artifact Return

Outcome:

- workstream progress, artifacts, and closeout have one accepted return contract
  back into Orbit

Work:

- freeze what progress updates return to source context and what stays on the
  workstream as detailed history
- freeze how produced artifacts remain inspectable without creating attachment
  ambiguity
- freeze the closeout return contract and blocker/failure visibility rules

Done when:

- later implementation work can return durable progress, artifacts, and closeout
  without flooding the origin context or splitting source of truth

### Packet 5. Prove Lane Discipline And Review Gates

Outcome:

- execution is bounded, inspectable, and reviewable

Work:

- verify gate behavior
- verify closeout requirements
- verify evidence capture for implementation and review roles

Done when:

- workstream execution no longer reads as hidden background magic

## Subagent Use Pattern

Safe subagents:

- workstream lifecycle review
- handoff-packet review
- artifact-return review
- validation and closeout review

Avoid:

- allowing spawned workstream lanes to broaden scope beyond the source packet

## Evidence Package

- `Packet-01-Freeze-Workstream-Ownership-And-Contract.md`
- `Packet-02-Freeze-Workstream-Runtime-Model.md`
- `Packet-03-Freeze-Handoff-From-Discussion-To-Execution.md`
- `Packet-04-Freeze-Progress-And-Artifact-Return.md`
- `Packet-05-Prove-Lane-Discipline-And-Review-Gates.md`
- `Example-Launch-Packet.md`
- `Workstream-Lifecycle-Example.md`
- `Progress-And-Artifact-Return-Example.md`
- `Validation-Review-Artifact.md`
- `Milestone-Closeout-Review-Artifact.md`
- `AJ-Closeout-Review-Artifact.md`

## Stop Points

- stop if the workstream owner persona is unresolved
- stop if `worktree-squad-lead` would need authority beyond bounded reviewed
  delivery lanes to make `M7` coherent
- stop if workstreams begin performing hidden consequential actions
- stop if closeout is implied instead of explicitly recorded

## Exit And Handoff

Exit when a post can launch a bounded workstream and receive visible progress,
artifacts, and closeout back into Orbit.

Handoff forward to:

- `M8` for journaling from real workstream activity
