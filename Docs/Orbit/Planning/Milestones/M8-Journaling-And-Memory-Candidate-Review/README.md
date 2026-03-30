# M8 Journaling And Memory Candidate Review

Status: Closed for M8 Closeout
Primary Owner: `orbit-memory-gardener`
Supporting Personas: `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-30

## Purpose

Turn accepted collaboration activity into reviewed learning proposals without
automatic behavioral drift.

## Quality Standard

`M8` is not successful because raw collaboration history can technically be
compressed into a journal or candidate.

`M8` is successful only when the first slice stays:

- explicit about which accepted `M7` artifacts may seed later journaling
- governed enough that candidate memory remains a reviewed proposal layer
  rather than implied learning
- honest about owner availability without treating the new persona as blanket
  approval for later `M8` execution

The bare minimum is not a milestone win.

`M8` planning started with one bounded intake-boundary packet from the accepted
local `M7` dossier. Later journal, candidate, and review packets must still
start from that boundary instead of broadening from owner availability alone.

`M8` is closed for first-pass journaling, candidate-staging, and review-workflow
planning.
The current dossier evidence is sufficient to hand forward to `M9` scope work
without reopening the accepted `M7` or `M8` packet set.

## Current Milestone Position

- the accepted `M7` closeout dossier is the frozen local baseline for `M8`
  planning unless later repo-local evidence forces an explicit reopen
- accepted `M7-P1` through `M7-P5` remain authoritative for source continuity,
  workstream lifecycle, returned status, artifact source of truth, and explicit
  closeout
- `M8-P1` is accepted: the first-pass `M7` to `M8` intake boundary is now
  frozen as the planning baseline for the milestone
- `orbit-memory-gardener` now exists in PersonaKit through hiring review
  `PHR-0010` plus candidate review and delivery sessions, so the missing-owner
  prerequisite is resolved
- `M8-P2` is accepted: the first `journal_entry` and `journal_source` boundary
  is now frozen from the accepted `M8-P1` intake bundle, including the
  first-slice entry-type posture and normal source discipline
- `M8-P3` is accepted: the first `memory_candidate` source, staging, and
  proposed-scope policy is now frozen from the accepted journaling boundary,
  including journal-first primary-source discipline for first-slice candidate
  staging
- `M8-P4` is accepted: the first-pass `memory_review` action semantics and
  reviewer posture are now frozen from the accepted candidate-staging
  boundary, including explicit operator authority over trusted memory
- `M8-P5` is accepted: the first-pass memory-review workflow and operator
  inspection surface are now frozen from the accepted candidate-staging and
  review-action boundaries without freezing approved memory, retrieval, or
  later governance actions
- `M8` milestone closeout is accepted on the prepared dossier
- later work beyond accepted `M8-P5` remains intentionally unfrozen and must
  still start from the accepted `M8-P1`, `M8-P2`, `M8-P3`, and `M8-P4`
  boundaries rather than improvisation

## File Map

- `README.md`
  milestone overview, packet order, and top-level guardrails
- `Packet-01-Freeze-M7-To-Journal-Intake-Boundary.md`
  first bounded planning packet for `M8-P1`
- `Packet-02-Freeze-Journal-Entry-And-Source-Policy.md`
  accepted journaling-boundary packet for `M8-P2`
- `Packet-03-Freeze-Memory-Candidate-Source-And-Scope-Policy.md`
  accepted candidate-source and candidate-scope packet for `M8-P3`
- `Packet-04-Freeze-Memory-Review-Action-Semantics.md`
  accepted review-action packet for `M8-P4`
- `Packet-05-Freeze-Memory-Review-Workflow-And-Inspection-Surface.md`
  accepted workflow and operator-inspection packet for `M8-P5`
- `Milestone-Closeout-Review-Artifact.md`
  AJ-facing milestone closeout note for the full accepted `M8` dossier

## Preconditions

- the accepted `M7` README and milestone closeout artifact remain the
  authoritative handoff source for this planning pass
- accepted `M7-P1` through `M7-P5` remain frozen and must not be reopened
  implicitly
- `RFC-0002` remains the data-model floor for `journal_entry`,
  `journal_source`, `memory_candidate`, and `memory_review`
- `RFC-0005` remains the lifecycle and governance authority for journaling,
  candidate review, and later approved-memory boundaries
- `RFC-0004` remains the authority for follow-up continuity and coordinator
  trigger points, not memory governance or workstream execution
- `orbit-memory-gardener` is now available as the required owner, but that
  owner availability does not bypass the accepted `M8-P1`, `M8-P2`, `M8-P3`,
  `M8-P4`, and accepted `M8-P5` planning boundaries

## Scope Freeze

In scope:

- `M8` planning only from the frozen `M7` baseline
- first-pass intake eligibility from accepted `M7` workstream evidence
- the accepted journaling, candidate-staging, and review-action boundaries from
  `M8-P2` through `M8-P4`
- the accepted first-pass review workflow and operator inspection requirements
  from `M8-P5`
- the resolved-owner posture and stop points that prevent
  `orbit-memory-gardener` from being treated as blanket execution approval

Out of scope:

- journal generation
- runtime candidate creation, review execution, or automated governance
- approved memory influencing activations
- scope-promotion or scope-demotion design, contradiction handling,
  supersession, or linked-memory action design
- persona creation, runtime work, UI work, schema work, or implementation

## Required Inputs

- `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/README.md`
- `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/Milestone-Closeout-Review-Artifact.md`
- `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/Packet-01-Freeze-Workstream-Ownership-And-Contract.md`
- `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/Packet-02-Freeze-Workstream-Runtime-Model.md`
- `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/Packet-03-Freeze-Handoff-From-Discussion-To-Execution.md`
- `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/Packet-04-Freeze-Progress-And-Artifact-Return.md`
- `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/Packet-05-Prove-Lane-Discipline-And-Review-Gates.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`

## Execution Packets

### Packet 1. Freeze M7-To-Journal Intake Boundary

Outcome:

- accepted `M7` workstream evidence maps to one explicit first-pass intake
  boundary for later journaling work

Work:

- define which accepted `M7` surfaces count as normal first-slice journal input
- define the minimum handoff bundle from `M7` into later `M8` packets
- record the resolved-owner posture and explicit stop points that prevent
  hidden autonomy or premature implementation

Done when:

- later `M8` work can start from an explicit intake boundary without
  re-litigating owner coverage or broadening beyond the accepted planning
  baseline

Status:

- accepted

Later `M8` packets remain intentionally unfrozen; owner coverage now exists,
but future packet work must still preserve the accepted `M8-P1` intake
boundary explicitly.

### Packet 2. Freeze Journal Entry And Source Policy

Outcome:

- accepted `M8-P1` intake bundles map to one explicit first-slice journaling
  contract before any memory-candidate or review workflow is frozen

Work:

- define the minimum `journal_entry` expectations for workstream-derived
  reflection from accepted `M7` return surfaces
- define the normal `journal_source` lineage policy from the accepted `M8-P1`
  intake bundle
- preserve journals as the normal first compression layer while deferring
  cadence, prompts, candidate staging, review actions, and implementation

Done when:

- later `M8` candidate workflow packets can rely on one explicit journal
  boundary without re-litigating source discipline or slipping back into raw
  runtime ingestion

Status:

- accepted

### Packet 3. Freeze Memory Candidate Source And Scope Policy

Outcome:

- accepted journals and explicit structured artifacts map to one first-pass
  `memory_candidate` boundary before any `memory_review` action semantics are
  frozen

Work:

- define the normal first-slice `memory_candidate` source discipline from
  accepted journals plus explicit structured artifacts allowed by the RFC floor
- define the first-pass proposed-scope posture for candidate staging without
  approving or retrieving memory
- preserve candidates as reviewed proposals while deferring review decisions,
  approval flow, governance execution, and implementation

Done when:

- later `M8` review-workflow packets can rely on one explicit candidate-staging
  boundary without re-litigating journal dependence, candidate scope posture,
  or raw-runtime exceptions

Status:

- accepted

### Packet 4. Freeze Memory Review Action Semantics

Outcome:

- accepted `memory_candidate` proposals map to one first-pass
  `memory_review` action floor before any approved-memory behavior is frozen

Work:

- define the first-pass semantics for `approve`, `reject`, `archive`, and
  `defer`
- define the reviewer posture for `operator`, `steward`, and `system` review
  records without bypassing operator authority
- preserve review as governance while deferring approved-memory materialization,
  scope-promotion semantics, tooling, and implementation

Done when:

- later `M8` workflow packets can rely on one explicit review-action boundary
  without re-litigating operator authority, first-pass action meanings, or the
  separation between review and approved memory

Status:

- accepted

### Packet 5. Freeze Memory Review Workflow And Inspection Surface

Outcome:

- accepted candidate staging and the accepted `memory_review` action floor map
  to one first-pass review workflow and operator inspection contract before any
  approved-memory behavior is frozen

Work:

- define the first-pass path from staged candidate into operator-visible review
  without reopening accepted source or action semantics
- define the minimum inspection surface for candidate summary, proposed scope,
  provenance, and review context without requiring raw runtime reconstruction
  or UI design
- preserve review as governance while deferring approved memory, retrieval,
  scope-change actions, contradiction handling, linked-memory actions, tooling,
  and implementation

Done when:

- `M8` can be judged as having one explicit review workflow boundary without
  re-litigating operator inspection needs, queue posture, or the separation
  between review and approved memory

Status:

- accepted

## Subagent Use Pattern

Safe subagents:

- none for `M8-P1` through `M8-P5`; delegation remains out of scope unless AJ
  explicitly approves it later

Avoid:

- substituting generic implementation personas or ad hoc review lanes for the
  explicit `orbit-memory-gardener` owner
- treating review lanes as permission for implementation or candidate approval

## Evidence Package

- `README.md`
- `Packet-01-Freeze-M7-To-Journal-Intake-Boundary.md`
- `Packet-02-Freeze-Journal-Entry-And-Source-Policy.md`
- `Packet-03-Freeze-Memory-Candidate-Source-And-Scope-Policy.md`
- `Packet-04-Freeze-Memory-Review-Action-Semantics.md`
- `Packet-05-Freeze-Memory-Review-Workflow-And-Inspection-Surface.md`
- `Milestone-Closeout-Review-Artifact.md`

## Stop Points

- stop if `M8` would need to reopen accepted `M7` contracts to define its
  intake boundary honestly
- stop if `orbit-memory-gardener` would be treated as blanket approval for
  `M8` execution instead of one explicit owner prerequisite
- stop if the work broadens into runtime, UI, schema, or implementation
- stop if accepted `M7` returned surfaces are not sufficient to define journal
  intake without hidden state reconstruction
- stop if later candidate packets bypass the accepted journal-first boundary
  and normalize raw runtime artifacts without explicit reopen and review
- stop if review workflow depends on approved-memory materialization,
  activation influence, or retrieval semantics to seem coherent
- stop if the workflow widens into promotion, demotion, contradiction,
  supersession, or linked-memory review actions

## Exit And Handoff

Exit when the dossier freezes:

- explicit `M7` to `M8` intake eligibility
- the first journaling boundary from that intake bundle
- the first candidate-staging and review-action boundaries without implying
  approved memory or implementation authority
- the first-pass review workflow and operator inspection requirements from the
  accepted staging and action floor

Handoff forward to:

- `M9-P1` to freeze approved-memory scope rules without reopening accepted
  `M8` governance boundaries
