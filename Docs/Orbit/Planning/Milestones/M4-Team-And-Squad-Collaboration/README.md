# M4 Team And Squad Collaboration With Visible Coordinator Expansion

Status: Planned
Primary Owner: `orbit-meeting-coordinator` or blocked until that persona exists
Supporting Personas: `samwise`, `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Let the operator ask a group for input and inspect why each participant was
included.

## Preconditions

- `M3` canonical runtime is stable enough to support group participation records
- `orbit-meeting-coordinator` exists as an approved persona or AJ approves a
  temporary substitute
- operator-visible activation and participation traces are already trusted

## Scope Freeze

In scope:

- team and squad addressing
- group-target expansion into workspace persona instances
- inclusion and exclusion reasons
- inline group reply flow
- participation roles and visible completion semantics for basic group exchange

Out of scope:

- promoted meeting posts with full continuity package
- advanced deliberation patterns
- saved ad hoc roster systems beyond what the first group-collaboration slice
  requires

## Required Inputs

- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- `Docs/Orbit/RFCs/RFC-0003-Workspace-Group-and-Workspace-Persona-Instance-Model.md`
- `M3` canonical runtime contract and evidence

## Execution Packets

### Packet 1. Freeze Group Structure Assumptions

Outcome:

- team and squad records have one stable first-pass meaning

Work:

- define persistent team and squad semantics
- define allowed group targeting syntax
- define where memberships live and how they are inspected

Done when:

- target expansion can operate on stable structures instead of ad hoc rosters

### Packet 2. Implement Target Expansion

Outcome:

- a group target expands into explicit participants every time

Work:

- implement coordinator roster expansion
- record inclusion reasons and exclusion reasons
- surface expansion results before or with replies

Done when:

- the operator can see who was asked and why

### Packet 3. Implement Inline Group Reply Flow

Outcome:

- group collaboration begins inside the existing post or thread model

Work:

- run attributed replies inline
- preserve existing activation and message traceability
- keep inline group reply legible without immediately promoting to a meeting

Done when:

- a group-targeted exchange feels explainable and bounded

### Packet 4. Add Participation Roles And Completion Semantics

Outcome:

- the operator can tell whether a group exchange is still active or done

Work:

- define participant roles
- define visible completion states
- define partial-failure behavior when some participants succeed and others fail

Done when:

- group behavior is no longer opaque or hand-wavy

### Packet 5. Prove Trust And Inspectability

Outcome:

- the feature can be trusted because it explains itself

Work:

- run trust review on participant reasoning
- run multi-participant validation suite
- run interaction review on roster legibility

Done when:

- AJ can target a group and inspect the expansion path confidently

## Subagent Use Pattern

Safe subagents:

- coordinator logic review
- roster reasoning review
- explainability review
- multi-participant validation

Avoid:

- hiding coordinator behavior behind generic system events
- parallel feature expansion into promoted meetings before inline group behavior
  is trusted

## Evidence Package

- group structure note
- target expansion examples
- participant reasoning examples
- partial-failure behavior examples
- trust and interaction review artifacts

## Stop Points

- stop if `orbit-meeting-coordinator` is not approved
- stop if inclusion reasoning cannot be shown clearly
- stop if group routing starts feeling provider-owned instead of Orbit-owned

## Exit And Handoff

Exit when a team or squad can be addressed naturally and the resulting exchange
is attributable, inspectable, and reviewable.

Handoff forward to:

- `M5` for meeting promotion and continuity
