# M8 Packet 1: Freeze M7-To-Journal Intake Boundary

Status: Accepted
Packet Id: `M8-P1`
Milestone: `M8`
Execution Owner: `samwise`
Review Personas: `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-28

## Header

- status: `done`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Freeze the first-pass handoff boundary from accepted `M7` workstream evidence
  into future journaling without starting journal creation, candidate review,
  or implementation work.
- This packet exists now because `M7` closed with an explicit handoff to `M8`,
  but the repo has no accepted intake contract and still lacks the required
  `orbit-memory-gardener` owner persona.
- This is the right slice size because it defines eligible `M7` sources, the
  minimum carried context, and the blocked-owner posture without reopening
  accepted `M7` contracts or inventing later memory workflow behavior.

## Quality Bar

- accepted `M7` outputs are sufficient to seed later journaling without
  re-reading hidden runtime state
- first-slice journal intake prefers accepted durable surfaces over raw runtime
  exhaust
- the missing `orbit-memory-gardener` prerequisite stays visible as a real stop
  point rather than being silently substituted
- later `M8` packets can add journal or candidate workflow details without
  weakening the accepted `M7` closeout posture

## Preconditions

- the accepted local `M7` README and milestone closeout artifact remain the
  authoritative handoff baseline for this packet
- accepted `M7-P1` through `M7-P5` remain frozen and continue to govern owner
  authority, runtime shape, handoff, returned visibility, and review gates
- `RFC-0002` remains the baseline for `journal_entry`, `journal_source`,
  `memory_candidate`, and `memory_review`
- `RFC-0004` remains the authority for follow-up continuity and coordinator
  trigger points, not workstream execution or memory governance
- `orbit-memory-gardener` is still missing from PersonaKit and remains a hard
  prerequisite before delegated `M8` execution or review workflow work

## Grounding Requirements

- local `personakit` CLI grounding for `samwise` with directive `apply-style`
- `README.md`
- `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/README.md`
- `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/Milestone-Closeout-Review-Artifact.md`
- `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/Packet-01-Freeze-Workstream-Ownership-And-Contract.md`
- `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/Packet-02-Freeze-Workstream-Runtime-Model.md`
- `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/Packet-03-Freeze-Handoff-From-Discussion-To-Execution.md`
- `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/Packet-04-Freeze-Progress-And-Artifact-Return.md`
- `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/Packet-05-Prove-Lane-Discipline-And-Review-Gates.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Decision-Register.md`
- `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Persona-Coverage-Matrix.md`
- live grounding required: `yes`
- PersonaKit MCP grounding allowed: `no`

## Exact Scope

Include:

- the accepted `M7` workstream surfaces that count as normal first-slice
  journal intake
- the minimum carried context later `M8` packets may rely on without hidden
  reconstruction of workstream history
- the explicit blocked-owner posture caused by the missing
  `orbit-memory-gardener`
- the boundary between accepted `M7` outputs and later `M8` journal, candidate,
  and review packets

Exclude:

- journal-entry creation, storage behavior, or cadence policy
- memory-candidate creation, review actions, approval rules, or scope policy
- approved memory, retrieval, or cross-workspace promotion behavior
- persona creation, hidden autonomy, or background processing
- runtime work, UI work, schema work, or implementation

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M8-Journaling-And-Memory-Candidate-Review/`
- may create: one packet-local planning artifact inside the `M8` dossier
- must not edit: `M7` dossier files, RFCs, runtime source paths, or later
  milestone dossiers in this packet

## Ordered Work

1. Freeze which accepted `M7` surfaces count as normal first-slice journal
   intake.
2. Freeze the minimum `M7` to `M8` handoff bundle and the blocked-owner
   posture.
3. Freeze the deferred boundary so later `M8` packets cannot smuggle in review
   workflow, implementation, or hidden autonomy.

## Validation And Evidence

- updated `M8` milestone README aligned with `M8-P1` as the active planning
  packet
- packet note naming authoritative intake sources, minimum carried context, and
  deferred items
- explicit language preserving accepted `M7` closure and the missing-owner stop
  point

## Packet 1 Closure Position

- accepted `M7` workstream outputs are sufficient to freeze the first `M8`
  intake boundary without reopening `M7`
- first-slice normal journal intake should come from accepted durable `M7`
  surfaces rather than raw runtime exhaust
- the missing `orbit-memory-gardener` remains a real blocker for later `M8`
  execution packets and may not be papered over by `samwise` or a generic
  implementation persona
