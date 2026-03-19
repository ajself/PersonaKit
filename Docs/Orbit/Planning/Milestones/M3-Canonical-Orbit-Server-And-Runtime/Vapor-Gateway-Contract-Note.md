# Vapor Gateway Contract Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `studio-integration-coordinator`
Review Ring: `architectural-editor`, `studio-reliability-engineer`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Record the first live `Vapor` gateway slice for the canonical runtime.

## What Exists Now

- `OrbitGatewayConnectRequest`
- `OrbitGatewayPollRequest`
- `OrbitGatewayTransportResponse`
- `OrbitGatewayRoutes.register(on:transport:)`

These now exist in `Sources/Features/OrbitServerGateway/`.

## Current Responsibilities

The gateway slice now provides:

1. one live `Vapor` HTTP connect endpoint
2. one live `Vapor` HTTP poll endpoint
3. transport payloads that stay subordinate to the replay/session layers
4. no hidden replay or resync logic inside route handlers

## Why This Matters

- `M3` now has a real network-facing seam instead of runtime-only services
- the approved `Vapor` posture is now represented by live route code
- later `WebSocket` or `SSE` work can build on a gateway that already honors the
  replay/session contract instead of bypassing it

## Deterministic Proof

- `Tests/Features/OrbitServer/OrbitServerGatewayTests.swift`

Current proof covers:

- connect returns a bootstrap payload
- poll returns replay payloads
- poll returns stale-client resync payloads

## Honest Limit

This is still an HTTP request/response gateway slice, not a persistent
`WebSocket` or `SSE` transport.

That is acceptable for the current `M3` slice because it proves the live `Vapor`
gateway seam without prematurely locking the final transport choice.

## Packet 3 Judgment

Packet 3 is materially stronger because the runtime now has a real `Vapor`
gateway edge and that edge remains thin over the replay/session services.
