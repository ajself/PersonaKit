# M6 Packet 3: Readiness Review

Status: Needs Another Planning Pass
Packet Id: `M6-P3`
Milestone: `M6`
Prepared By: `samwise`
Last Updated: 2026-03-23

## Purpose

Decide whether the current `M6` dossier is specific enough to start the note
and decision surface packet without reopening `M6-P1` or broadening beyond the
next smallest slice.

## Inputs Reviewed

- `Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/README.md`
- `Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/Packet-01-Freeze-Object-Definitions.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/Meeting-Output-Examples.md`
- `Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md`
- current ordered-attachment runtime and Studio projection paths

## What Is Already Ready

- the runtime now carries the ordered attachment lane needed for coherent
  per-post reads.
- the runtime object floor still preserves the `M6-P1` semantic decision fields
  such as rationale, tradeoffs, dissent, and linked reference ids.
- the Studio projection already has one ordered per-post structured-object model
  available through `orderedStructuredObjectRecords`.

## Why `M6-P3` Is Not Yet Ready For Work

- the milestone README still mixes two different scopes: rendering note and
  decision surfaces, and "make edits" work. That is too broad for the next
  smallest slice and risks pulling editing UX into `M6-P3` by accident.
- the dossier does not yet freeze the source-of-truth rule for surfaces. `M6-P3`
  should explicitly say that note and decision read surfaces derive from the
  ordered attachment lane, not from parallel meeting-only arrays or per-type
  sort rules.
- the dossier does not yet freeze the context boundary for the first surface
  slice. It needs to say exactly how the first note and decision read surface
  behaves on one originating post, how meeting posts differ from message posts
  if they differ at all, and how the accepted `M5` meeting-output card remains
  stable while the new surface is introduced.
- the dossier does not yet freeze the minimum visible decision fields for the
  first surface pass. `M6-P1` already froze the semantic field floor, but
  `M6-P3` still needs to decide which of those fields are visible in the first
  read-only surface and how explicit "none recorded" values should appear.

## Readiness Judgment

`M6-P3` needs another planning pass before implementation starts.

This is not a data-model blocker. The ordered attachment runtime and projection
lane are ready enough.

It is a packet-boundary blocker: the UI packet still needs one written first
slice that keeps the work read-only, derives from the canonical ordered
attachment lane, preserves the current `M5` surface, and defers edit flows plus
reference and artifact surfaces to later packets.

## Recommended Planning Target

The next planning pass should freeze one bounded `M6-P3` slice:

- read-only note and decision surfaces only
- one originating post at a time
- canonical order comes from `structured_attachment`
- no editing UX
- no reference or artifact surface work except the minimum linkage needed to
  keep decision evidence legible
- no reopening of `M6-P1`, `M6-P2`, or `M5`
