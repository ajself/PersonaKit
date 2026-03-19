# Failure And Recovery Matrix

Status: Accepted
Milestone: `M3`
Owner: `studio-reliability-engineer`
Last Updated: 2026-03-18

## Purpose

Define the expected failure and recovery behavior for the canonical runtime
backbone.

## Failure Matrix

| Failure case | Trigger | Expected system behavior | Persisted effect | Visible operator signal | Validation expectation |
| --- | --- | --- | --- | --- | --- |
| Gateway unavailable | client cannot reach the front door service | block durable writes, preserve only local draft or retry posture where allowed | no canonical state change finalized | visible unavailable or retry state | test proves no fake durable success |
| Database unavailable | server cannot persist transactional runtime state | fail the write, do not finalize runtime truth | no canonical runtime mutation | visible failure state, not silent success | test proves writes do not appear durable |
| Event emission fails after persistence | durable write succeeds but realtime projection fails | persisted state remains canonical; reconnect or refresh recovers missing projection | canonical records remain correct | client may lag, but refresh or replay restores state | test proves state can be reconstructed from durable records |
| Client stale after successful write | client misses one or more updates | refresh from snapshot and replay | no extra canonical mutation required | visible recovery without contradictory truth | test proves stale client converges deterministically |
| Replay gap detected | replay cursor or event history is incomplete | fetch fresh snapshot and resume from trusted point | canonical records remain authoritative | visible recovery or brief resync state | test proves no local guesswork |
| Artifact storage unavailable | large durable artifact operation fails | transactional runtime may still proceed where decoupled, artifact-heavy operation fails visibly | runtime truth preserved separately from artifact failure | visible artifact error or degraded attachment state | test proves storage degradation does not corrupt runtime truth |
| macOS cache diverges from server | local cached state is outdated or partial | server snapshot overrides stale cache | cache is replaced or reconciled | operator sees current canonical room state after refresh | test proves no local override of canonical truth |
| Contract linkage missing for response trace | response runtime path cannot preserve inspectable contract linkage | fail or mark incomplete before presenting attributable success | no successful canonical response path without trace linkage | visible blocked or incomplete trace state | test proves trace-less collaborator success is disallowed |

## Severity Rule

For `M3`, failures in persistence, replay, reconnect, or trace linkage are not
minor infrastructure blemishes.

They directly affect whether Orbit has a trustworthy canonical runtime.

## Recovery Design Rule

Recovery should favor:

- canonical snapshot recovery
- replay from trusted checkpoints
- explicit degraded states

Recovery should never favor:

- guessed local truth
- hidden silent fallback to client-owned state
- pretending success where durability is not proven
