# Realtime Projection Contract Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `studio-integration-coordinator`
Review Ring: `architectural-editor`, `studio-reliability-engineer`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Freeze the first Packet 3 realtime contract before transport or subscription code
starts inventing its own semantics.

## Realtime Design Law

Realtime remains a projection of durable server state, not a second source of
truth.

That means Packet 3 should preserve three invariants:

1. events describe durable transitions
2. snapshots remain sufficient to reconstruct the current room state
3. replay is ordered from a trusted cursor, not local guesswork

## First Contract Types

- `OrbitPhase1RealtimeEventEnvelope`
- `OrbitPhase1ReplayCursor`
- `OrbitPhase1RealtimeSnapshot`

These now exist in `Sources/Features/OrbitServerRuntime/Phase1RealtimeContract.swift`.

## Initial Event Categories

- `post.created`
- `message.created`
- `thread.activity.updated`
- `participant.joined`
- `participant.failed`
- `activation.resolved`
- `activation.failed`

These match the phase-1 durable room and trace semantics frozen in Packet 1.

## Replay Rule

- replay cursor is workspace-scoped
- replay ordering is created-at first, id second
- same-timestamp replay must still converge deterministically

## Deterministic Proof

- `Tests/Features/OrbitServer/Phase1RealtimeContractTests.swift`

Current proof covers:

- event-category lock
- replay-cursor derivation from the latest event
- deterministic replay filtering and ordering

## Honest Limit

This slice does not yet provide transport, subscription management, or snapshot
delivery over `WebSocket` or `SSE`.

It freezes the semantics those later transport choices must obey.

## Packet 3 Judgment

Packet 3 has started credibly because the event and replay contract now exists in
code and tests before transport implementation begins.
