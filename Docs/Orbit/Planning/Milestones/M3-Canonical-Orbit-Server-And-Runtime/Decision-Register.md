# M3 Decision Register

Status: Draft
Milestone: `M3`
Owner: `studio-integration-coordinator`
Last Updated: 2026-03-18

## Purpose

List the high-impact decisions that should be resolved or explicitly staged
before the canonical runtime migration proceeds too far.

This register should keep `M3` from turning into architecture-by-drift.

## Fixed Stack Posture Already Chosen

The following are no longer open for `M3` unless AJ explicitly reopens them:

- Orbit Server should be implemented in `Swift`
- Orbit Server should use `Vapor`
- canonical transactional runtime storage should use `Postgres`
- deployment should remain self-hosted and private by default
- the preferred reference topology is `Mac mini + Synology`, but it is not a
  hard requirement
- `M3` stays monolith-first
- PersonaKit contract resolution stays in the same server process for `M3`
- managed cloud services are out of scope for the baseline platform path
- extra infrastructure such as `Redis`, `Kafka`, `NATS`, separate queue systems,
  separate cache tiers, and vector or search databases are out of scope for the
  baseline canonical-runtime milestone

The decisions below are the remaining architecture and migration choices inside
that posture.

## Decision 1. Initial Transactional Runtime Store Shape

Question:

- what is the first relational persistence shape for the `M3` phase-1 runtime
  slice, and what stable identifier strategy should it use?

Why it matters:

- the server cannot become canonical without a durable, reconstructible runtime
  model

Resolution criteria:

- supports the minimum RFC-0002 phase-1 entities
- keeps stable identifiers and relationships clear
- does not prematurely overfit the final schema beyond `M3`

Recommended default:

- choose the simplest `Postgres`-backed relational shape that preserves
  reconstructibility and traceability for the phase-1 runtime slice

Decision owner:

- `architectural-editor` and `studio-integration-coordinator`, with AJ review

Must close before:

- cut 2 persistence work

Delay cost:

- high; migration logic becomes mushy if the persistence contract stays vague

Downstream impact:

- every `M3` packet after contract freeze

## Decision 2. Snapshot And Replay Boundary

Question:

- what constitutes a trusted snapshot and replay checkpoint for client recovery?

Why it matters:

- replay claims are weak if the system cannot define what a trustworthy recovery
  point is

Resolution criteria:

- stale clients can recover deterministically
- replay gaps can be detected and handled visibly
- the approach preserves canonical truth over client convenience

Recommended default:

- define one explicit snapshot bootstrap path and one explicit replay continuation
  strategy before the client cutover is treated as ready

Decision owner:

- `studio-reliability-engineer` and `architectural-editor`, with AJ review

Must close before:

- cut 3 gateway and replay design, and certainly before cut 5 client cutover

Delay cost:

- high; reconnect behavior drifts quickly without a frozen recovery model

Downstream impact:

- replay validation, reliability review, and mobile readiness later

## Decision 3. First Realtime Transport

Question:

- should the first realtime projection use `WebSocket` or `SSE`?

Why it matters:

- realtime delivery is part of the canonical runtime story, but the transport
  choice should support the semantics rather than distort them

Resolution criteria:

- supports the `M3` event categories that matter to the canonical runtime slice
- works cleanly with snapshot plus replay recovery
- does not force premature long-term protocol commitments
- stays operationally reasonable for a self-hosted `Vapor` backend

Recommended default:

- start from a `WebSocket`-first posture and allow `SSE` only if it better
  preserves simplicity without weakening recovery guarantees

Decision owner:

- `studio-integration-coordinator` and `studio-reliability-engineer`, with AJ
  review

Must close before:

- cut 3 realtime implementation

Delay cost:

- medium; transport ambiguity can stall the client cutover and replay design

Downstream impact:

- gateway and realtime cut, replay validation, macOS cutover

