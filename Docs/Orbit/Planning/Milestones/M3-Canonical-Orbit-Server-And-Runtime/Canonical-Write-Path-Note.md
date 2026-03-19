# Canonical Write Path Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `studio-integration-coordinator`
Review Ring: `architectural-editor`, `studio-reliability-engineer`, `senior-swiftui-engineer`
Last Updated: 2026-03-18

## Purpose

Record the first live canonical write-path slice for the server-backed room.

## What Exists Now

- `OrbitPhase1RoomWriteService`
- `OrbitGatewayAppendMessageRequest`
- `OrbitGatewayAppendMessageResponse`
- `POST /api/orbit/room/messages`

These now exist across:

- `Sources/Features/OrbitServerRuntime/Phase1RoomWriteService.swift`
- `Sources/Features/OrbitServerGateway/OrbitGatewayPayloads.swift`
- `Sources/Features/OrbitServerGateway/OrbitGatewayRoutes.swift`

## Current Responsibilities

The write path now provides:

1. load the canonical room by workspace and channel scope
2. append one user-authored message into server-owned room truth
3. emit durable realtime events for the append path
4. return a canonical post/thread summary for the write result

## Why This Matters

- `M3` now has a real server write seam, not only read/replay semantics
- the event log is no longer purely a bootstrap concern; message append now writes
  durable realtime events by default
- the gateway now includes both read-side and write-side room behavior

## Deterministic Proof

- `Tests/Features/OrbitServer/Phase1RoomWriteServiceTests.swift`
- `Tests/Features/OrbitServer/OrbitServerGatewayTests.swift`

Current proof covers:

- missing-room failure behavior
- canonical message creation
- durable realtime-event generation for append
- live gateway write request/response behavior

## Honest Limit

This slice still does not prove a live database-backed end-to-end write against a
running `Postgres` instance.

It proves the canonical write contract and the live gateway seam that such a
database-backed write must travel through.

## Packet Judgment

The canonical write path is now materially underway because the room can be
written through a real server-side service and gateway edge, not only replayed.
