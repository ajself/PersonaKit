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
3. canonical runtime boundary audit note
4. schema and event model note
5. phase-1 persistence bootstrap note
6. realtime projection contract note
7. realtime feed and replay service note
8. database-backed replay loader note
9. polling session recovery note
10. transport adapter contract note
11. artifact storage boundary note
12. macOS cutover projection note
13. migration cut plan
14. golden canonical flow
15. failure and recovery matrix
16. validation and review matrix
17. decision register
18. stack-conformance review artifact
19. architecture review artifact
20. reliability review artifact
21. product continuity review artifact
22. migration or cutover validation artifact
23. current migration validation artifact
24. current review packet for AJ
25. canonical closeout packet showing runtime, replay, and product continuity

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

Before full closeout, AJ may also review an in-progress packet containing:

- the current architecture review artifact
- the current reliability review artifact
- the current product continuity review artifact
- the current migration validation artifact
- the current `Review-Packet.md`

If that packet is accepted, `M3` may close and construction should pause rather
than rolling directly into `M4` or later milestones.
