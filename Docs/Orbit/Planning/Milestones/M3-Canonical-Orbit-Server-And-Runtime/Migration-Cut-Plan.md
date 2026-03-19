# Migration Cut Plan

Status: Accepted
Milestone: `M3`
Owner: `studio-integration-coordinator`
Last Updated: 2026-03-18

## Purpose

Define the ordered migration plan that moves Orbit from the `M2` local proving
loop to a canonical server-backed runtime without breaking product trust.

## Migration Principle

Do not migrate everything at once.

Migrate in cuts that preserve reviewability:

1. freeze ownership and runtime rules
2. stand up the canonical persistence slice
3. add gateway and realtime projection
4. add artifact storage abstraction
5. cut the macOS client over to server truth
6. prove replay, reconnect, and recovery behavior

Default migration posture:

- prefer seeded fresh server state or a re-proven server-backed flow
- do not default to historical import of local proving-loop data

## Cut 1. Freeze Ownership And Baseline Semantics

Primary outcome:

- one written contract exists for server-owned versus client-owned state

Work:

- freeze the canonical runtime contract
- freeze the approved `Swift + Vapor + Postgres` stack posture for the migration
- identify which `M2` semantics must remain unchanged
- identify any local-only behavior that must disappear after cutover

Done when:

- the implementation lane can point to one boundary contract instead of making
  ad hoc ownership decisions

## Cut 2. Build The Canonical Phase-1 Persistence Slice

Primary outcome:

- Orbit Server can durably store the minimum RFC-0002 phase-1 runtime records

Work:

- implement the minimum server-owned record set
- keep authored PersonaKit truth out of the schema
- preserve stable identifiers and relationships needed for traceability

Done when:

- the server can store and reconstruct the basic proving-loop runtime from
  durable records alone

## Cut 3. Add Gateway, Snapshot, And Realtime Projection

Primary outcome:

- the server becomes the front door for writes and the source for reconnect

Work:

- add write and read entry points for the `M3` runtime slice
- add snapshot entry points for client bootstrap and refresh
- add realtime events for durable transitions only

Done when:

- a client can submit work, receive projected updates, and recover by snapshot
  plus replay

## Cut 4. Add Basic Artifact Storage Abstraction

Primary outcome:

- the platform can reference large durable artifacts without binding product
  semantics to one storage backend

Work:

- freeze the object-style storage abstraction
- implement the smallest acceptable first backend
- verify the abstraction boundary stays separate from runtime transactional truth

Done when:

- artifact references can exist with a replaceable storage backing

## Cut 5. Cut The macOS Client Over

Primary outcome:

- the command-center UI runs over server-backed truth while preserving `M2`
  product quality

Work:

- move fetch and write paths to the server
- keep room semantics, attribution, and trace meaning stable
- ensure the client no longer acts as long-term owner of posts, threads,
  messages, or activations

Done when:

- a reviewer can say the room still feels like Orbit and the backend now clearly
  owns runtime truth

## Cut 6. Prove Replay, Reconnect, And Failure Recovery

Primary outcome:

- reliability claims are backed by evidence

Work:

- run reconnect tests
- run stale-client and replay-gap tests
- run durable-write failure tests
- run artifact-storage degradation tests where relevant

Done when:

- reliability reviewers can defend recovery behavior without caveats that weaken
  canonical trust

## Stop Conditions

Stop the migration if any of these become true:

- server and client ownership are still both needed after cut 5
- replay cannot recover a stale client deterministically
- trace semantics become weaker after server cutover
- the migration requires broader `M4` or later features to feel coherent
- the solution starts drifting into service-first decomposition for style reasons

## Quality Rule

This plan is only useful if it makes migration feel smaller, sharper, and harder
to rush.

If a lane can still interpret `M3` as "add backend stuff until it works," the
plan is not strong enough.
