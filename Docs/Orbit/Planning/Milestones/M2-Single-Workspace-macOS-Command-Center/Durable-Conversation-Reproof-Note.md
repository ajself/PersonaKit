# Durable Conversation Re-Proof Note

Status: Ready For Planning Closeout
Milestone: `M2`
Owner: `senior-swiftui-engineer`
Review Ring: `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Record the Packet 3 re-proof that Orbit conversation state survives local reload
without losing thread shape, speaker attribution, or checkpoint coherence.

## What Was Re-Proved

### Direct address survives reload

- a direct-address turn can be written through the real workspace-local Orbit
  store and reloaded into a fresh workspace session
- the response remains attributed to Samwise after reload
- the activation record and contract snapshot remain linked after reload

### Lightweight meeting survives reload

- a founding-group exchange can be written and reloaded as one durable room
  thread
- both participant responses remain attributable after reload
- the interaction mode remains `lightweight meeting`

### Empty and seeded states remain coherent

- the seeded default workspace still loads as the believable first-checkpoint room
- the empty-state variant round-trips without inventing fake activity or
  accidental records

## Deterministic Proof Added

- `OrbitWorkspacePersistenceTests.directAddressRoundTripsAcrossReloadWithAttribution`
- `OrbitWorkspacePersistenceTests.lightweightMeetingRoundTripsAcrossReloadWithAttribution`
- `OrbitWorkspacePersistenceTests.emptyWorkspaceRoundTripsWithoutInventingDiscussion`

## Supporting Alignment

- `OrbitSnapshotTests` now use `OrbitWorkspacePersistence` instead of hand-rolled
  file writing, so snapshot fixtures and runtime persistence share the same store
  path and encoding rules

## Packet 3 Judgment

Packet 3 is strong enough to proceed because the current Orbit room can now be
described as durably reloadable in seeded, empty, direct-address, and lightweight
meeting conditions without losing visible speaker identity.
