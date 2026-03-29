# M8 Packet 2: Freeze Journal Entry And Source Policy

Status: Accepted
Packet Id: `M8-P2`
Milestone: `M8`
Execution Owner: `orbit-memory-gardener`
Review Personas: `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-29

## Header

- status: `done`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Freeze the first-pass journaling contract that turns the accepted `M8-P1`
  intake bundle into reflective `journal_entry` and `journal_source` records
  without starting candidate staging, review actions, or implementation work.
- This packet exists now because `M8-P1` froze which accepted `M7` surfaces may
  seed later journaling, but the dossier still lacks one explicit contract for
  what the first journal layer must contain and cite.
- This is the right slice size because it advances journaling directly and
  unblocks later memory-candidate review without widening into runtime, UI,
  schema, or later `M8` governance redesign.

## Quality Bar

- journals remain reflective compression rather than a replay of raw workstream
  history
- accepted durable `M7` return surfaces stay the normal first-slice source path
- later memory-candidate packets inherit inspectable journal lineage instead of
  falling back to raw runtime artifacts
- owner availability stays bounded to this packet and does not imply blanket
  approval for later `M8` workflow execution

## Preconditions

- `M8-P1` is accepted and remains the authoritative intake boundary for later
  journaling work
- accepted `M7-P1` through `M7-P5` remain frozen and continue to govern source
  continuity, workstream lifecycle, returned status, artifact source of truth,
  and explicit closeout
- `RFC-0005` remains the semantic authority that journals are the first
  compression layer and memory candidates normally derive from journals and
  other explicit structured artifacts
- `RFC-0002` remains the data-model floor for `journal_entry`,
  `journal_source`, `memory_candidate`, and `memory_review`
- `orbit-memory-gardener` is now available as the required owner, but that
  does not authorize candidate review, approval, or implementation work in this
  packet

## Grounding Requirements

- local `personakit` CLI grounding for `samwise` with directive `apply-style`
- `README.md`
- `Packet-01-Freeze-M7-To-Journal-Intake-Boundary.md`
- `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/README.md`
- `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/Milestone-Closeout-Review-Artifact.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md`
- live grounding required: `yes`
- PersonaKit MCP grounding allowed: `no`

## Exact Scope

Include:

- the first-pass `journal_entry` expectations for workstream-derived
  reflections grounded in the accepted `M8-P1` intake bundle
- the normal `journal_source` lineage rules for citing accepted durable `M7`
  surfaces and carried context
- the boundary that keeps journals as reflective synthesis rather than direct
  raw-history ingestion
- the explicit deferred line between journaling and later
  `memory_candidate`/`memory_review` workflow packets

Exclude:

- journal cadence, trigger automation, scheduling, or prompt-template work
- memory-candidate creation, proposed-scope policy, or review-action semantics
- approved memory, retrieval, promotion, or contradiction handling
- runtime work, UI work, schema work, or implementation
- any reopening of accepted `M7` contracts or the accepted `M8-P1` intake
  boundary

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M8-Journaling-And-Memory-Candidate-Review/`
- may create: one packet-local planning artifact inside the `M8` dossier
- must not edit: `M7` dossier files, RFCs, runtime source paths, or later
  milestone dossiers in this packet

## Ordered Work

1. Freeze the minimum reflective job of a first-slice `journal_entry` for
   accepted workstream-derived activity.
2. Freeze the normal `journal_source` citation discipline from the accepted
   `M8-P1` intake bundle and durable `M7` return surfaces.
3. Freeze the deferred boundary so later packets cannot smuggle in candidate
   review, cadence policy, raw-runtime normalization, or implementation detail.

## Validation And Evidence

- updated `M8` milestone README aligned with `M8-P2` as the next bounded
  packet after accepted `M8-P1`
- packet note naming the `journal_entry` boundary, `journal_source` policy, and
  deferred items
- explicit language preserving journals as the normal first compression layer
  before memory-candidate workflow

## Packet 2 Working Contract

### Journal Role And Boundary

