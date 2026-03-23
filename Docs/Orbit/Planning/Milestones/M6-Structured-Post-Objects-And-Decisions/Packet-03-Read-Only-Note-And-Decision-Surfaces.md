# M6 Packet 3: Read-Only Note And Decision Surfaces

Status: In Progress
Packet Id: `M6-P3`
Milestone: `M6`
Prepared By: `samwise`
Last Updated: 2026-03-23

## Purpose

Freeze the first `M6-P3` UI slice so note and decision objects become visible
enough for real collaboration without reopening `M5`, `M6-P1`, or `M6-P2`.

## Objective

- add one read-only structured notes-and-decisions card
- power it from the canonical ordered attachment lane already shipped in
  `M6-P2`
- keep the current meeting outputs card and meeting-completion editing flow
  stable

## Quality Bar

- the new surface reads from `structured_attachment` order rather than parallel
  per-type arrays
- `M6-P1` decision semantics stay visible: body, rationale, tradeoffs, dissent,
  and linked evidence
- meeting-summary notes do not duplicate the `M5` summary body on meeting posts
- no part of this packet broadens into editing UX, full reference surfaces,
  artifact surfaces, workstreams, or memory

## Exact Scope

Include:

- one separate structured notes-and-decisions card
- one active originating post at a time
- ordered mixed note/decision presentation from the canonical attachment lane
- minimal read-only decision evidence display from linked references on the same
  post

Exclude:

- editing flows for notes or decisions
- broad reference or artifact inspectors
- changes to runtime schema, network payloads, or meeting-completion writes
- changes that replace or weaken the accepted `M5` meeting outputs card

## Chosen Defaults

- read-only only
- separate card rather than folding into the meeting outputs card
- ordered mixed list rather than type-grouped sections
- `meeting_summary` note references the meeting outputs card on meeting posts
  instead of repeating the full summary body
- linked decision evidence renders as titles-first read-only rows with compact
  secondary metadata
- no empty placeholder card
- hide the new card while meeting completion is actively editable

## Implementation Rules

- use `activeStructuredPostObjectRecords` / `orderedStructuredObjectRecords` as
  the sole source of truth for the new card
- do not expand `meetingSummaryRecords`, `meetingDecisionRecords`, or other
  `M5`-specific records to power the new surface
- do not change runtime schema, server projection shape, or request/response
  contracts in this packet
- if a linked reference id cannot be resolved after projection, keep a muted
  missing-evidence row rather than silently dropping it

## Validation And Evidence

- focused Studio tests for presentation rules, card visibility, and linked
  evidence fallback
- projection coverage proving ordered structured decision fields survive into
  Studio
- persistence coverage proving the ordered structured decision payload survives
  reload
- message-post and meeting-post snapshots showing the new card without weakening
  the accepted `M5` surface
