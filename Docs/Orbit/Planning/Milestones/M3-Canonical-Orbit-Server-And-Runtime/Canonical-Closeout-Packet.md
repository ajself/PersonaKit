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
- the env-backed `make orbit-m3-proof` lane has now passed locally on one Mac
  against a configured `ORBIT_PG_*` environment, including the bounded
  transport soak and three consecutive live mutation-ring runs
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

## Recorded Local Closeout Proof

The current accepted `M3` local closeout proof was captured on:

- commit `09fa445`
- date `2026-03-20`
- machine `MacBook Pro` (`MacBookPro18,2`, `Apple M1 Max`, `32 GB`)
- topology: one-machine self-hosted `Postgres` configured through `ORBIT_PG_*`
  plus the local `OrbitServer` gateway on `127.0.0.1:8080`

The final repository closeout step for this proof bar is `make closeout-local`
once the main worktree is clean enough for the ancestor-verifying workflow.

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
On 2026-03-20, this local path was exercised far enough to confirm
`make orbit-server-local` serves `GET /healthz` and that Studio can reopen the
gateway-backed realtime path without the earlier websocket registration crash
or HTTP date-format mismatch.

## Honest Limits

- the live macOS cutover still depends on canonical gateway configuration being
  present in the Studio environment
- the accepted `M3` exit bar is now local self-hosted proof on one Mac rather
  than CI-backed or operations-backed infrastructure proof
- the current transport confidence now includes a repeatable local soak lane,
  but stronger operations-grade evidence remains a post-`M3` hardening follow-up
- the current closeout bundle can now be executed in a pre-wired
  `ORBIT_PG_*` environment through `make orbit-m3-proof`, and that execution
  has now been captured locally on one Mac as the accepted milestone proof bar
- the repository still needs to complete `make closeout-local` before the
  branch-local proof packet becomes a finished repo-side closeout
- AJ closeout review should still treat this packet as the current closeout
  container, not as automatic proof that `M3` is already complete

## Current Disposition

- this artifact now fills the canonical closeout-packet slot required by
  `Evidence-And-Exit-Criteria.md`
- this packet now treats the local self-hosted proof bar as sufficient for `M3`
  closeout on one Mac
- the final repository closeout step remains `make closeout-local`
- `External-Closeout-Execution-Runbook.md` now defines post-`M3` hardening work
  rather than a remaining exit blocker
