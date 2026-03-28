# M7 Progress And Artifact Return Example

Status: Ready For Review
Milestone: `M7`
Prepared For: `venture-product-steward`, `studio-integration-coordinator`, `studio-coverage-architect`, `AJ`
Prepared By: `samwise`
Last Updated: 2026-03-27

## Purpose

Show how source context receives bounded, reviewer-visible return signals from a
workstream without mirroring the full workstream thread or silently duplicating
artifact attachments.

## Source Context View

For source post `message-post-201`, the first-slice returned view should make it
possible to inspect:

- linked workstream:
  `workstream-post-301`
- latest returned status:
  `in_progress`, `blocked`, `completed`, `failed`, or `cancelled`
- latest returned checkpoint or blocker summary
- whether artifacts are available
- whether closeout has been recorded

## Returned Signal Sequence

### Launch Return

- returned signal:
  workstream launched
- source visibility:
  source post now shows one linked workstream and the handed-forward outcome
- workstream thread remains the detailed execution home

### Progress Return

- returned signal:
  state transition into `in_progress`
- source visibility:
  one bounded status update confirms that execution has started
- not returned:
  full progress-note transcript or routine executor chatter

### Blocker Return

- returned signal:
  `blocked`
- source visibility:
  one concise blocker summary is attached to the source context
- workstream thread keeps:
  detailed rationale, discussion, and recovery notes

### Artifact Return

- returned signal:
  artifact available
- source visibility:
  bounded artifact summary or structured reference back to the workstream
- source-of-truth posture:
  the durable artifact attachment remains on `workstream-post-301`
- forbidden posture:
  silently duplicating the same attachment record onto the source post

### Closeout Return

- returned signal:
  explicit terminal closeout
- source visibility:
  terminal status, concise closeout summary, and whether artifacts or
  references were produced
- closeout posture:
  remains compatible with `note_type = workstream_closeout`

## Why This Example Matters

- it proves that the source context remains readable even when the workstream
  thread contains richer internal history
- it proves that artifact inspectability does not depend on dual-write
  attachment behavior
- it proves that completion, failure, and cancellation remain explicit rather
  than being inferred from thread silence

## Review Focus

- bounded source visibility should add signal without replaying the workstream
  thread
- artifact linkage should remain inspectable while preserving one durable source
  of truth
- closeout should read as an explicit returned outcome, not as background drift
