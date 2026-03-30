# M8 Packet 3: Freeze Memory Candidate Source And Scope Policy

Status: Accepted
Packet Id: `M8-P3`
Milestone: `M8`
Execution Owner: `orbit-memory-gardener`
Review Personas: `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-29

## Header

- status: `done`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Freeze the first-pass `memory_candidate` staging contract that turns accepted
  journals and explicit structured artifacts into reviewed memory proposals
  without starting `memory_review` actions, approved memory behavior, or
  implementation work.
- This packet exists now because `M8-P2` freezes the journaling boundary, but
  the dossier still lacks one explicit contract for which sources may normally
  become candidates and how proposed scope stays bounded before review.
- This is the right slice size because it advances memory-candidate review
  preparation directly while staying out of review-decision workflow, approved
  memory, runtime, UI, schema, and implementation.

## Quality Bar

- `memory_candidate` remains an explicit staging layer rather than implied
  memory
- accepted journals remain the normal first-slice candidate source path
- direct raw runtime artifacts stay exception-only sources unless a later
  packet explicitly reopens that policy
- proposed scope stays inspectable and bounded before any approval or retrieval
  behavior is frozen

## Preconditions

- `M8-P1` is accepted and remains the authoritative intake boundary from `M7`
- `M8-P2` is accepted and remains the authoritative journaling boundary for
  first-slice `journal_entry` and `journal_source` behavior
- `RFC-0005` remains the semantic authority that candidates are memory
  proposals and normally derive from journals and other explicit structured
  artifacts
- `RFC-0002` remains the data-model floor for `memory_candidate` and
  `memory_review`
- `orbit-memory-gardener` is available as the required owner, but this packet
  does not authorize review decisions, approval, or retrieval behavior

## Grounding Requirements

- local `personakit` CLI grounding for `samwise` with directive `apply-style`
- `README.md`
- `Packet-01-Freeze-M7-To-Journal-Intake-Boundary.md`
- `Packet-02-Freeze-Journal-Entry-And-Source-Policy.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md`
- live grounding required: `yes`
- PersonaKit MCP grounding allowed: `no`

## Exact Scope

Include:

- the normal first-slice `memory_candidate` source policy from accepted
  journals plus explicit structured artifacts permitted by the RFC floor
- the first-pass proposed-scope posture for `workspace`, `workspace_persona`,
  `persona_global`, and `organization` candidate staging
- the boundary that keeps candidates as proposals rather than approved memory
- the explicit deferred line between candidate staging and later
  `memory_review` action semantics

Exclude:

- `memory_review` decision rules, reviewer roles, archive/defer behavior, or
  governance execution details
- approved memory, retrieval, lineage traversal, promotion, or contradiction
  handling
- journal cadence, prompt-template work, or reopening the accepted `M8-P2`
  journaling boundary
- runtime work, UI work, schema work, or implementation

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M8-Journaling-And-Memory-Candidate-Review/`
- may create: one packet-local planning artifact inside the `M8` dossier
- must not edit: `M7` dossier files, RFCs, runtime source paths, or later
  milestone dossiers in this packet

## Ordered Work

1. Freeze the normal first-slice `memory_candidate` source discipline from
   accepted journals and explicit structured artifacts.
2. Freeze the proposed-scope posture for candidate staging without implying
   approval, retrieval, or cross-scope promotion.
3. Freeze the deferred boundary so later packets cannot smuggle in review
   decisions, approved memory behavior, or raw-runtime normalization.

## Validation And Evidence

- updated `M8` milestone README aligned with accepted `M8-P3` as the frozen
  candidate-staging boundary after accepted `M8-P2`
- packet note naming the `memory_candidate` source boundary, proposed-scope
  posture, and deferred review items
- explicit language preserving candidates as reviewed proposals rather than
  implied memory

## Packet 3 Closure Position

- accepted journals remain the normal primary source for first-slice
  `memory_candidate` staging
- `note`, `decision`, and explicit manual proposal artifacts may stage
  candidates directly only as bounded structured-source exceptions allowed by
  the RFC floor, not as a replacement for journal-first discipline
- first-slice candidate staging should preserve one inspectable primary-source
  posture per candidate before later review workflow decides what to approve,
  reject, defer, or archive
- later `M8` packets may freeze `memory_review` action semantics only if they
  preserve the candidate-staging boundary and the journal-first source posture
  frozen here

## Packet 3 Working Contract

### Candidate Role And Boundary

- a `memory_candidate` is a memory proposal, not memory itself
- candidate staging should create an inspectable buffer between
  "this seems important" and "this should affect future reasoning"
- this packet should freeze candidate staging only, not review decisions or
  retrieval behavior

### Normal First-Slice Candidate Sources

- accepted journals are the normal first-slice candidate source
- first-slice staging should nominate one primary source artifact per
  candidate so lineage stays inspectable within the existing `RFC-0002`
  `source_type` / `source_id` floor
- when an accepted journal and a structured artifact both point at the same
  durable learning, the journal should be the normal primary source and the
  structured artifact should remain supporting evidence unless explicit later
  policy reopens that posture
- `note` and `decision` artifacts may also serve as normal candidate sources
  only when they are the clearest explicit durable artifact for the proposed
  learning and no accepted journal is being used as the primary source for that
  same candidate
- explicit operator-entered manual proposals remain allowed by the RFC floor
- `reference` and `artifact` objects are usually supporting evidence or context
  and should normally shape journals, notes, or decisions first
- direct raw `post`, `thread`, `message`, and `run` sources remain
  exception-only and must not become the normal first-slice candidate path in
  this packet

### Proposed-Scope Posture

- first-slice candidate staging may propose only the existing RFC scope set:
  `workspace`, `workspace_persona`, `persona_global`, or `organization`
- the packet should freeze how scope is proposed for review, not how it is
  approved or retrieved later
- v1 still does not create team-scoped memory as a first-class candidate scope
- if later work wants broader default promotion posture, that should reopen
  `M8-P3` explicitly

### Boundary To Later Packets

- a later packet may freeze `memory_review` action semantics only if candidates
  remain a distinct staging layer
- approved memory, retrieval, lineage, and promotion remain outside `M8-P3`
- if later work wants raw runtime artifacts to become normal direct candidate
  sources, that should reopen `M8-P3` rather than slipping in as an
  implementation convenience

## Open Risks And Review Decisions Needed

- if real usage later proves that accepted journals are too coarse for normal
  candidate formation, that should reopen `M8-P2` and `M8-P3` together instead
  of weakening journal-first discipline silently

## Failure Dispositions

- `blocked`
  accepted `M8-P2` journal outputs are not sufficient to define coherent
  candidate staging without reopening earlier boundaries
- `needs-review`
  the packet is coherent but awaits AJ review before review-workflow
  packetization continues
- `grounding-blocked`
  required local PersonaKit grounding or repo-local dossier inputs are not
  available
- `failed`
  the packet depends on review-action design, approved memory behavior,
  hidden autonomy, or implementation detail

## Stop Points

- stop if accepted `M8-P2` journals are treated as optional instead of the
  normal candidate source path
- stop if raw runtime artifacts become the normal first-slice candidate source
  path without explicit review
- stop if the packet needs review-decision semantics, approved memory behavior,
  or implementation detail to seem coherent
- stop if the work widens into retrieval, promotion, UI, schema, or runtime

## Closeout Return Format

- completed or shipped
- evidence produced
- open risks
- review decisions needed
- next recommended packet
