# M4 Packet 2: Target Expansion

Status: Ready For Planning Closeout
Packet Id: `M4-P2`
Milestone: `M4`
Execution Owner: `orbit-meeting-coordinator`
Review Personas: `venture-product-steward`, `studio-coverage-architect`
Last Updated: 2026-03-20

## Header

- status: `needs-review`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Define the deterministic target-expansion contract that turns a team or squad
  target into explicit participants and visible reasons.
- This packet exists now because trust depends on knowing who was asked before
  inline collaboration can feel believable.
- This is the right slice size because it isolates expansion logic from reply
  rendering and later meeting behavior.

## Quality Bar

- the same target yields the same participants under the same workspace state
- inclusion and exclusion reasons are visible enough to defend
- expansion results are inspectable without provider-owned magic

## Preconditions

- `M4-P1` froze team and squad semantics
- `orbit-meeting-coordinator` is approved and available through `PHR-0009`
- the operator-visible trace posture from `M3` is trusted

## Grounding Requirements

- `.personakit/Sessions/orbit-meeting-coordinator-review.session.json`
- `.personakit/Sessions/orbit-meeting-coordinator-delivery.session.json`
- `Packet-01-Group-Structure-Assumptions.md`
- `Validation-And-Review-Matrix.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- live grounding required: `yes`

## Exact Scope

Include:

- the expansion input and output contract
- inclusion and exclusion reason categories
- operator-visible examples for successful and negative expansion cases

Exclude:

- inline reply sequencing or rendering
- promoted meeting behavior
- heuristic ranking or provider-specific routing logic

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/`
- may create: expansion examples and review notes inside the `M4` dossier
- must not edit: runtime collaboration code or later milestone dossiers in this
  packet

## Ordered Work

1. Define the participant-expansion contract and the minimum explanation shape.
2. Add examples that cover inclusion, exclusion, and empty-or-blocked cases.
3. Return explicit validation expectations needed by `M4-P5`.

## Validation And Evidence

- target expansion examples for at least one team and one squad
- one explicit exclusion example
- review note confirming the reasoning stays operator-visible

## Failure Dispositions

- `blocked`
  `M4-P1` decisions are still unresolved
- `needs-review`
  AJ needs to review the reason model before runtime work begins
- `grounding-blocked`
  required coordinator grounding is unavailable
- `failed`
  expansion remains opaque or inconsistent after the packet work

## Stop Points

- stop if participant selection cannot be explained without hidden heuristics
- stop if exclusions cannot be shown clearly when they materially affect trust

## Closeout Return Format

- expansion contract defined
- examples and evidence produced
- open risks
- review decisions needed
- next recommended packet: `M4-P3`
