# Database-Backed Replay Loader Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `studio-integration-coordinator`
Review Ring: `architectural-editor`, `studio-reliability-engineer`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Record the Packet 3 slice that turns the transport-agnostic replay contract into
a database-backed loader and handshake adapter.

## What Exists Now

### Database-backed replay loader

- `Sources/Features/OrbitServerRuntime/OrbitPostgresRealtimeLoader.swift`
  now projects realtime envelopes from the canonical room snapshot loaded through
  the Postgres runtime store

Current responsibilities:

- load the current room snapshot for a subscription scope
- derive deterministic realtime envelopes from canonical room records
- derive a trusted replay cursor from the same durable state
- return replay batches by comparing the trusted cursor against the projected
  event stream

### Transport-neutral subscription adapter

- `Sources/Features/OrbitServerRuntime/Phase1RealtimeSubscriptionAdapter.swift`
  now provides one explicit handshake result model for:
  - bootstrap
  - replay
  - no-change
  - resync

## Why This Matters

- transport code can now stay thin because the replay semantics and stale-client
  recovery logic are already owned by a dedicated service layer
- Packet 3 now has a credible database-backed path from canonical room records to
  snapshot and replay behavior

## Deterministic Proof

- `Tests/Features/OrbitServer/OrbitPostgresRealtimeLoaderTests.swift`
- `Tests/Features/OrbitServer/Phase1RealtimeSubscriptionAdapterTests.swift`

Current proof covers:

- deterministic projection from canonical room state into ordered realtime events
- loader/feed-service consistency for bootstrap and replay
- bootstrap-only delivery when no cursor exists
- replay delivery when a valid cursor exists
- resync when the client cursor no longer matches the snapshot workspace

## Honest Limit

This slice still does not provide an actual `WebSocket` or `SSE` transport.

It now provides the database-backed semantics that such a transport must expose.

## Packet 3 Judgment

Packet 3 is materially stronger now because replay and reconnect semantics no
longer depend on in-memory-only loader closures; they have a real database-backed
projection path and a transport-neutral handshake adapter.
