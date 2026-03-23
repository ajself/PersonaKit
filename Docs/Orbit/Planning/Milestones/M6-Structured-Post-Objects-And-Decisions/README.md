# M6 Structured Post Objects And Decision Packets

Status: In Progress - M6-P5 product and interaction review preparation underway
Primary Owner: `venture-product-steward`
Supporting Personas: `senior-swiftui-engineer`, `studio-interaction-quality-lead`, `architectural-editor`
Last Updated: 2026-03-23

## Purpose

Stop important context from disappearing into thread text by attaching durable,
inspectable objects to posts and meetings.

## Current Milestone Position

- `M6-P1` remains the authoritative semantic freeze for `note`, `decision`,
  `reference`, and `artifact`.
- `M6-P2` is now concluded locally: ordered attachment reads and projection are
  implemented through `structured_attachment`, replay and reload stay stable for
  mixed structured objects on one post, and the current `M5` meeting-output
  surface remains stable.
- `M6-P3` is now concluded locally: one separate structured notes-and-decisions
  card ships from canonical `structured_attachment` order, preserves the
  accepted `M5` meeting outputs card, and keeps note and decision inspection
  read-only.
- `M6-P4` is now concluded locally: one separate structured
  references-and-artifacts card ships from canonical
  `structured_attachment` order, preserves the accepted `M5` meeting-reference
  surface as a separate legacy section, and keeps evidence inspection
  read-only.
- `M6-P5` is now the active review packet: the next pass prepares the dossier,
  examples, and product-and-interaction artifact needed to judge whether the
  shipped `M6` surfaces add signal rather than overhead.

## File Map

- `README.md`
  milestone overview, packet order, and current closeout/readiness posture
- `Packet-01-Freeze-Object-Definitions.md`
  accepted first-pass object-definition freeze for `M6`
- `Packet-02-Attachment-Plumbing-Closeout.md`
  local closeout note for the ordered attachment runtime and projection slice
- `Packet-03-Readiness-Review.md`
  readiness judgment for the note-and-decision surface packet
- `Packet-03-Read-Only-Note-And-Decision-Surfaces.md`
  execution note freezing the first `M6-P3` read-only surface slice
- `Packet-04-Read-Only-Reference-And-Artifact-Surfaces.md`
  execution note freezing the first `M6-P4` read-only evidence slice
- `Packet-05-Product-And-Interaction-Review.md`
  packet contract freezing the first `M6-P5` product-and-interaction review
  pass
- `Structured-Object-Surface-Examples.md`
  reviewer-readable examples of the shipped message-post and meeting-post
  structured-object surfaces
- `Product-And-Interaction-Review-Artifact.md`
  prepared `M6-P5` review artifact grounded in shipped docs, tests, and
  snapshots

## Preconditions

- `M5` continuity model is stable enough to carry structured meeting outputs
- canonical runtime object attachment rules from `M3` are available
- product intent is clear enough to define note, decision, reference, and
  artifact differences

## Scope Freeze

In scope:

- attached notes
- attached decisions
- attached references
- attached artifacts
- inspection surfaces from posts and meetings

Out of scope:

- making structured objects a second top-level collaboration system
- automated memory promotion from structured objects
- connector catalog work for external reference sources

## Required Inputs

- `Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `M5` meeting output examples

## Execution Packets

### Packet 1. Freeze Object Definitions

Outcome:

- notes, decisions, references, and artifacts each have one clear first-pass job

Work:

- define required fields for each object
- define what belongs in a decision packet versus a note
- define how references and artifacts differ

Done when:

- later UI and persistence work can proceed without relitigating object meaning

### Packet 2. Implement Attachment Plumbing

Outcome:

- structured objects attach to posts and meetings through one durable model

Work:

- implement attachment records
- define ordering and inspection behavior
- keep attachments bound to originating collaboration context

Done when:

- one post can hold multiple structured objects without model confusion

### Packet 3. Implement Note And Decision Surfaces

Outcome:

- the most important structured objects are visible enough to be used in real
  collaboration

Work:

- render read-only note and decision surfaces from the ordered attachment lane
- keep the accepted `M5` meeting outputs card stable as a separate surface
- defer editing, full reference surfaces, and artifact surfaces to later packets

Done when:

- readers can inspect ordered notes and decisions for one originating post
  without rereading the whole thread

### Packet 4. Implement Reference And Artifact Surfaces

Outcome:

- supporting evidence is discoverable from the originating context

Work:

- render read-only reference and artifact surfaces from the ordered attachment
  lane
- keep the accepted `M5` meeting references surface stable as a separate legacy
  section
- defer previews, open actions, and connector-aware artifact handling to later
  packets

Done when:

- a reader can inspect ordered references and artifacts for one originating post
  without broadening into previews or editing

### Packet 5. Run Product And Interaction Review

Outcome:

- the feature earns its complexity

Work:

- review the shipped read-only `M6-P3` and `M6-P4` surfaces as one bounded
  story
- verify that structured objects clarify workflows without replacing the post
  model
- identify clutter, duplication, or boundary risks before any later broadening

Done when:

- product and interaction reviewers can judge the shipped surfaces from explicit
  dossier artifacts instead of code reconstruction

## Subagent Use Pattern

Safe subagents:

- object-model review
- decision-packet UX review
- architectural boundary review

Avoid:

- expanding attachments into workflow automation during the first object slice

## Evidence Package

- object-definition note
- attachment-plumbing closeout note
- structured-object surface examples for message and meeting posts
- product and interaction review artifact

## Stop Points

- stop if structured objects start replacing the post model instead of attaching
  to it
- stop if decision packets lose rationale or evidence fields
- stop if the attachment UX becomes heavier than the collaboration value it adds

## Exit And Handoff

Exit when serious posts and meetings can accumulate durable structured outputs
that remain inspectable and contextual.

Handoff forward to:

- `M7` for workstream handoff
- `M8` later, when journals and memory candidates can cite these outputs
