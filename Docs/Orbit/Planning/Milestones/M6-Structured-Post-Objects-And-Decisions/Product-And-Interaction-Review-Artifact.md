# M6 Product And Interaction Review Artifact

Status: Draft
Milestone: `M6`
Review Pass: Product and interaction review
Prepared For: `venture-product-steward`, `studio-interaction-quality-lead`
Prepared By: `samwise`
Last Updated: 2026-03-23

## Purpose

Capture the current product and interaction review for `M6-P5` so the shipped
structured-object surfaces are judged by operator clarity, boundedness, and
signal-to-noise ratio rather than implementation confidence alone.

## Review Questions

- Do structured objects make serious posts easier to review without rereading
  the full thread?
- Does the three-surface meeting stack feel coherent rather than duplicative?
- Is canonical attachment ordering legible enough to justify separate cards?
- Do dedupe rules remove noise without hiding important context?
- Does the current surface stay attached to one originating post rather than
  feeling like a second collaboration system?
- Does the current first slice remain clearly bounded away from editing,
  preview, workstream, and memory behavior?

## Evidence Reviewed

- `README.md`
- `Structured-Object-Surface-Examples.md`
- `Packet-01-Freeze-Object-Definitions.md`
- `Packet-02-Attachment-Plumbing-Closeout.md`
- `Packet-03-Read-Only-Note-And-Decision-Surfaces.md`
- `Packet-04-Read-Only-Reference-And-Artifact-Surfaces.md`
- `Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/Meeting-Output-Examples.md`
- `Tests/Features/Studio/OrbitStructuredNotesAndDecisionsPresentationTests.swift`
- `Tests/Features/Studio/OrbitStructuredReferencesAndArtifactsPresentationTests.swift`
- `Tests/Features/Studio/OrbitServerRoomProjectionTests.swift`
- `Tests/Features/Studio/OrbitWorkspacePersistenceTests.swift`
- `Tests/Features/Studio/OrbitPanelViewMeetingCompletionTests.swift`
- `Tests/Features/Studio/OrbitSnapshotTests.swift`

## Prepared Findings

- The shipped `M6` surfaces make structured outputs inspectable from the
  originating post instead of burying durable context in thread prose alone.
- Canonical `structured_attachment` order now reads through both cards
  consistently, so mixed structured objects do not force the operator to infer
  hidden ordering logic.
- The meeting-post stack stays intentionally layered: accepted `M5` meeting
  outputs first, then structured notes and decisions, then structured
  references and artifacts.
- Current dedupe rules reduce noise rather than flattening meaning:
  `meeting_summary` points back to `M5`, mirrored meeting references collapse to
  compact rows, and artifacts remain fully visible because `M5` has no artifact
  surface.
- The current first slice remains visibly bounded: no editing UX, no previews,
  no connector-aware artifact behavior, and no workstream or memory semantics
  are implied by the current cards.

## Provisional Outcome

- Ready for reviewer confirmation as a believable first-slice `M6`
  structured-object surface package.
- Strong enough to support a real product and interaction review without
  reopening `M5` meeting basics or relitigating `M6-P1` object semantics.

## Residual Notes

- The current snapshot names still carry the `M6-P3` surface label even though
  the captured message-post and meeting-post examples now show the full shipped
  `M6-P3` plus `M6-P4` surface stack.
- The first slice intentionally favors separate cards over a unified inspector;
  if later milestones want a more consolidated surface, that should be treated
  as new work rather than silently folded into `M6-P5`.
- This artifact prepares the product and interaction review only. Validation and
  AJ closeout artifacts remain out of scope for this first `M6-P5` docs pass.
