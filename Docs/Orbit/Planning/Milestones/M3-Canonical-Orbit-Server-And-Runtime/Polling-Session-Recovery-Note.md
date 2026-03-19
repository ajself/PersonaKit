# Polling Session Recovery Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `studio-reliability-engineer`
Review Ring: `studio-integration-coordinator`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Record the Packet 3 slice that turns the transport-neutral replay semantics into
a stale-client-aware polling/session layer.

## What Exists Now

- `OrbitPhase1RealtimeSession`
- `OrbitPhase1RealtimeSessionDelivery`
- `OrbitPhase1RealtimePollingSessionService`

These now exist in `Sources/Features/OrbitServerRuntime/Phase1RealtimePollingSession.swift`.

## Current Responsibilities

The polling/session layer now provides:

1. connect
   - bootstrap when no client cursor exists
2. poll
   - replay new events when the cursor is still valid
   - return no-change when nothing new is available
   - force resync when the client is stale beyond the configured threshold
3. stale detection
   - explicit `requiresResync` check before transport code invents its own retry
     rules

## Why This Matters

- Packet 3 now has an explicit recovery rule for stale or dropped clients
- transport code can remain thin because session semantics already decide when to
  replay versus when to resync
- this is the first slice that directly addresses the `Client stale after
  successful write` and `Replay gap detected` rows in the failure matrix

## Deterministic Proof

- `Tests/Features/OrbitServer/Phase1RealtimePollingSessionTests.swift`

Current proof covers:

- bootstrap session creation
- replay with cursor advancement
- no-change polling
- stale-client resync path

## Honest Limit

This still does not provide a live long-poll, `WebSocket`, or `SSE` transport.

It provides the session and recovery semantics that those later transports must
follow.

## Packet 3 Judgment

Packet 3 is now substantially stronger because stale-client recovery is explicit
in code and tests instead of remaining only a failure-matrix promise.