- a first-slice journal should answer the RFC questions:
  what changed, what mattered, what was learned, and what should not yet be
  generalized
- a journal is not a thread replay, a closeout packet clone, or a memory
  candidate
- the packet should use the accepted `M8-P1` intake bundle as its floor rather
  than reconstructing hidden workstream history

### Normal First-Slice Journal Inputs

- accepted durable `M7` return surfaces remain the normal source path:
  - workstream post identity plus preserved source-post continuity
  - returned checkpoint, blocker, or closeout summaries
  - explicit lifecycle posture from accepted `M7` return rules
  - attached `artifact`, `decision`, and `reference` objects when they
    materially explain why the work mattered
- raw `message`, `post_event`, and `run` records remain exception-only source
  material and must not become the normal journal seed path in this packet

### Minimum Journal Entry Expectations

- every first-slice journal should stay anchored to:
  - one accepted workstream identity
  - the carried source-post or source-thread lineage from `M8-P1`
  - a visible time window anchored to meaningful returned status or closeout
  - at least one accepted checkpoint, blocker, or closeout summary
- first-slice workstream-derived journals should stay within the existing
  `RFC-0002` entry-type floor:
  - default to `technical_notes` for bounded workstream reflection
  - allow `design_rationale` when the primary durable value is why a design or
    technical choice was made
  - allow `milestone` only when the reflection genuinely summarizes
    milestone-level learning rather than one local workstream
  - do not invent a workstream-specific `journal_entry` type in this packet
- the packet should freeze the minimum reflective contents later work may rely
  on without deciding final prose templates, operator UX, or generation timing

### Journal Source Discipline

- `journal_source` should cite the material sources that shaped the journal
  rather than exhaustively mirroring every message or event
- the normal citation floor should include the accepted workstream identity, the
  carried origin linkage, and the specific returned summary or structured object
  that materially supports the reflection
- if later `M8` work wants raw runtime artifacts to become normal direct
  journal sources, that should reopen `M8-P2` explicitly

### Boundary To Later Packets

- a later packet may freeze `memory_candidate` source, scope, and review
  workflow only if journals remain the normal first compression layer
- cadence, trigger policy, and prompt-shape work remain deferred even if a
  later implementation needs them
- approved memory, retrieval, and cross-workspace promotion remain outside `M8`
  packet 2

## Packet 2 Closure Position

- accepted `M8-P1` intake bundles are now sufficient to support a bounded
  first-slice journaling layer without reopening `M7`
- journals remain the normal first compression layer and cite material durable
  sources rather than replaying raw runtime history
- first-slice workstream-derived reflections stay within the existing
  `RFC-0002` `journal_entry.entry_type` floor instead of inventing new runtime
  categories
- later `M8` packets may stage `memory_candidate` records only if they preserve
  the accepted journaling boundary frozen here

## Open Risks And Review Decisions Needed

- if real review later proves that accepted returned summaries are too thin for
  reflective journaling without normal raw-thread inspection, that should
  reopen `M8-P1` and `M8-P2` together rather than broadening source policy by
  implementation convenience

## Failure Dispositions

- `blocked`
  accepted `M8-P1` intake material is not sufficient to define a coherent first
  journal layer without reopening `M7`
- `needs-review`
  the packet is coherent but awaits AJ review before journal or candidate
  packetization continues
- `grounding-blocked`
  required local PersonaKit grounding or repo-local dossier inputs are not
  available
- `failed`
  the packet depends on raw-history normalization, schema invention, hidden
  autonomy, or later `M8` workflow redesign

## Stop Points

- stop if accepted `M7` and `M8-P1` contracts are insufficient to define normal
  journal inputs without reopening them
- stop if raw runtime artifacts become the normal first-slice journal source
  path without explicit review
- stop if the packet needs new runtime records, UI surfaces, or schema changes
  to feel coherent
- stop if candidate review, approval, or governance execution starts leaking
  into the journal-boundary packet

## Closeout Return Format

- completed or shipped
- evidence produced
- open risks
- review decisions needed
- next recommended packet
