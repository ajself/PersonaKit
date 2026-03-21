# M4 Team And Squad Collaboration With Visible Coordinator Expansion

Status: Ready For Planning Closeout
Primary Owner: `orbit-meeting-coordinator`
Supporting Personas: `samwise`, `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-20

## Purpose

Let the operator ask a group for input and inspect why each participant was
included.

## Quality Standard

`M4` is not successful because multiple participants can technically reply.

`M4` is successful only when group collaboration remains:

- deterministic about who was asked and why
- inspectable without debugger-only reasoning
- attributable inside the existing conversation surface
- bounded away from `M5` meeting promotion and `M7` workstream execution

The bare minimum is not a milestone win.

## File Map

- `README.md`
  milestone overview, packet order, and top-level guardrails
- `Quality-Bar.md`
  milestone-specific definition of trustworthy, review-worthy group
  collaboration
- `Validation-And-Review-Matrix.md`
  named validation owners, review passes, and disqualifiers
- `Decision-Register.md`
  high-impact coordinator decisions that must close or remain explicitly staged
- `Packet-01-Group-Structure-Assumptions.md`
  preflight packet contract for freezing first-pass team and squad semantics
- `Packet-02-Target-Expansion.md`
  preflight packet contract for deterministic participant expansion and reason
  visibility
- `Packet-03-Inline-Group-Reply-Flow.md`
  preflight packet contract for bounded inline multi-participant replies
- `Packet-04-Participation-Roles-And-Completion-Semantics.md`
  preflight packet contract for visible role and state semantics
- `Packet-05-Trust-And-Inspectability.md`
  preflight packet contract for the evidence needed before `M4` can be treated
  as trustworthy

## Preconditions

- `M3` canonical runtime is stable enough to support group participation records
- `orbit-meeting-coordinator` is approved and available
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
- starting runtime-facing packet work from dossier hardening alone

## Evidence Package

- packet-level planning notes with explicit scope, grounding, and stop points
- target expansion examples and participant reasoning examples
- participation-role and partial-failure examples
- validation and review matrix results
- trust and interaction review artifacts

## Stop Points

- stop if `orbit-meeting-coordinator` is not approved
- stop if inclusion reasoning cannot be shown clearly
- stop if group routing starts feeling provider-owned instead of Orbit-owned
- stop if packet docs begin authorizing runtime work before AJ reviews the
  dossier

## Exit And Handoff

Exit when a team or squad can be addressed naturally and the resulting exchange
is attributable, inspectable, and reviewable.

Handoff forward to:

- `M5` for meeting promotion and continuity
