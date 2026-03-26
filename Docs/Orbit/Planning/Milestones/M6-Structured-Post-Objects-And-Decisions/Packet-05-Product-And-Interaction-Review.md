# M6 Packet 5: Product And Interaction Review

Status: Ready For Review
Packet Id: `M6-P5`
Milestone: `M6`
Execution Owner: `venture-product-steward`
Review Personas: `studio-interaction-quality-lead`, `samwise`
Last Updated: 2026-03-26

## Header

- status: `ready-for-review`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Decide whether the shipped `M6-P3` and `M6-P4` structured-object surfaces add
  signal rather than overhead.
- This packet exists now because the runtime, projection, and read-only Studio
  surfaces are already present, but the dossier still lacks the explicit review
  package needed to judge product value without code archaeology.
- This is the right slice size because it prepares one bounded product and
  interaction review pass instead of widening into more UI work or milestone
  closeout improvisation.

## Quality Bar

- reviewers can inspect the shipped message-post and meeting-post surfaces from
  explicit dossier artifacts
- the current read-only surfaces are judged against clarity, boundedness, and
  duplication risk rather than implementation confidence alone
- the review packet stays attached to the accepted `M5` and `M6` boundaries and
  does not reopen `M6-P1`, `M6-P3`, or `M6-P4`

## Preconditions

- `M6-P1` remains the accepted semantic floor for `note`, `decision`,
  `reference`, and `artifact`
- `M6-P2` remains the accepted ordered-attachment runtime and projection
  baseline
- `M6-P3` and `M6-P4` are both shipped locally as read-only surfaces in the
  current macOS room
- the accepted `M5` meeting outputs surface remains the coexistence baseline
  for meeting-post review

## Grounding Requirements

- local `personakit` CLI grounding for `samwise` with directive `apply-style`
- `README.md`
- `Packet-01-Freeze-Object-Definitions.md`
- `Packet-02-Attachment-Plumbing-Closeout.md`
- `Packet-03-Read-Only-Note-And-Decision-Surfaces.md`
- `Packet-04-Read-Only-Reference-And-Artifact-Surfaces.md`
- `Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/Meeting-Output-Examples.md`
- live grounding required: `yes`

## Exact Scope

Include:

- dossier and evidence preparation for the first `M6-P5` review pass
- review of the shipped read-only message-post and meeting-post surfaces
- explicit findings about clarity, duplication, and boundary discipline
- residual risks and next-boundary recommendations grounded in the shipped slice

Exclude:

- new UI implementation work
- editing flows, previews, open actions, or connector-aware artifact behavior
- runtime schema, projection-shape, or request/response changes
- workstream, memory, or later-milestone behavior
- any review that depends on reopening `M6-P1` object semantics

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/`
- may create: one packet contract, one examples primer, and one prepared review
  artifact inside the `M6` dossier
- must not edit: runtime source paths, Studio implementation files, `M5`
  dossier files, or later milestone dossiers in this packet

## Ordered Work

1. Confirm the current `M6` dossier and status markers match the shipped
   `P3`/`P4` reality.
2. Assemble one reviewer-readable examples primer for the message-post and
   meeting-post surfaces.
3. Record the product and interaction review questions, evidence set, and
   prepared findings for the shipped surfaces.
4. Return residual risks and next-boundary recommendations without broadening
   into new implementation scope.

## Validation And Evidence

- current milestone README aligned with shipped `M6-P3` / `M6-P4` status
- one packet-local contract for `M6-P5`
- one examples primer that covers both message-post and meeting-post surfaces
- one product-and-interaction review artifact updated with the actual local
  findings from shipped docs, implementation, tests, and snapshots

## Failure Dispositions

- `ready-for-review`
  dossier, examples, and review artifact exist and are internally consistent
- `needs-review`
  the review package exists but still needs reviewer confirmation or sharper
  wording before it should guide milestone judgment
- `blocked`
  the dossier still has missing or contradictory evidence that prevents an
  honest review pass
- `grounding-blocked`
  required PersonaKit grounding or local evidence inputs are unavailable

## Stop Points

- stop if the review implies reopening `M6-P1`
- stop if the review requires broad UI redesign rather than bounded findings
- stop if the review starts pulling in workstream, preview, connector, or
  memory semantics

## Closeout Return Format

- dossier status normalized
- examples primer prepared
- review artifact updated with actual findings
- residual risks
- disposition: `ready-for-review`, `needs-review`, `blocked`, or
  `grounding-blocked`
