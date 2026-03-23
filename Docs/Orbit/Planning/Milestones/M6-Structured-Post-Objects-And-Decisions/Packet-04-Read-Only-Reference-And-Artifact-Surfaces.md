# M6 Packet 4: Read-Only Reference And Artifact Surfaces

Status: Concluded Locally
Packet Id: `M6-P4`
Milestone: `M6`
Prepared By: `samwise`
Last Updated: 2026-03-23

## Purpose

Freeze the first `M6-P4` UI slice so supporting evidence and produced outputs
become inspectable from one originating post without reopening `M5` or
broadening into connectors, previews, or editing UX.

## Objective

- add one separate structured references-and-artifacts card
- power it from the canonical ordered attachment lane already shipped in
  `M6-P2`
- keep the current meeting outputs card and the accepted `M6-P3` notes and
  decisions card stable

## Quality Bar

- the new surface reads from `structured_attachment` order rather than parallel
  per-type arrays
- meeting-post references dedupe back to `M5` only when a mirrored
  `meetingReferenceRecord` exists
- artifacts stay fully inspectable on message and meeting posts
- no part of this packet broadens into editing UX, previews, connector
  semantics, artifact storage expansion, workstreams, or memory

## Exact Scope

Include:

- one separate structured references-and-artifacts card
- one active originating post at a time
- ordered mixed reference/artifact presentation from the canonical attachment
  lane
- metadata-only rows with creator attribution and timestamp captions

Exclude:

- editing flows for references or artifacts
- open actions, inline previews, or file loading
- changes to runtime schema, network payloads, or meeting-completion writes
- changes that replace or weaken the accepted `M5` meeting outputs card

## Chosen Defaults

- read-only only
- separate card rather than folding into the notes-and-decisions card
- ordered mixed list rather than type-grouped sections
- meeting-post structured references become compact rows only when a matching
  `meetingReferenceRecord.id` exists
- artifacts always render as full metadata rows
- no empty placeholder card
- hide the new card while meeting completion is actively editable

## Implementation Rules

- use `activeStructuredPostObjectRecords` / `orderedStructuredObjectRecords` as
  the sole source of truth for the new card
- do not expand `meetingReferenceRecords` or other `M5`-specific records to
  power the new surface
- do not change runtime schema, server projection shape, or request/response
  contracts in this packet
- use display labels in the new surface rather than raw enum values for
  `reference_type` and `artifact_type`

## Validation And Evidence

- focused Studio tests for mixed evidence ordering, meeting-post dedupe, and
  visibility rules
- projection coverage proving structured reference and artifact payloads survive
  into Studio
- persistence coverage proving the ordered evidence payload survives reload
- message-post and meeting-post snapshots showing the new evidence card without
  weakening the accepted `M5` or `M6-P3` surfaces
