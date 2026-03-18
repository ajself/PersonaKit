# M3 Canonical Orbit Server And Runtime Backbone

Status: Planned
Primary Owner: `studio-integration-coordinator`
Supporting Personas: `architectural-editor`, `senior-swiftui-engineer`, `studio-reliability-engineer`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Move Orbit from a local proving surface to one canonical collaboration runtime.

## Preconditions

- `M1` identity and activation rules are stable
- `M2` has produced a believable local command-center loop
- the platform team agrees that server migration is now worth the added
  complexity

## Scope Freeze

In scope:

- Orbit Server as canonical source of truth
- RFC-0002 phase-1 runtime records
- realtime event stream
- artifact-storage abstraction
- macOS client migration from local truth to server-backed truth

Out of scope:

- iPhone and iPad clients
- team and squad orchestration logic beyond what runtime migration needs
- memory review and memory reuse
- service decomposition for its own sake

## Required Inputs

- `Docs/Orbit/Planning/Orbit-Agentic-Milestone-Roadmap.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0006-Orbit-Multi-Client-Platform-Architecture.md`
- `M1` evidence package
- `M2` checkpoint evidence package

## Execution Packets

### Packet 1. Freeze The Canonical Runtime Contract

Outcome:

- one written contract exists for what moves from local-only truth to server
  truth

Work:

- define the minimum server-owned records
- define client-owned cached or derived state
- define migration constraints from the local checkpoint

Done when:

- the migration no longer depends on ad hoc decisions in implementation threads

### Packet 2. Build Phase-1 Runtime Persistence

Outcome:

- the server can persist the minimum collaboration runtime cleanly

Work:

- implement workspace, channel, workspace_persona, post, thread, message,
  post_participant, post_event, post_link, persona_activation, and agent_run
- keep authored PersonaKit truth out of the server runtime schema

Done when:

- the canonical backend can store and replay the same core loop proven in `M2`

### Packet 3. Add Realtime Delivery

Outcome:

- client updates reflect server-backed truth instead of a second local source

Work:

- define event stream shape
- implement subscriptions and replay entry points
- define failure behavior for dropped or stale clients

Done when:

- one client can reconnect and converge on canonical state deterministically

### Packet 4. Add Artifact Storage Abstraction

Outcome:

- posts and later workstreams have a durable artifact path without locking the
  system to one storage backend too early

Work:

- define object-style abstraction boundary
- keep the first implementation simple
- avoid coupling the first backend choice to the product model

Done when:

- artifacts can be referenced by stable identifiers and storage is replaceable

### Packet 5. Migrate The macOS Client

Outcome:

- the command-center remains believable while shifting to canonical server truth

Work:

- move read and write paths to the server
- preserve local UI quality from `M2`
- ensure activation trace semantics survive unchanged

Done when:

- the macOS client no longer acts as long-term owner of truth

### Packet 6. Prove Reliability And Replay

Outcome:

- the migration is trusted because replay, reconnect, and state convergence are
  tested

Work:

- run replay tests
- run reconnect and stale-state tests
- validate transaction and event ordering

Done when:

- the reliability and coverage owners can show canonical-state evidence instead
  of best-effort confidence

## Subagent Use Pattern

Safe subagents:

- schema and transaction design review
- realtime transport spike
- client migration review
- replay and reconnect validation

Avoid:

- parallel architecture changes that split canonical ownership across multiple
  services too early

## Evidence Package

- canonical runtime contract note
- schema and event model note
- replay and reconnect test results
- migration checklist for the macOS client
- architecture review artifact

## Stop Points

- stop if the server begins mutating PersonaKit authored truth
- stop if client behavior diverges from canonical runtime semantics
- stop before mobile-client work if replay and reconnect are not trusted

## Exit And Handoff

Exit when Orbit has one authoritative backend and the macOS client is a surface
over that truth.

Handoff forward to:

- `M4` and `M5` for richer collaboration behaviors
- `M11` and `M12` only after canonical runtime reliability is accepted
