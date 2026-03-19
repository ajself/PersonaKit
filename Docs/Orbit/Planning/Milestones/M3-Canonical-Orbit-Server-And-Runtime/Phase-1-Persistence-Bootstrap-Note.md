# Phase-1 Persistence Bootstrap Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `studio-integration-coordinator`
Review Ring: `architectural-editor`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Record the first concrete Packet 2 persistence slice for the canonical runtime.

## What Exists Now

### Raw-SQL-first schema contract

- `Sources/Features/OrbitServerRuntime/Phase1RuntimeSchema.swift`
  freezes the minimum canonical table set and initial realtime categories in code

### Postgres migration runner

- `Sources/Features/OrbitServerRuntime/OrbitPostgresRuntimeStore.swift`
  provides:
  - Postgres configuration for the raw-SQL runtime store
  - a phase-1 schema migrator over ordered SQL statements
  - a `PostgresClient`-backed application path for the schema bootstrap
  - live room bootstrap, append, and room-snapshot loading entry points over the
    same runtime store

### First repository layer

- `Sources/Features/OrbitServerRuntime/Phase1RuntimeRecords.swift`
  defines the first canonical record shapes for workspace, channel, post, thread,
  message, workspace persona, post participant, post event, persona activation,
  and agent run persistence
- `Sources/Features/OrbitServerRuntime/Phase1RuntimeRepository.swift`
  provides raw-SQL repository behavior for:
  - room bootstrap inside an explicit transaction across the phase-1 canonical
    runtime set
  - message append plus durable realtime-event write and thread-activity touch
    inside an explicit transaction
  - room snapshot query shape
  - participant roster query shape
  - post-event query shape
  - activation/run query shape
  - thread message replay query shape

## Why This Slice Matters

- it proves Packet 2 is now implementation work, not only planning text
- it keeps the first persistence layer close to the canonical runtime contract
- it avoids ORM drift while the phase-1 schema is still being frozen

## Deterministic Proof

- `Tests/Features/OrbitServer/Phase1RuntimeSchemaTests.swift`
- `Tests/Features/OrbitServer/Phase1RuntimeRepositoryTests.swift`

Current proof covers:

- canonical table coverage
- authored-truth table exclusion
- ordered migration execution
- transaction-wrapped room bootstrap
- rollback on failed bootstrap write
- transaction-wrapped message append, realtime-event write, and thread activity
  update
- canonical snapshot query shape
- participant roster replay ordering
- post-event replay ordering
- activation-to-run linkage query shape
- message replay query ordering

Current live store shape covers:

- bootstrapping one canonical room into `Postgres`
- appending a durable message with thread-activity touch
- loading one room snapshot with workspace, channel, post, thread, workspace
  personas, participants, events, activations, runs, and messages

## Honest Limit

This slice still does not prove end-to-end reads and writes against a running
`Postgres` instance in CI.

It now proves the live runtime-store API shape and the raw-SQL repository
contract needed for that next step.

## Packet 2 Judgment

Packet 2 has now started in a credible way: the canonical schema, migration
runner, and first repository layer exist and are testable.