## Decision 4. Contract Snapshot And Trace Linkage Shape

Question:

- how should Orbit Server preserve inspectable linkage to resolved contract truth
  for participant responses without re-owning PersonaKit authored definitions?

Why it matters:

- `M3` must preserve `M1` trace semantics while moving runtime truth to the
  server

Resolution criteria:

- contract linkage remains inspectable for operator review
- the server can explain why a response happened
- PersonaKit remains the authored-definition authority
- the chosen approach does not mirror full authored contract state as if the
  server owned it

Recommended default:

- persist minimal activation-linked contract snapshot references or compact
  resolved snapshots; do not mirror PersonaKit authored definitions into Orbit
  Server runtime tables

Decision owner:

- `architectural-editor` and `studio-coverage-architect`, with AJ review

Must close before:

- participant-response migration and cut 5 client cutover

Delay cost:

- high; trace continuity becomes blurry quickly if this is left implicit

Downstream impact:

- response attribution, product continuity, and later collaboration milestones

## Decision 5. First Artifact Storage Backend

Question:

- what is the first concrete backend for the object-style artifact storage
  abstraction?

Why it matters:

- `M3` needs a real storage path without letting the first backend choice become
  the product architecture

Resolution criteria:

- keeps object-style abstraction clean
- fits the self-hosted near-term posture
- does not distort runtime transactional responsibilities

Recommended default:

- start from a self-hosted filesystem backend with a NAS-friendly direction and
  keep the abstraction honest and replaceable

Decision owner:

- `studio-integration-coordinator`, with architecture review and AJ approval

Must close before:

- cut 4 artifact-storage implementation

Delay cost:

- medium; not all `M3` work blocks on this immediately, but storage boundary
  drift grows if the decision stays fuzzy

Downstream impact:

- artifact attachment paths and later workstream or document outputs

## Decision 6. Migration Posture From `M2`

Question:

- should the canonical runtime begin from seeded fresh server state or from a
  re-proven server-backed flow, and where is historical import explicitly off the
  table?

Why it matters:

- product continuity matters, but an overcomplicated migration can distract from
  the real goal of establishing canonical truth

Resolution criteria:

- preserves reviewable continuity where it matters
- avoids long-lived dual truth
- keeps the migration auditable and time-bounded
- does not depend on importing local proving-loop history by default

Recommended default:

- prefer seeded fresh server state or a re-proven server-backed flow over
  historical import unless import is required to preserve a review-critical
  artifact lineage

Decision owner:

- AJ, informed by `samwise`, `studio-integration-coordinator`, and product review

Must close before:

- cut 5 client cutover and any claim of migration continuity

Delay cost:

- medium to high; a fuzzy posture encourages ad hoc transition logic

Downstream impact:

- macOS cutover, evidence packet, baseline trust for later milestones

## Decision 7. Temporary Dual-Write Or Transition Bridge

Question:

- is any temporary dual-write or local-to-server transition bridge allowed during
  cutover, and if so, under what explicit constraints?

Why it matters:

- the biggest `M3` risk is ending up with hidden dual truth during migration

Resolution criteria:

- any transition bridge is explicit, auditable, and time-bounded
- no long-lived user-invisible fallback remains after cutover
- the bridge can be removed as part of `M3` closeout

Recommended default:

- avoid dual-write entirely; if absolutely necessary, allow only a narrow,
  migration-only bridge with one named cutover deadline and explicit shutdown
  criteria

Decision owner:

- `studio-integration-coordinator` and `architectural-editor`, with AJ review

Must close before:

- cut 5 client cutover

Delay cost:

- medium to high; ambiguity here almost guarantees boundary drift

Downstream impact:

- macOS cutover, replay reliability, and `M3` exit criteria

## Rule For Unresolved Decisions

If one of these decisions is not closed, the affected packet should be marked
`blocked`, `needs-review`, or `prerequisite-required`, not `ready enough`.
