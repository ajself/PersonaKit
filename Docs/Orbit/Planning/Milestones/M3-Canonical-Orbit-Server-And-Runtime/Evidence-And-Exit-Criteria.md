# M3 Evidence And Exit Criteria

Status: Accepted
Milestone: `M3`
Owner: `studio-integration-coordinator`
Last Updated: 2026-03-18

## Purpose

Define the proof package required to close `M3` honestly.

## Hero Proof

`M3` should produce one convincing canonical-runtime proof that includes all of
these in one reviewable sequence:

- a macOS room loaded from Orbit Server rather than local canonical state
- one message or response flow persisted through server-owned runtime records
- one operator-visible trace path that remains semantically faithful to `M1` and
  `M2`
- one realtime projection of durable state
- one reconnect or stale-client recovery by snapshot plus replay

If that sequence is weak, confusing, or under-evidenced, `M3` is not done.

## Required Artifacts

1. quality bar for canonical runtime migration
2. canonical runtime contract
3. migration cut plan
4. golden canonical flow
5. failure and recovery matrix
6. validation and review matrix
7. decision register
8. stack-conformance review artifact
9. architecture review artifact
10. reliability review artifact
11. product continuity review artifact
12. migration or cutover validation artifact
13. canonical closeout packet showing runtime, replay, and product continuity

## Exit Checklist

`M3` exits only when all of these are true:

- Orbit Server is the one authoritative runtime source for the `M3` slice
- the macOS client reads and writes through server paths for the canonical slice
- no long-term dual truth remains between client-local and server runtime state
- the minimum RFC-0002 phase-1 runtime records are durably represented on the
  server
- the implementation remains inside the approved `Swift + Vapor + Postgres`,
  self-hosted, monolith-first posture
- realtime reflects durable state rather than becoming a second truth source
- reconnect and replay behavior are deterministic enough to defend
- product semantics from `M1` and `M2` survive the migration unchanged in
  meaning
- PersonaKit authored truth remains outside Orbit Server runtime ownership
- architecture review passes
- reliability review passes
- product continuity review passes
- coverage and closeout review pass
- the implementation stop line is honored: construction pauses after `M3` until
  AJ explicitly restarts it

## Residual Open Dependencies

- `M3` still depends on `M1` and `M2` being strong enough baselines to preserve
- later milestones such as `M4`, `M5`, `M11`, and `M12` should remain blocked on
  `M3` if replay and canonical truth are not convincingly proven

Those are real dependencies and should stay visible.

## Not Enough To Exit

These do not count as success:

- a backend service exists
- the macOS client can talk to the server but still owns key runtime truth
- the backend works only by drifting away from the approved stack posture
- realtime appears to work in demos but replay and stale-state recovery are weak
- the migration preserves data shape but weakens product semantics
- the branch is described as `review-ready` without stack-conformance,
  architecture, and reliability evidence

## Review Gate

Before `M4`, `M5`, or later mobile milestones are allowed to rely on this as a
trusted baseline, AJ should be able to review a small, convincing packet
containing:

- the canonical runtime contract
- the golden canonical flow
- the failure and recovery matrix
- the stack-conformance review artifact
- the architecture review artifact
- the reliability and replay validation results
- the product continuity review artifact
- the migration continuity summary for the macOS room

If that packet does not feel sharp, `M3` should remain open.

If that packet is accepted, `M3` may close and construction should pause rather
than rolling directly into `M4` or later milestones.
