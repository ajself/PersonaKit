# M6 Structured Object Surface Examples

Status: Accepted
Milestone: `M6`
Prepared By: `samwise`
Last Updated: 2026-03-26

## Purpose

Capture the shipped `M6` structured-object surfaces in reviewer-readable form
so `M6-P5` can judge product and interaction quality from explicit examples
instead of code reconstruction.

## Boundary Reminder

- the current `M6` slice is read-only only
- notes, decisions, references, and artifacts remain attached to one
  originating post rather than becoming first-class post types
- no editing, previews, open actions, or connector-aware artifact behavior is
  introduced here
- no workstream or memory behavior is introduced here
- accepted `M5` meeting-output semantics remain intact and are not reopened by
  these examples
- the current snapshot names still use the `M6-P3` label, but they now show the
  full shipped structured-object surface from `M6-P3` plus `M6-P4`

## Example 1. Message Post With Ordered Structured Surfaces

The current message-post surface now shows one originating post with two
separate read-only cards driven from the same canonical ordered attachment lane:

- in the current shipped example, a structured references-and-artifacts card
  first because supporting context was attached first
- then a structured notes-and-decisions card for narrative and decision objects

What the operator can inspect:

- notes and decisions in canonical `structured_attachment` order within the
  notes-and-decisions card
- explicit creator attribution and timestamps on every visible row
- full decision semantics from `M6-P1`, including rationale, tradeoffs,
  dissent, and linked evidence
- references and artifacts in canonical attachment order within the evidence
  card rather than grouped by type
- the two structured cards follow the earliest attachment family from that
  canonical lane instead of a fixed notes-first stack
- evidence and outputs without rereading the full thread body

Evidence:

- `Packet-01-Freeze-Object-Definitions.md`
- `Packet-02-Attachment-Plumbing-Closeout.md`
- `Packet-03-Read-Only-Note-And-Decision-Surfaces.md`
- `Packet-04-Read-Only-Reference-And-Artifact-Surfaces.md`
- `Tests/Features/Studio/OrbitStructuredNotesAndDecisionsPresentationTests.swift`
- `Tests/Features/Studio/OrbitStructuredReferencesAndArtifactsPresentationTests.swift`
- `Tests/Features/Studio/OrbitSnapshotTests.swift`
- `Tests/Features/Studio/__Snapshots__/OrbitSnapshotTests/testOrbitStructuredNotesAndDecisionsMessagePost.orbit-structured-message-post.png`

## Example 2. Completed Meeting Post With Bounded Coexistence

The current completed meeting-post surface keeps the accepted `M5` Meeting
Outputs card as the first meeting-specific surface, then layers the shipped
`M6` structured-object cards below it.

What the operator can inspect:

- the `M5` Meeting Outputs card remains first and preserves summary, outcome,
  open questions, and follow-up references
- in this shipped example, the structured notes-and-decisions card appears below
  it and keeps
  `meeting_summary` deduped back to the `M5` card instead of repeating the full
  summary body
- in this shipped example, the structured references-and-artifacts card appears
  below that and keeps mirrored meeting references compactly deduped back to the
  `M5` card when a matching meeting reference already exists
- artifacts still render in full because `M5` has no artifact surface
- both `M6` cards remain hidden while meeting completion is actively editable,
  preserving the accepted `M5` drafting flow

Evidence:

- `Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/Meeting-Output-Examples.md`
- `Packet-02-Attachment-Plumbing-Closeout.md`
- `Packet-03-Read-Only-Note-And-Decision-Surfaces.md`
- `Packet-04-Read-Only-Reference-And-Artifact-Surfaces.md`
- `Tests/Features/Studio/OrbitPanelViewMeetingCompletionTests.swift`
- `Tests/Features/Studio/OrbitStructuredNotesAndDecisionsPresentationTests.swift`
- `Tests/Features/Studio/OrbitStructuredReferencesAndArtifactsPresentationTests.swift`
- `Tests/Features/Studio/OrbitSnapshotTests.swift`
- `Tests/Features/Studio/__Snapshots__/OrbitSnapshotTests/testOrbitStructuredNotesAndDecisionsMeetingPost.orbit-structured-meeting-post.png`

## Why This Is Enough For `M6-P5`

These examples show that the shipped `M6` slice now preserves:

- one canonical ordered attachment lane underneath both structured cards
- read-only inspectability for notes, decisions, references, and artifacts
- coexistence with the accepted `M5` meeting outputs surface
- visible attribution, earliest-family card order, card-local ordering, and
  bounded deduplication rules

They do not authorize:

- editing flows for structured objects
- artifact previews or open actions
- connector expansion or storage-policy work
- workstream handoff behavior from `M7`
- memory promotion or candidate behavior from later milestones
