# External Closeout Execution Runbook

Status: Accepted
Milestone: `M3`
Owner: `samwise`
Last Updated: 2026-03-20

## Purpose

Define the exact execution path for the remaining external `M3` blockers once a
real CI lane or operations-backed environment is available.

## Remaining External Blockers

`M3` still needs:

1. operations-grade persistent-transport evidence
2. CI-backed or operations-backed live database proof

The repo should not invent new implementation scope for those blockers before
running the proof lanes that already exist.

## Required Environment

For the env-backed proof lane, provide:

- `ORBIT_PG_HOST`
- `ORBIT_PG_PORT` if not using the default `5432`
- `ORBIT_PG_USER`
- `ORBIT_PG_PASSWORD`
- `ORBIT_PG_DATABASE`

The same environment should also be able to run the focused macOS transport
tests used by the transport soak lane.

## Canonical Execution Commands

Use these commands in order:

1. `make orbit-m3-proof`
2. if a local branch-local sanity pass is also needed, `make orbit-m3-proof-local`

`make orbit-m3-proof` is the primary closeout command because it runs:

- the transport soak lane through `make orbit-transport-soak-local`
- the live database proof lane through `make orbit-live-db-proof`

## Expected Success Shape

The execution should show all of the following:

- the transport soak lane passes without reconnect or fallback drift
- the live runtime-store proof passes against a real configured `Postgres`
  environment
- the combined bundle finishes without changing code or hand-editing commands

## Closeout Update Rule

If `make orbit-m3-proof` passes in CI or an operations-backed environment, the
result should be reflected back into:

- `Canonical-Closeout-Packet.md`
- `Review-Packet.md`
- `Live-Postgres-Integration-Harness-Note.md`
- `Reliability-Review-Artifact.md`

Until that happens, the current packet should continue to describe those
blockers as open.
