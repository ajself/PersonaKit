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

## Strongest Reliability Wins

1. Replay and reconnect semantics are now code-backed, not only promised.
2. Recovery no longer depends on local guesswork in the service layer.
3. Transaction boundaries exist where bootstrap and append semantics need them.
4. The live runtime-store harness now has a one-command local temp-`Postgres`
   proof path, and that path passed three consecutive mutation-ring runs.

## Strongest Remaining Reliability Notes

1. No long-running persistent transport soak or operations-grade
   disconnect/reconnect proof exists yet.
2. The current live database proof is local-run evidence, not CI-backed or
   operations-backed proof.

## Judgment

The current `M3` slice is reliability-reviewable and credibly addresses replay,
stale-client recovery, and transactional write discipline with notes.

Current disposition:

- this reliability readout supported AJ approval of the current `M3` checkpoint
