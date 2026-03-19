# Stack Conformance Review Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `architectural-editor`
Review Ring: `samwise`, `studio-integration-coordinator`
Last Updated: 2026-03-18

## Purpose

Freeze the implementation posture for `M3` before server work begins so the lane
cannot drift into stack exploration.

## Approved `M3` Posture

- implementation language: `Swift`
- server framework: `Vapor`
- canonical transactional runtime store: `Postgres`
- deployment posture: self-hosted and private
- architecture posture: monolith-first
- contract-resolution posture: same-process PersonaKit resolver
- realtime posture: `WebSocket`-leaning, `SSE` acceptable only if it preserves
  the same recovery semantics more simply
- artifact storage posture: object-style abstraction with a simple self-hosted,
  filesystem/NAS-friendly first backend

## Explicit Non-Goals For This Packet

- no `Redis`, `Kafka`, `NATS`, separate queue tiers, or separate cache tiers
- no managed cloud or paid platform dependencies
- no microservice or service-mesh decomposition
- no mobile-client broadening

## Current Repo Readout

Current implementation has only started the smallest server-facing schema slice:

- `Package.swift` now includes a dedicated `OrbitServerRuntime` target for the
  phase-1 canonical schema contract
- current Orbit UI and proving-loop behavior still remain inside the macOS Studio
  feature set
- `Package.swift` still contains no conflicting backend or infrastructure stack
  choice
- no competing backend framework or database posture is being introduced yet

This is acceptable for Packet 1. The important review result is that no
conflicting stack direction has silently entered the repo before `M3` begins.

## Packet 1 Judgment

Packet 1 is strong enough to proceed because the repo is still cleanly inside the
approved posture: the first canonical schema target now exists, but no contrary
backend or infrastructure decision has drifted into the codebase.

The next implementation packet should add only the approved `Swift + Vapor +
Postgres` server direction.
