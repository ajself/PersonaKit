# M7 Workstream Posts And Execution Lanes

Status: Planned
Primary Owner: `worktree-squad-lead` unless AJ approves `orbit-workstream-runner`
Supporting Personas: `samwise`, `venture-product-steward`, `studio-integration-coordinator`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Bridge discussion to execution without collapsing execution into chat.

## Preconditions

- `M5` meeting continuity is stable enough to hand work forward
- `M6` structured objects can capture context and evidence
- the execution-owner persona for workstreams is explicitly approved

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

- one explicit identity owns execution-lane behavior

Work:

- confirm whether `worktree-squad-lead` is sufficient
- if not, stage or create `orbit-workstream-runner`
- define workstream handoff packet shape and approval rules

Done when:

- no workstream lane starts with fuzzy authority or implicit autonomy

### Packet 2. Implement Workstream Runtime Model

Outcome:

- workstream posts have durable state, assignment, and lifecycle records

Work:

- implement workstream post shape
- implement assignment records
- implement status model and lifecycle transitions

Done when:

- a workstream exists as a first-class runtime object instead of a note in a
  thread

### Packet 3. Implement Handoff From Discussion To Execution

Outcome:

- a source post can launch bounded execution intentionally

Work:

- define launch paths from message and meeting posts
- preserve source context and acceptance criteria in the handoff
- define explicit blocked and failed states

Done when:

- the originating discussion can show that concrete work has started elsewhere

### Packet 4. Implement Progress And Artifact Return

Outcome:

- workstream progress is visible in Orbit without flooding the source thread

Work:

- stream progress updates back
- attach artifacts to the workstream and source context
- summarize closeout state explicitly

Done when:

- the operator can inspect progress, artifacts, and closeout cleanly

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

- workstream contract note
- example launch packet
- workstream lifecycle example
- progress and artifact return example
- closeout and validation artifacts

## Stop Points

- stop if the workstream owner persona is unresolved
- stop if workstreams begin performing hidden consequential actions
- stop if closeout is implied instead of explicitly recorded

## Exit And Handoff

Exit when a post can launch a bounded workstream and receive visible progress,
artifacts, and closeout back into Orbit.

Handoff forward to:

- `M8` for journaling from real workstream activity
