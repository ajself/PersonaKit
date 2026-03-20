# Live Postgres Integration Harness Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `studio-coverage-architect`
Review Ring: `studio-reliability-engineer`, `architectural-editor`
Last Updated: 2026-03-20

## Purpose

Record the first live-database proof harness for the canonical runtime store.

## What Exists Now

- `OrbitPostgresRuntimeStoreIntegrationTests.liveRuntimeStoreRoundTripWhenDatabaseEnvironmentIsAvailable`
- `OrbitPostgresRuntimeStoreIntegrationTests.liveRuntimeStoreSupportsCurrentOrbitMutationRingWhenDatabaseEnvironmentIsAvailable`
- `Scripts/run-orbit-live-db-proof.sh`
- `make orbit-live-db-proof`
- `make orbit-live-db-proof-local`
- `make orbit-m3-proof`
- `make orbit-m3-proof-local`

These now exist in:

- `Tests/Features/OrbitServer/OrbitPostgresRuntimeStoreIntegrationTests.swift`
- `Scripts/run-orbit-live-db-proof.sh`
- `Makefile`

## Current Harness Scope

When the following environment variables are available:

- `ORBIT_PG_HOST`
- `ORBIT_PG_PORT` (optional, default `5432`)
- `ORBIT_PG_USER`
- `ORBIT_PG_PASSWORD`
- `ORBIT_PG_DATABASE`

the harness can prove:

1. phase-1 schema application against a live `Postgres` instance
2. room bootstrap through the real runtime store
3. canonical append through the real runtime store
4. live system-message persistence through the real runtime store
5. live collaborator-response persistence including activation, agent-run, and
   durable activation-event linkage
6. live activation-failure persistence including durable failure-event linkage
7. realtime-event load through the real runtime store
8. room snapshot round-trip after the live mutation ring

When the same environment is available, `make orbit-live-db-proof` can rerun
that harness repeatedly without changing the test code or hand-assembling the
command line each time.

When the same environment is available and the transport soak lane should be
executed in the same pass, `make orbit-m3-proof` can run both the transport
soak and the live-db proof harness together.

When no external database environment is pre-wired, `make orbit-live-db-proof-local`
can boot a temporary local `Postgres` cluster in `/tmp`, wire `ORBIT_PG_*`
automatically, and run the same proof harness against that local instance.

When the local transport proof is also needed in the same pass,
`make orbit-m3-proof-local` can run the bounded transport confidence ring and
the local temp-`Postgres` live-db harness together.

## Why This Matters

- `M3` closeout still requires live database proof, not only deterministic unit
  coverage
- the harness now exists so that proof can be executed without redesigning the
  runtime layer later

## Honest Limit

This harness now has a one-command repeatable local proof path against a
temporary local `Postgres` instance, and that path has passed three consecutive
runs for the full currently supported mutation ring.

What it still does not provide is repeatable CI-backed or long-lived operations
environment proof.

## Packet 6 Judgment

Packet 6 is stronger because live database proof is now a defined executable path
rather than a vague future intention.

Current disposition:

- `make orbit-live-db-proof-local` passed locally during this `M3` run against
  a temporary local `Postgres` instance across three consecutive proof runs
