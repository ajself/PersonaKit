# Reliability Review Artifact

Status: Accepted
Milestone: `M3`
Owner: `studio-reliability-engineer`
Grounding: `studio-reliability-engineer` + `apply-style`
Last Updated: 2026-03-20

## Decision

- result: `pass with notes`

## Review Readout

### Replay and resync

- pass: replay cursor ordering is deterministic
- pass: replay no-change, replay events, gap-detected resync, stale-client
  resync, and workspace mismatch are all explicit in code and tests
- pass: replay of the currently supported runtime mutation types is now covered
  through user, system, collaborator-response, and activation-failure replay
  tests on the macOS server-backed room path
- pass: transport-facing responses inherit recovery semantics from the lower
  replay/session layers instead of inventing them
- pass: persistent transport reconnect now resumes from the last canonical
  replay cursor instead of restarting from guessed local truth

### Write and bootstrap reliability

- pass: room bootstrap and message append both use explicit transactions in the
  repository layer
- pass: rollback-on-failure paths are tested for bootstrap

### Failure visibility

- pass: replay-gap and stale-client behavior now has explicit resync outcomes
- pass: the first live `Vapor` gateway now stays subordinate to the replay and
  session stack instead of inventing new recovery semantics
- pass: the persistent transport path now has focused proof for reconnect and
  fallback to the existing HTTP polling path when socket transport fails
- pass: the macOS transport loop now retries back into persistent transport
  after a bounded polling cooldown instead of degrading permanently after the
  first socket failure
- pass: the focused persistent-transport confidence ring can now be rerun with
  one command through `make orbit-transport-proof`
- pass: a longer local transport soak can now be rerun with
  `make orbit-transport-soak-local`

## Strongest Reliability Wins

1. Replay and reconnect semantics are now code-backed, not only promised.
2. Recovery no longer depends on local guesswork in the service layer.
3. Transaction boundaries exist where bootstrap and append semantics need them.
4. The live runtime-store harness now has a one-command local temp-`Postgres`
   proof path, and that path passed three consecutive mutation-ring runs.
5. Repeated local reconnect now has bounded proof across cursor carry-forward,
   degraded polling fallback, and retry back into persistent transport.
6. The bounded local transport proof can now be rerun on demand instead of
   living only in ad hoc test history, and it passed three consecutive runs via
   `make orbit-transport-proof`.
7. The same transport ring now has a dedicated local soak lane and passed ten
   consecutive local runs via `make orbit-transport-soak-local`.
8. The combined env-backed closeout lane now has one captured local run via
   `make orbit-m3-proof` on 2026-03-20 against a configured `ORBIT_PG_*`
   environment on one Mac.

## Strongest Remaining Reliability Notes

1. No operations-grade disconnect/reconnect proof exists yet, even though the
   focused transport ring now also has a repeatable local soak lane.
2. The current live database proof is repeated local temp-`Postgres` evidence
   plus one local env-backed `make orbit-m3-proof` capture on a single Mac,
   not CI-backed or operations-backed proof.

## Judgment

The current `M3` slice is reliability-reviewable and credibly addresses replay,
stale-client recovery, and transactional write discipline with notes.

Current disposition:

- this reliability readout supported AJ approval of the current `M3` checkpoint
