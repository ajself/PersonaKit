# M4 Packet 4: Participation Roles And Completion Semantics

Status: Ready For Planning Closeout
Packet Id: `M4-P4`
Milestone: `M4`
Execution Owner: `orbit-meeting-coordinator`
Review Personas: `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-20

## Header

- status: `needs-review`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Define the smallest participation-role and completion-state model that makes a
  group exchange understandable.
- This packet exists now because the operator needs visible state, not just more
  replies.
- This is the right slice size because role and state semantics can be sharpened
  separately from target expansion and inline reply behavior.

## Quality Bar

- participant roles are visible enough to understand what Orbit expects
- completion state distinguishes active, complete, partial, and failed paths
- partial-failure behavior remains explicit instead of hidden in aggregate success

## Preconditions

- `M4-P1`, `M4-P2`, and `M4-P3` are coherent enough to describe who participates
  and how replies stay inline
- `orbit-meeting-coordinator` is approved and available through `PHR-0009`
- the M4/M5 boundary is still explicit

## Grounding Requirements

- `.personakit/Sessions/orbit-meeting-coordinator-review.session.json`
- `Packet-03-Inline-Group-Reply-Flow.md`
- `Decision-Register.md`
- `Validation-And-Review-Matrix.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- live grounding required: `yes`

## Exact Scope

Include:

- role vocabulary for the first collaboration slice
- visible completion states for group exchange
- partial-failure behavior expectations

Exclude:

- meeting-only governance roles
- advanced deliberation or moderation policies
- workstream execution state

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/`
- may create: role tables, state examples, and partial-failure notes inside the
  `M4` dossier
- must not edit: `M5`, `M7`, or runtime implementation paths in this packet

## Ordered Work

1. Define the minimum role vocabulary needed for the first `M4` slice.
2. Define visible completion states and the partial-failure path.
3. Return examples that make the trust review in `M4-P5` concrete.

## Validation And Evidence

- one role table for the first slice
- one complete-path example and one partial-failure example
- validation questions aligned with the `M4` review matrix

## Failure Dispositions

- `blocked`
  earlier packet contracts are still too vague to define visible state honestly
- `needs-review`
  AJ needs to approve the role and state vocabulary before runtime work begins
- `grounding-blocked`
  required coordinator grounding is unavailable
- `failed`
  the packet cannot make state legible without importing later milestone behavior

## Stop Points

- stop if the role model starts importing full meeting governance
- stop if completion state cannot show partial failure clearly

## Closeout Return Format

- role and state contract defined
- examples and evidence produced
- open risks
- review decisions needed
- next recommended packet: `M4-P5`
