# Canonical Closeout Packet

Status: Accepted
Milestone: `M3`
Owner: `samwise`
Last Updated: 2026-03-20

## Purpose

Provide one current closeout-facing packet for `M3` that ties together runtime
ownership, replay and reconnect behavior, and product continuity without
pretending the remaining external proof gaps are already closed.

## Current Hero Proof

The current best `M3` hero proof is this sequence:

1. the macOS Orbit room boots from canonical server state through the
   server-backed client path
2. the canonical runtime persists the supported mutation ring through the same
   server-owned records and gateway seam
3. durable state is projected back to the client through the existing
   bootstrap-plus-poll contract, including the persistent gateway transport path
4. reconnect recovery resumes from the last canonical replay cursor rather than
   guessed local truth
5. the resulting room still reads as Orbit rather than as a generic remote log

## Packet Backbone

This closeout packet depends on the following artifacts as its current evidence
spine:

- `Golden-Canonical-Flow.md`
- `Failure-And-Recovery-Matrix.md`
- `Architecture-Review-Artifact.md`
- `Reliability-Review-Artifact.md`
- `Product-Continuity-Review-Artifact.md`
- `Migration-Validation-Artifact.md`
- `Live-Postgres-Integration-Harness-Note.md`
- `Review-Packet.md`

## What Is Proven Now

- Orbit Server remains the authoritative runtime source for the current `M3`
  slice
- the macOS room can use the server-backed client path through explicit
  environment-backed configuration
- replay for the currently supported runtime mutation ring is covered on the
  server-backed macOS path across user, system, collaborator-response, and
  activation-failure behavior
- persistent gateway transport can now reconnect from the last canonical replay
  cursor, fall back to polling when socket transport fails, and retry back into
  persistent transport after a bounded cooldown
- the live runtime-store proof now has a repeatable local temp-`Postgres` lane
- the current bounded local proof lanes can be rerun together with
  `make orbit-m3-proof-local`

## Concrete Proof Sources

- `OrbitServerBackedRoomCoordinatorTests`
- `OrbitServerBackedRoomTransportPolicyTests`
- `OrbitGatewayNetworkClientTests`
- `OrbitPostgresRuntimeStoreIntegrationTests`
- `make orbit-transport-proof`
- `make orbit-live-db-proof-local`
- `make orbit-m3-proof-local`

## Honest Limits

- the live macOS cutover is still env-gated through `ORBIT_SERVER_BACKED_ROOM=1`
- the current transport confidence is bounded local proof rather than
  operations-grade soak evidence
- the current live database proof is repeated local temp-`Postgres` evidence
  rather than CI-backed or operations-backed proof
- AJ closeout review should still treat this packet as the current closeout
  container, not as automatic proof that `M3` is already complete

## Current Disposition

- this artifact now fills the canonical closeout-packet slot required by
  `Evidence-And-Exit-Criteria.md`
- the remaining `M3` blockers are now concentrated in external confidence work:
  operations-grade persistent-transport evidence and CI-backed or
  operations-backed live database proof
