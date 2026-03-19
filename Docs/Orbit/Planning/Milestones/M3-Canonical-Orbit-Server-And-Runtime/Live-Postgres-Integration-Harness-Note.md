# Live Postgres Integration Harness Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `studio-coverage-architect`
Review Ring: `studio-reliability-engineer`, `architectural-editor`
Last Updated: 2026-03-18

## Purpose

Record the first live-database proof harness for the canonical runtime store.

## What Exists Now

- `OrbitPostgresRuntimeStoreIntegrationTests.liveRuntimeStoreRoundTripWhenDatabaseEnvironmentIsAvailable`

This now exists in `Tests/Features/OrbitServer/OrbitPostgresRuntimeStoreIntegrationTests.swift`.

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
4. realtime-event load through the real runtime store
5. room snapshot round-trip after the live append path

## Why This Matters

- `M3` closeout still requires live database proof, not only deterministic unit
  coverage
- the harness now exists so that proof can be executed without redesigning the
  runtime layer later

## Honest Limit

This harness now has one successful local proof run against a temporary local
`Postgres` instance.

What it still does not provide is repeatable CI-backed or long-lived operations
environment proof.

## Packet 6 Judgment

Packet 6 is stronger because live database proof is now a defined executable path
rather than a vague future intention.

Current disposition:

- the harness passed locally during this `M3` run against a temporary local
  `Postgres` instance