- later `M8` packets may define journal records, candidate staging, and review
  workflow only if they preserve the intake boundary frozen here or explicitly
  reopen `M8-P1`

## Packet 1 Working Contract

### Explicit Assumptions

- the accepted local `M7` dossier named in the handoff request is the frozen
  baseline for this packet
- the smallest honest first slice for `M8` is intake-boundary planning, not
  journal generation or candidate review behavior
- `samwise` may prepare this planning packet under local PersonaKit grounding,
  but that does not substitute for the missing `orbit-memory-gardener`

### Authoritative M7 Intake Sources

- the normal first-slice sources for later journaling are the accepted durable
  `M7` surfaces:
  - linked `workstream` post identity and preserved `follow_up` continuity to
    the source post
  - `workstream_state` lifecycle truth together with the returned status,
    checkpoint, blocker, and terminal summaries frozen by `M7-P4`
  - explicit closeout narratives compatible with
    `note_type = workstream_closeout`
  - workstream-attached `artifact`, `decision`, and `reference` objects that
    remain inspectable without silent dual write
- source message posts and meeting posts remain part of lineage through the
  accepted `M7-P3` handoff link, but they are not the normal first-slice
  journal seed by themselves once work has moved into a workstream

### Minimum M7-To-M8 Intake Bundle

Every later `M8` packet should be able to rely on the following carried context
without reconstructing hidden runtime state:

- workstream post identifier
- source post identifier and source post type
- source thread or meeting linkage carried forward by accepted `M7` handoff
  rules
- visible time window anchored to significant returned status or explicit
  closeout
- one accepted checkpoint, blocker, or closeout summary
- explicit terminal or current lifecycle posture:
  `blocked`, `completed`, `failed`, `cancelled`, or the latest meaningful
  in-flight checkpoint
- any attached `artifact`, `decision`, or `reference` object needed to explain
  why the work matters

### Normal Vs Exception Source Policy

- the first slice should treat accepted durable `M7` return surfaces as the
  normal journaling input path
- raw `message`, `post_event`, and `run` records remain exception-only
  candidate sources even though `RFC-0002` leaves room for them under explicit
  later policy
- if later `M8` work wants raw runtime artifacts to become normal journal
  sources, that should reopen `M8-P1` rather than slipping in as an
  implementation convenience

### Owner And Stop-Point Contract

- `orbit-memory-gardener` remains the required owner for later `M8` execution
  and review workflow packets
- `samwise` may prepare planning-only dossier updates under local grounding but
  does not inherit authority to execute memory-governance work
- no later packet may claim journal generation, candidate staging, review
  action, or governance execution authority until the owner persona exists or
  AJ explicitly changes the owner contract

### Boundary To Later Packets

- a later packet may freeze `journal_entry` and `journal_source` behavior only
  if it preserves the authoritative intake sources defined here
- a later packet may freeze `memory_candidate` and `memory_review` workflow
  only if it preserves the reviewed-proposal boundary and the missing-owner stop
  point
- approved memory and retrieval remain `M9`
- runtime, UI, schema, and implementation work remain out of scope

## Open Risks And Review Decisions Needed

- the intake boundary is now frozen before detailed journal cadence or review
  policy, so later `M8` work must keep those additions subordinate to the
  accepted `M7` surfaces rather than drifting into raw-history ingestion
- if real workstream activity later proves that accepted returned summaries are
  insufficient without raw thread or event inspection, that should reopen
  `M8-P1` and may also require explicit review of `M7-P4`

## Failure Dispositions

- `blocked`
  the owner prerequisite or accepted `M7` source surfaces are not sufficient to
  define journal intake honestly
- `needs-review`
  the intake boundary is coherent but awaits AJ review before later `M8`
  packetization
- `grounding-blocked`
  required local PersonaKit grounding or repo-local `M7` closeout evidence is
  not available
- `failed`
  the packet depends on reopened `M7` contracts, hidden autonomy, or premature
  implementation detail

## Stop Points

- stop if accepted `M7` contracts are not enough to define normal journal
  intake without reopening them
- stop if the missing `orbit-memory-gardener` would be replaced implicitly by
  `samwise`, a generic engineering persona, or a hidden service
- stop if runtime, UI, schema, or implementation detail is needed to make the
  packet seem coherent
- stop if raw runtime exhaust becomes the normal source path without explicit
  review

## Closeout Return Format

- completed or shipped
- evidence produced
- open risks
- review decisions needed
- next recommended packet
