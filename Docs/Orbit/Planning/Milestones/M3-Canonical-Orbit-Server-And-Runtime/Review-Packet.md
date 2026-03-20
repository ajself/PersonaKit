# M3 Review Packet

Status: Accepted
Milestone: `M3`
Owner: `samwise`
Last Updated: 2026-03-19

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
- the Studio root can now enable the server-backed Orbit room path through
  explicit runtime configuration
- the macOS room can now keep canonical transport traffic on one persistent
  gateway `WebSocket` connection and reconnect from its last replay cursor after
  transport loss or post-write recovery

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

## Honest Remaining Gaps

1. no long-running persistent transport soak or operations-grade
   disconnect/reconnect evidence exists yet
2. the current live database proof is local-run evidence rather than CI-backed or
   operations-backed proof
3. the closeout packet and hero-proof evidence still need a refreshed readout
   now that replay coverage for the currently supported runtime mutation types
   is in place

## Judgment Frame

This packet is ready for AJ review as a serious `M3` progress checkpoint.

It is not yet a closeout packet for full `M3` acceptance.

## Review Ask

AJ should review whether the current backbone is strong enough to continue into
persistent-transport confidence, repeatable live-database proof, and final
closeout evidence work without reopening the core architecture, replay, or
storage boundaries.

## AJ Review Outcome

- AJ approved this `M3` checkpoint as a trustworthy runtime-backbone review pass
- `M3` remains open for full closeout until persistent-transport confidence,
  repeatable live database proof, and refreshed macOS closeout evidence are
  complete
