# M6 Packet 2: Attachment Plumbing Closeout

Status: Done - Local Closeout
Packet Id: `M6-P2`
Milestone: `M6`
Prepared By: `samwise`
Last Updated: 2026-03-23

## Purpose

Record the smallest coherent closeout note for the `M6-P2` slice that made
structured attachments readable and projectable in one ordered per-post lane.

## Scope Closed Here

- `structured_attachment` is now the canonical ordering and origin-binding
  source for attached structured objects on one originating post.
- mixed `note`, `decision`, `reference`, and `artifact` objects can now be read
  and projected through one coherent ordered model without confusing per-type
  arrays for display order.
- replay and reload preserve that ordered attachment lane.
- current `M5` meeting-output behavior remains stable; this packet does not add
  new UI surfaces.

## Evidence In Repo

- ordered attachment records and mixed-object ordering helpers in
  `Sources/Features/OrbitServerRuntime/Phase1RuntimeRecords.swift`
- meeting completion payload and replay support for ordered attachments in
  `Sources/Features/OrbitServerRuntime/Phase1MeetingCompletionService.swift`,
  `Sources/Features/OrbitServerRuntime/Phase1RealtimeEventPayloads.swift`, and
  `Sources/Features/OrbitServerRuntime/Phase1RealtimeSnapshotReducer.swift`
- ordered projection into the macOS room model in
  `Sources/Features/Studio/UI/Orbit/OrbitServerRoomProjection.swift` and
  `Sources/Features/Studio/UI/Orbit/OrbitModels.swift`
- deterministic coverage in:
  - `Tests/Features/OrbitServer/Phase1StructuredAttachmentModelTests.swift`
  - `Tests/Features/OrbitServer/Phase1MeetingCompletionServiceTests.swift`
  - `Tests/Features/OrbitServer/Phase1RealtimeSnapshotReducerTests.swift`
  - `Tests/Features/Studio/OrbitServerRoomProjectionTests.swift`
  - `Tests/Features/Studio/OrbitWorkspacePersistenceTests.swift`
  - `Tests/Features/OrbitServer/OrbitPostgresRuntimeStoreIntegrationTests.swift`

## Validation Readout

- `personakit validate --root .personakit` passed during this closeout pass.
- targeted structured-attachment unit and projection coverage passed before the
  local closeout commit for the runtime and Studio projection slice.
- on 2026-03-23, `Scripts/run-orbit-live-db-proof.sh --runs 1 --filter
  OrbitPostgresRuntimeStoreIntegrationTests --local-temp-postgres` passed
  against a temporary local `Postgres` instance, including the mixed structured
  attachment ordering regression and the meeting-completion round-trip.

## Explicit Boundaries Preserved

- `M6-P1` object definitions remain authoritative and were not reopened here.
- explicit creator attribution remains preserved for new `decision` and
  `reference` writes, and the existing legacy backfill rule was not changed.
- this packet does not add note, decision, reference, or artifact UI surfaces.
- this packet does not broaden into workstreams, connector semantics, memory, or
  `M7`.

## Packet 2 Judgment

`M6-P2` is now strong enough to hand off cleanly: one post can hold multiple
structured objects, the canonical order survives replay and reload, and later
surface work can build on the ordered attachment lane instead of inventing
parallel ordering logic.
