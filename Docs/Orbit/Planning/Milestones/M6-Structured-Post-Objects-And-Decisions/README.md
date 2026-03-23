# M6 Structured Post Objects And Decision Packets

Status: In Progress - `M6-P3` read-only note and decision surfaces underway
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
- `M6-P3` is now frozen as a bounded read-only surface packet: one separate
  structured notes-and-decisions card, one active post at a time, canonical
  order from `structured_attachment`, and no editing or broad reference/artifact
  UI work in this slice.

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

- render references and artifacts inline or in linked inspectors
- keep provenance visible
- avoid oversized attachment UX for the first slice

Done when:

- a reader can inspect the evidence packet behind a post or meeting outcome

### Packet 5. Run Product And Interaction Review

Outcome:

- the feature earns its complexity

Work:

- verify that structured objects clarify workflows
- verify that the first packet shape is small enough
- identify clutter or duplication risks before broadening further

Done when:

- product and interaction reviewers agree the objects add signal, not overhead

## Subagent Use Pattern

Safe subagents:

- object-model review
- decision-packet UX review
- architectural boundary review

Avoid:

- expanding attachments into workflow automation during the first object slice

## Evidence Package

- object-definition note
- attachment model example
- decision packet example
- reference and artifact example
- product and interaction review artifacts

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
