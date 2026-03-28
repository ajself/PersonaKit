# M8 Journaling And Memory Candidate Review

Status: Planning baseline accepted; execution blocked on owner prerequisite
Primary Owner: `orbit-memory-gardener` (required; milestone execution remains
blocked until this persona exists)
Supporting Personas: `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-28

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
- honest about the missing `orbit-memory-gardener` prerequisite instead of
  silently substituting another persona

The bare minimum is not a milestone win.

`M8` planning starts with one bounded intake-boundary packet from the accepted
local `M7` dossier. Later journal, candidate, and review packets remain blocked
until that boundary is accepted and the owner prerequisite is resolved.

## Current Milestone Position

- the accepted `M7` closeout dossier is the frozen local baseline for `M8`
  planning unless later repo-local evidence forces an explicit reopen
- accepted `M7-P1` through `M7-P5` remain authoritative for source continuity,
  workstream lifecycle, returned status, artifact source of truth, and explicit
  closeout
- `M8-P1` is accepted: the first-pass `M7` to `M8` intake boundary is now
  frozen as the planning baseline for the milestone
- `orbit-memory-gardener` is still missing from PersonaKit and remains the
  approved owner prerequisite before delegated `M8` execution work
- later `M8` packets remain blocked until the owner prerequisite is resolved or
  AJ explicitly changes the owner contract

## File Map

- `README.md`
  milestone overview, packet order, and top-level guardrails
- `Packet-01-Freeze-M7-To-Journal-Intake-Boundary.md`
  first bounded planning packet for `M8-P1`

## Preconditions

- the accepted `M7` README and milestone closeout artifact remain the
  authoritative handoff source for this planning pass
- accepted `M7-P1` through `M7-P5` remain frozen and must not be reopened
  implicitly
- `RFC-0002` remains the data-model floor for `journal_entry`,
  `journal_source`, `memory_candidate`, and `memory_review`
- `RFC-0004` remains the authority for follow-up continuity and coordinator
  trigger points, not memory governance or workstream execution
- `orbit-memory-gardener` is still absent and remains a hard prerequisite
  before delegated `M8` journal or candidate workflow work

## Scope Freeze

In scope:

- `M8` planning only from the frozen `M7` baseline
- first-pass intake eligibility from accepted `M7` workstream evidence
- the blocked-owner posture and stop points for the missing
  `orbit-memory-gardener`
- the handoff boundary from accepted `M7` closeout into later `M8` packets

Out of scope:

- journal generation
- memory-candidate creation or review actions
- approved memory influencing activations
- cross-workspace promotion, automated gardening, or contradiction handling
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
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`

## Execution Packets

### Packet 1. Freeze M7-To-Journal Intake Boundary

Outcome:

- accepted `M7` workstream evidence maps to one explicit first-pass intake
  boundary for later journaling work

Work:

- define which accepted `M7` surfaces count as normal first-slice journal input
- define the minimum handoff bundle from `M7` into later `M8` packets
- record the blocked-owner posture and explicit stop points that prevent hidden
  autonomy or premature implementation

Done when:

- later `M8` work can start from an explicit intake boundary or stop visibly if
  the owner prerequisite is still unresolved

Status:

- accepted

Later `M8` packets remain intentionally unfrozen and blocked until
`orbit-memory-gardener` exists or AJ explicitly changes the owner contract.

## Subagent Use Pattern

Safe subagents:

- none for `M8-P1`; delegation remains out of scope unless AJ explicitly
  approves it later

Avoid:

- substituting subagents for the missing `orbit-memory-gardener`
- treating review lanes as permission for implementation or candidate approval

## Evidence Package

- `README.md`
- `Packet-01-Freeze-M7-To-Journal-Intake-Boundary.md`

## Stop Points

- stop if `M8` would need to reopen accepted `M7` contracts to define its
  intake boundary honestly
- stop if the missing `orbit-memory-gardener` would be papered over by
  `samwise` or a generic implementation persona
- stop if the work broadens into runtime, UI, schema, or implementation
- stop if accepted `M7` returned surfaces are not sufficient to define journal
  intake without hidden state reconstruction

## Exit And Handoff

Exit when accepted `M7` workstream outputs are named as explicit future journal
inputs and the dossier states clearly that later `M8` execution remains blocked
pending `orbit-memory-gardener`.

Handoff forward to:

- later `M8` journal and candidate packets once `orbit-memory-gardener` exists
  and `M8-P1` is accepted
