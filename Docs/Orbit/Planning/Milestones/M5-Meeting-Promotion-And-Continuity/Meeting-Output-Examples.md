# M5 Meeting Output Examples

Status: Accepted
Milestone: `M5`
Prepared By: `samwise`
Last Updated: 2026-03-22

## Purpose

Capture the first durable `M5` meeting output shapes so later milestones can
see exactly what `M5` proved without broadening into `M6` structured-object
depth or `M7` workstream behavior.

## Boundary Reminder

- inline remains the explicit default for `v1`
- no team, squad, or other target class auto-promotes into meeting mode
- promotion failure still falls back inline unless explicitly overridden
- meeting outputs stay bounded to summary, outcome, open questions, and
  follow-up references
- no workstream handoff, artifacts, or memory-candidate behavior is introduced

## Example 1. Summary Shell Exists Before Completion

The first durable meeting output is a canonical `note` with
`note_type = meeting_summary`.
Meeting creation seeds exactly one summary shell for the meeting post, and
completion updates that same note in place rather than creating a second
summary object.

Evidence:

- `Sources/Features/OrbitServerRuntime/Phase1MeetingRoomCreationService.swift`
- `Sources/Features/OrbitServerRuntime/Phase1RuntimeRecords.swift`
- `Tests/Features/OrbitServer/Phase1MeetingRoomCreationServiceTests.swift`
- `Tests/Features/OrbitServer/Phase1RuntimeSchemaTests.swift`

## Example 2. Decision Completion Bundle

An explicit meeting completion with outcome `decision` now produces one bounded
canonical output bundle:

- updated `meeting_summary` note body
- one `meeting_output_state` row with `decision_recorded`
- zero or one canonical `decision` row
- zero or more ordered `meeting_open_question` rows
- zero or more ordered canonical `reference` rows
- one committed post event and realtime replay envelope

Evidence:

- `Sources/Features/OrbitServerRuntime/Phase1MeetingCompletionService.swift`
- `Sources/Features/OrbitServerRuntime/Phase1RuntimeRepository.swift`
- `Tests/Features/OrbitServer/Phase1MeetingCompletionServiceTests.swift`
- `Tests/Features/OrbitServer/Phase1RuntimeRepositoryTests.swift`
- `Tests/Features/OrbitServer/Phase1RealtimeSnapshotReducerTests.swift`
- `Tests/Features/OrbitServer/OrbitPostgresRuntimeStoreIntegrationTests.swift`

## Example 3. Explicit No-Decision Completion

An explicit meeting completion with outcome `no_decision` updates the summary in
place, records `meeting_output_state = no_decision_recorded`, and intentionally
creates no canonical `decision` row.

This preserves the `M5` boundary that no-decision truth is explicit and durable
without pretending a decision exists.

Evidence:

- `Sources/Features/OrbitServerRuntime/Phase1MeetingCompletionService.swift`
- `Tests/Features/OrbitServer/Phase1MeetingCompletionServiceTests.swift`
- `Tests/Features/Studio/OrbitServerBackedRoomCoordinatorTests.swift`

## Example 4. Inspectable After Replay And Reload

The projected macOS room now keeps the meeting output bundle inspectable after
realtime replay and workspace reload.
The operator can see:

- meeting lifecycle status
- explicit outcome status
- projected participant roster and roles
- open-question count and bodies
- follow-up reference count and targets

Evidence:

- `Sources/Features/Studio/UI/Orbit/OrbitServerRoomProjection.swift`
- `Sources/Features/Studio/UI/Orbit/OrbitModels.swift`
- `Sources/Features/Studio/UI/Orbit/OrbitPanelView+UI.swift`
- `Tests/Features/Studio/OrbitServerRoomProjectionTests.swift`
- `Tests/Features/Studio/OrbitWorkspacePersistenceTests.swift`
- `Tests/Features/Studio/OrbitServerBackedRoomCoordinatorTests.swift`

## Example 5. Visible In The Current macOS Surface

The current Orbit room now renders one bounded meeting outputs card between the
room header and the conversation card.
The header pills surface meeting status, outcome status, open-question count,
and follow-up reference count without adding separate completion UX flows or
workstream navigation.

Evidence:

- `Sources/Features/Studio/UI/Orbit/OrbitPanelView.swift`
- `Sources/Features/Studio/UI/Orbit/OrbitPanelView+UI.swift`
- `Tests/Features/Studio/OrbitPanelViewMeetingCompletionTests.swift`
- `Tests/Features/Studio/OrbitSnapshotTests.swift`

## Why This Is Enough For M5

These examples show that `M5` now preserves:

- continuity between origin and promoted meeting context
- one durable summary shell
- explicit decision versus no-decision truth
- inspectable review surfaces after replay and reload

They do not authorize:

- richer structured object semantics from `M6`
- workstream handoff behavior from `M7`
- memory or artifact behavior outside the accepted `M5` boundary
