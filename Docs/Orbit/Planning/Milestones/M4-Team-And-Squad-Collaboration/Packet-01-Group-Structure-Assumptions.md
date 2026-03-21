# M4 Packet 1: Group Structure Assumptions

Status: Ready For Planning Closeout
Packet Id: `M4-P1`
Milestone: `M4`
Execution Owner: `orbit-meeting-coordinator`
Review Personas: `samwise`, `venture-product-steward`
Last Updated: 2026-03-20

## Header

- status: `needs-review`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Freeze the first-pass meaning of teams, squads, and group-target inspection for
  the `M4` collaboration slice.
- This packet exists now because target expansion will drift immediately if the
  underlying group semantics stay implicit.
- This is the right slice size because it sharpens the contract without starting
  runtime work.

## Quality Bar

- teams and squads have one explicit first-pass meaning
- supported target syntax is small and reviewable
- membership inspection stays visible and Orbit-owned

## Preconditions

- `M3` runtime and trace posture are trusted enough to support collaboration
  records
- `orbit-meeting-coordinator` is approved and available through `PHR-0009`
- `RFC-0003` and `RFC-0004` have been reviewed together

## Grounding Requirements

- `.personakit/Sessions/orbit-meeting-coordinator-review.session.json`
- `README.md`
- `Decision-Register.md`
- `Docs/Orbit/RFCs/RFC-0003-Workspace-Group-and-Workspace-Persona-Instance-Model.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- live grounding required: `yes`

## Exact Scope

Include:

- first-pass team and squad semantics
- supported target forms for the first collaboration slice
- where the operator inspects memberships and expansion inputs

Exclude:

- meeting promotion and continuity behavior
- workstream handoff semantics
- runtime implementation or schema work

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/`
- may create: packet-local examples or decision notes inside the `M4` dossier
- must not edit: `M5`, `M7`, or runtime product implementation paths in this
  packet

## Ordered Work

1. Reconcile `RFC-0003` and `RFC-0004` into one first-pass definition for teams,
   squads, and their operator-facing inspection surface.
2. Freeze the allowed target forms and explicitly record what is deferred.
3. Return the decision closures and open risks needed by `M4-P2`.

## Validation And Evidence

- updated packet note and aligned `Decision-Register.md`
- at least one team-target example and one squad-target example
- explicit note describing what remains deferred to later packets

## Failure Dispositions

- `blocked`
  required upstream structure or runtime assumptions remain unclear
- `needs-review`
  AJ needs to approve the first-pass group meaning before runtime-facing work
- `grounding-blocked`
  required coordinator grounding is unavailable
- `failed`
  the packet cannot define teams and squads without reopening later-milestone
  scope

## Stop Points

- stop if group semantics require `M5` continuity or `M7` workstream behavior
- stop if supported target syntax would force ad hoc roster behavior into the
  first slice

## Closeout Return Format

- decisions closed or explicitly staged
- examples and evidence produced
- open risks
- review decisions needed
- next recommended packet: `M4-P2`
