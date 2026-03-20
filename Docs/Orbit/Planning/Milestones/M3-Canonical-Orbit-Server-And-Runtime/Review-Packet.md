# M3 Review Packet

Status: Accepted
Milestone: `M3`
Owner: `samwise`
Last Updated: 2026-03-20

## Purpose

Package the current `M3` canonical-runtime backbone so AJ can review real
progress without reconstructing every packet from scratch.

## What `M3` Proves Today

- canonical ownership and stack posture are frozen explicitly
- the phase-1 canonical runtime schema and repository layer exist in code
- the Postgres runtime store has real bootstrap, append, and snapshot-loading
  entry points
- the first server-side room write path now exists through the runtime service
  and gateway edge
- the first server-driven collaborator response path now exists with activation
  and agent-run linkage
- replay, stale-client recovery, and transport-facing semantics exist in layered
  services and tests
- a live `Vapor` gateway seam now exists and remains thin over the replay/session
  services
- artifact storage now has a replaceable object-style abstraction with a
  filesystem backend
- the macOS room now has a client-side projection and replay-reduction seam from
  canonical server truth back into the accepted Orbit room model
- the Studio root now activates the server-backed Orbit room path whenever
  canonical gateway configuration is present
- the macOS room can now keep canonical transport traffic on one persistent
  gateway `WebSocket` connection and reconnect from its last replay cursor after
  transport loss or post-write recovery
- the live runtime-store harness now has a one-command local temp-`Postgres`
  proof path, and that path passed three consecutive mutation-ring runs
- the macOS room now has bounded repeated reconnect proof across cursor-based
  replay, degraded polling fallback, and retry back into persistent transport
- the bounded local transport confidence ring can now be rerun on demand with
  `make orbit-transport-proof`
- that bounded local transport confidence ring now has three consecutive
  successful local proof runs
- the same transport ring now has a dedicated local soak lane through
  `make orbit-transport-soak-local`
- that local soak lane has now passed ten consecutive local runs
- the current closeout bundle can now be executed in a pre-wired
  `ORBIT_PG_*` environment through `make orbit-m3-proof`
- on 2026-03-20, that env-backed `make orbit-m3-proof` lane passed locally on
  one Mac against a configured `ORBIT_PG_*` environment
- the current local M3 proof lanes can now be executed together with
  `make orbit-m3-proof-local`
- the required canonical closeout packet now exists as
  `Canonical-Closeout-Packet.md`

## Core Evidence

1. `Canonical-Runtime-Boundary-Audit-Note.md`
2. `Stack-Conformance-Review-Note.md`
3. `Schema-And-Event-Model-Note.md`
4. `Phase-1-Persistence-Bootstrap-Note.md`
5. `Canonical-Write-Path-Note.md`
6. `Canonical-Collaborator-Response-Path-Note.md`
7. `Realtime-Projection-Contract-Note.md`
8. `Realtime-Feed-And-Replay-Service-Note.md`
9. `Database-Backed-Replay-Loader-Note.md`
10. `Polling-Session-Recovery-Note.md`
11. `Transport-Adapter-Contract-Note.md`
12. `Vapor-Gateway-Contract-Note.md`
13. `Artifact-Storage-Boundary-Note.md`
14. `macOS-Cutover-Projection-Note.md`

## Review Artifacts

1. `Architecture-Review-Artifact.md`
2. `Reliability-Review-Artifact.md`
3. `Product-Continuity-Review-Artifact.md`
4. `Migration-Validation-Artifact.md`

## Closeout Artifact

- `Canonical-Closeout-Packet.md`
- `External-Closeout-Execution-Runbook.md`

## Post-M3 Hardening Notes

1. no operations-grade persistent transport soak or disconnect/reconnect
   evidence exists yet, even though the accepted local-only `M3` proof bar now
   has bounded reconnect/fallback/retry coverage plus a repeatable local soak lane
2. the current live database proof is local self-hosted evidence on one Mac,
   not CI-backed or operations-backed proof

## Judgment Frame

This packet is now strong enough to support full `M3` closeout under the local
self-hosted proof bar.
The remaining repo-side action is the ancestor-verifying `make closeout-local`
workflow.

## Review Ask

AJ should review whether the current backbone and closeout packet are now strong
enough to close `M3` locally without reopening the core architecture, replay,
or storage boundaries.

## AJ Review Outcome

- AJ approved this `M3` checkpoint as a trustworthy runtime-backbone review pass
- under the local-only closeout policy, `M3` may now close on the current proof
  packet and repository closeout workflow
