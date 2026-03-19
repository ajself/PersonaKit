# macOS Cutover Projection Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `senior-swiftui-engineer`
Review Ring: `venture-product-steward`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Record the first Packet 5 cutover slice that projects canonical room truth back
into the Orbit macOS room model.

## What Exists Now

- `OrbitServerRoomProjection.workspace(from:)`
- `OrbitServerBackedRoomState`
- `OrbitServerBackedRoomCoordinator`
- `OrbitServerBackedRoomClient`
- `OrbitServerBackedRoomClientFactory`
- `OrbitServerBackedRoomClient`
- `OrbitServerBackedRoomClientFactory`

These now exist in the Orbit Studio feature under:

- `OrbitServerRoomProjection.swift`
- `OrbitServerBackedRoomState.swift`
- `OrbitServerBackedRoomCoordinator.swift`
- `OrbitServerBackedRoomClient.swift`
- `OrbitServerBackedRoomClientFactory.swift`
- `OrbitServerBackedRoomClient.swift`
- `OrbitServerBackedRoomClientFactory.swift`

## Current Responsibility

The projection layer now proves that a canonical server-backed room snapshot can
be translated into the same Orbit room model the macOS command center expects.

The latest cutover slice also includes a server-backed room state reducer in
Studio that can apply replay events over the projected snapshot instead of
depending only on one-shot projection.

The latest coordinator slice now adds a client-side read path that can connect,
poll, and update the projected Orbit room from the transport contract.

The latest factory slice now lets `StudioRootView` provide a server-backed room
client to `OrbitPanelView` whenever the canonical runtime environment is
configured.

The latest factory slice now lets `StudioRootView` opt the Orbit panel into the
server-backed client path whenever the required environment-backed runtime
configuration exists.

Current preserved semantics:

- workspace name and room purpose
- founding roster with AJ, Samwise, and ProdDoc
- one active room thread
- direct user and participant response message meaning
- lightweight-meeting interaction mode when multiple workspace personas are
  present in the room
- replayed server events can now update the projected macOS room state without
  inventing a second local truth model
- the client now has a transport-facing coordinator seam rather than only a raw
  projection helper
- the Orbit panel can now switch to a server-backed room client when the
  canonical runtime is configured
- the Orbit room can now be switched onto the server-backed client path by
  configuration rather than only by manual test setup

## Why This Matters

- Packet 5 now has a real migration seam instead of a vague promise to "rewire
  the client later"
- the server and client models can now be compared concretely for product
  continuity

## Deterministic Proof

- `Tests/Features/Studio/OrbitServerRoomProjectionTests.swift`

Current proof covers:

- believable Orbit workspace projection from canonical room truth
- speaker and message-kind continuity across canonical authors
- replayed canonical events updating the projected room state
- server-backed connect and poll behavior updating the projected Orbit room state
- environment-gated factory construction for the server-backed room client
- configuration-based server-backed client enablement in Studio

## Honest Limit

The live macOS UI is not yet fully switched over to the canonical server path.

This slice proves the projection contract needed for that cutover without
pretending the whole migration is already complete.

## Packet 5 Judgment

Packet 5 has now started credibly because there is a concrete client-side
projection seam for server-backed room truth, not just an abstract migration
intent.
