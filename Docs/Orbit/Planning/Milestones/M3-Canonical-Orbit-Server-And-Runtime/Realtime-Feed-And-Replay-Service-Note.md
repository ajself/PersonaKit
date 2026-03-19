# Realtime Feed And Replay Service Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `studio-integration-coordinator`
Review Ring: `architectural-editor`, `studio-reliability-engineer`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Record the first transport-agnostic Packet 3 feed service over the phase-1 event
and replay contract.

## What Exists Now

- `OrbitPhase1RealtimeSubscriptionScope`
- `OrbitPhase1RealtimeReplayBatch`
- `OrbitPhase1RealtimeReplayResult`
- `OrbitPhase1RealtimeFeedService`

These now exist in `Sources/Features/OrbitServerRuntime/Phase1RealtimeFeedService.swift`.

## Current Service Responsibilities

The service now provides:

1. subscription bootstrap from a room snapshot
2. replay from a trusted workspace-scoped cursor
3. deterministic ordering of replay events through the existing contract helper
4. explicit resync decisions for:
   - replay gaps
   - workspace mismatch
   - inconsistent replay batches

## Why This Matters

- transport code now has one place to get snapshot/replay behavior without
  inventing semantics inside `WebSocket` or `SSE`
- failure behavior for dropped or stale clients is now explicit enough to test
- replay no-change, replay-events, and resync outcomes are separated cleanly for
  later transport adaptation

## Deterministic Proof

- `Tests/Features/OrbitServer/Phase1RealtimeFeedServiceTests.swift`

Current proof covers:

- bootstrap returning the scoped snapshot
- replay returning ordered new events and the next cursor
- replay returning `noChange` when nothing new exists
- gap-detected resync behavior
- workspace-mismatch and inconsistent-batch resync behavior

## Honest Limit

This slice is still transport-agnostic and uses loader closures rather than a
live subscription server.

That is intentional: Packet 3 should freeze feed semantics before transport code
hardens around the wrong behavior.

## Packet 3 Judgment

Packet 3 is now materially underway because snapshot/replay entry points and
stale-client recovery behavior exist in code and deterministic tests, not only in
planning prose.
