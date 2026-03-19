# Transport Adapter Contract Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `studio-integration-coordinator`
Review Ring: `architectural-editor`, `studio-reliability-engineer`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Record the first transport-facing Packet 3 adapter that stays subordinate to the
feed and polling/session services.

## What Exists Now

- `OrbitPhase1RealtimeConnectRequest`
- `OrbitPhase1RealtimePollRequest`
- `OrbitPhase1RealtimeTransportResponse`
- `OrbitPhase1RealtimeTransportAdapter`

These now exist in `Sources/Features/OrbitServerRuntime/Phase1RealtimeTransportAdapter.swift`.

## Current Responsibilities

The transport adapter now does only four things:

1. accept a connect request and return one bootstrap transport response
2. accept a poll request and return replay, no-change, or resync transport
   responses
3. surface the updated session token with every transport response
4. stay thin by delegating state and recovery semantics to the polling/session
   service

## Why This Matters

- Packet 3 now has an actual transport-facing seam without forcing a `WebSocket`
  or `SSE` commitment too early
- future transports can map to one explicit request/response contract instead of
  reproducing replay logic separately

## Deterministic Proof

- `Tests/Features/OrbitServer/Phase1RealtimeTransportAdapterTests.swift`

Current proof covers:

- bootstrap transport response
- replay transport response with cursor advancement
- stale-session resync transport response

## Honest Limit

This slice still does not include a live network transport.

It provides the thin request/response layer that a later `WebSocket` or `SSE`
adapter should implement against.

## Packet 3 Judgment

Packet 3 now has a credible transport-facing seam because the transport layer can
stay thin and deterministic while the replay and recovery rules remain owned by
lower-level realtime services.
