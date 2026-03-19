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

This now exists in `Sources/Features/Studio/UI/Orbit/OrbitServerRoomProjection.swift`.

## Current Responsibility

The projection layer now proves that a canonical server-backed room snapshot can
be translated into the same Orbit room model the macOS command center expects.

Current preserved semantics:

- workspace name and room purpose
- founding roster with AJ, Samwise, and ProdDoc
- one active room thread
- direct user and participant response message meaning
- lightweight-meeting interaction mode when multiple workspace personas are
  present in the room

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

## Honest Limit

The live macOS UI is not yet fully switched over to the canonical server path.

This slice proves the projection contract needed for that cutover without
pretending the whole migration is already complete.

## Packet 5 Judgment

Packet 5 has now started credibly because there is a concrete client-side
projection seam for server-backed room truth, not just an abstract migration
intent.
