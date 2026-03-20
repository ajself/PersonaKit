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
- `External-Closeout-Execution-Runbook.md`
- `Review-Packet.md`

## What Is Proven Now

- Orbit Server remains the authoritative runtime source for the current `M3`
  slice
- the macOS room now activates the server-backed client path directly from
  canonical gateway configuration without a separate feature gate
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
- `OrbitCanonicalCommandCenterBootstrapTests`
- `OrbitServerApplicationTests`
- `OrbitServerConfigurationTests`
- `OrbitPostgresRuntimeStoreIntegrationTests`
- `make orbit-transport-proof`
- `make orbit-transport-soak-local`
- `make orbit-m3-proof`
- `make orbit-live-db-proof-local`
- `make orbit-m3-proof-local`

## Local Server Hero Path

For a local-only `M3` rehearsal on one machine:

1. start a real local `Postgres` instance and export `ORBIT_PG_*`
2. run `make orbit-server-local`
3. launch Studio with `ORBIT_SERVER_GATEWAY_BASE_URL=http://127.0.0.1:8080`
4. exercise the Orbit panel over the live local gateway-backed room

This path is local evidence only, but it now uses the same gateway and runtime
stack that the `M3` closeout packet is reviewing.
The local server intentionally seeds the same command-center baseline language
used by `OrbitWorkspace.defaultWorkspace`, including `Orbit MVP Checkpoint`, so
the macOS projection stays aligned even though some older server-only fixtures
still use `Primary Orbit room` / `Orbit room` wording.

## Honest Limits

- the live macOS cutover still depends on canonical gateway configuration being
  present in the Studio environment
- the current transport confidence now includes a repeatable local soak lane,
  but it is still not operations-grade evidence
- the current closeout bundle can now be executed in a pre-wired
  `ORBIT_PG_*` environment through `make orbit-m3-proof`, but that execution
  has not yet been captured as CI-backed or operations-backed proof
- AJ closeout review should still treat this packet as the current closeout
  container, not as automatic proof that `M3` is already complete

## Current Disposition

- this artifact now fills the canonical closeout-packet slot required by
  `Evidence-And-Exit-Criteria.md`
- `External-Closeout-Execution-Runbook.md` now defines the exact remaining
  execution path for the env-backed proof lane
- the remaining `M3` blockers are now concentrated in external confidence work:
  operations-grade persistent-transport evidence and CI-backed or
  operations-backed live database proof
