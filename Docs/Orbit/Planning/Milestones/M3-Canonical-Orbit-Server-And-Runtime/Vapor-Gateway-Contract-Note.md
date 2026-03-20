# Vapor Gateway Contract Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `studio-integration-coordinator`
Review Ring: `architectural-editor`, `studio-reliability-engineer`, `studio-coverage-architect`
Last Updated: 2026-03-20

## Purpose

Record the first live `Vapor` gateway slice for the canonical runtime.

## What Exists Now

- `OrbitGatewayConnectRequest`
- `OrbitGatewayPollRequest`
- `GET /api/orbit/realtime/socket`
- `OrbitGatewayTransportResponse`
- `OrbitGatewayRoutes.register(on:transport:)`

These now exist in `Sources/Features/OrbitServerGateway/`.

## Current Responsibilities

The gateway slice now provides:

1. one live `Vapor` HTTP connect endpoint
2. one live `Vapor` HTTP poll endpoint
3. one live persistent `WebSocket` endpoint that carries the same bootstrap and
   poll contract over a long-lived connection
4. transport payloads that stay subordinate to the replay/session layers
5. no hidden replay or resync logic inside route handlers

## Why This Matters

- `M3` now has a real network-facing seam instead of runtime-only services
- the approved `Vapor` posture is now represented by live route code
- later `WebSocket` or `SSE` work can build on a gateway that already honors the
  replay/session contract instead of bypassing it

## Deterministic Proof

- `Tests/Features/OrbitServer/OrbitServerGatewayTests.swift`
- `Tests/Features/Studio/OrbitGatewayNetworkClientTests.swift`
- `Tests/Features/Studio/OrbitServerBackedRoomCoordinatorTests.swift`

Current proof covers:

- connect returns a bootstrap payload
- poll returns replay payloads
- poll returns stale-client resync payloads
- the macOS gateway client can keep bootstrap and poll traffic on one
  persistent `WebSocket` connection
- the macOS room coordinator reconnects from the last canonical replay cursor
  after a post-write failure instead of cold-bootstrapping blindly
- the macOS transport loop can fall back to HTTP polling after socket failure
  and retry back into the persistent gateway path after a bounded cooldown

## Honest Limit

This slice now includes a live persistent `WebSocket` transport, but it still
uses the existing bootstrap-plus-poll contract over that socket instead of a
fully push-driven feed.

That is acceptable for the current `M3` slice because it proves a persistent
gateway channel and cursor-based reconnect behavior without prematurely locking
the final long-term feed shape.

## Packet 3 Judgment

Packet 3 is materially stronger because the runtime now has a real `Vapor`
gateway edge and that edge remains thin over the replay/session services.
