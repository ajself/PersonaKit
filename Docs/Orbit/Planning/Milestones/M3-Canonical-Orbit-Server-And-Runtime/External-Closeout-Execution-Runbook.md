# External Closeout Execution Runbook

Status: Accepted
Milestone: `M3`
Owner: `samwise`
Last Updated: 2026-03-20

## Purpose

Define the exact execution path for post-`M3` hardening once a real CI lane or
operations-backed environment is available.

## Post-M3 Hardening Follow-Ups

After local-only `M3` closeout, the next optional confidence upgrades are:

1. operations-grade persistent-transport evidence
2. CI-backed or operations-backed live database proof

The repo should not invent new implementation scope for those follow-ups before
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

For a local-only rehearsal on one Mac before external capture, the same
`ORBIT_PG_*` environment can now run:

1. `make orbit-server-local`
2. Studio with `ORBIT_SERVER_GATEWAY_BASE_URL=http://127.0.0.1:8080`

That local server path is useful for hero-proof walkthroughs and now counts
toward the accepted local-only `M3` closeout packet when paired with the
env-backed `make orbit-m3-proof` lane on the same machine.

## Local-Only Closeout Commands

Use these commands for the accepted local-only `M3` closeout path:

1. `make orbit-m3-proof`
2. `make orbit-server-local`
3. Studio with `ORBIT_SERVER_GATEWAY_BASE_URL=http://127.0.0.1:8080`
4. `make closeout-local`

## External Hardening Commands

If stronger external proof is available later, use these commands in order:

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

## Hardening Update Rule

If `make orbit-m3-proof` later passes in CI or an operations-backed
environment, the stronger result should be reflected back into:

- `Canonical-Closeout-Packet.md`
- `Review-Packet.md`
- `Live-Postgres-Integration-Harness-Note.md`
- `Reliability-Review-Artifact.md`

Until that happens, the current packet should continue to describe that work as
post-`M3` hardening rather than as an exit blocker.
