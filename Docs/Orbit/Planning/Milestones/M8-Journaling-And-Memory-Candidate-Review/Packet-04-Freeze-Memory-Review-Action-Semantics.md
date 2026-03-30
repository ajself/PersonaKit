# M8 Packet 4: Freeze Memory Review Action Semantics

Status: Accepted
Packet Id: `M8-P4`
Milestone: `M8`
Execution Owner: `orbit-memory-gardener`
Review Personas: `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-29

## Header

- status: `done`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Freeze the first-pass `memory_review` action semantics that govern how
  accepted `memory_candidate` proposals may be reviewed without starting
  approved-memory behavior, retrieval, promotion, contradiction handling, or
  implementation work.
- This packet exists now because `M8-P3` freezes candidate source and
  proposed-scope policy, but the dossier still lacks one explicit contract for
  the review actions and reviewer posture that keep candidate memory governed
  before it can affect future reasoning.
- This is the right slice size because it advances review-workflow planning
  directly while staying out of approved memory materialization, runtime, UI,
  schema, and implementation.

## Quality Bar

- `memory_review` remains an explicit governance layer rather than an implied
  approved-memory write
- the RFC-0002 floor actions `approve`, `reject`, `archive`, and `defer`
  receive one bounded first-pass semantic posture
- operator authority over trusted memory stays explicit even when steward or
  system review records exist
- later packets can refine workflow or tooling without weakening the accepted
  candidate-staging boundary

## Preconditions

- `M8-P1` is accepted and remains the authoritative intake boundary from `M7`
- `M8-P2` is accepted and remains the authoritative journaling boundary
- `M8-P3` is accepted and remains the authoritative candidate-source and
  proposed-scope boundary
- `RFC-0005` remains the semantic authority that candidates are reviewed
  proposals and approved memory is a later distinct layer
- `RFC-0002` remains the data-model floor for `memory_review` and
  `memory_entry`
- `orbit-memory-gardener` is available as the required owner, but this packet
  does not authorize autonomous approval, approved-memory retrieval behavior,
  or implementation work

## Grounding Requirements

- local `personakit` CLI grounding for `samwise` with directive `apply-style`
- `README.md`
- `Packet-01-Freeze-M7-To-Journal-Intake-Boundary.md`
- `Packet-02-Freeze-Journal-Entry-And-Source-Policy.md`
- `Packet-03-Freeze-Memory-Candidate-Source-And-Scope-Policy.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md`
- live grounding required: `yes`
- PersonaKit MCP grounding allowed: `no`

## Exact Scope

Include:

- the first-pass semantic posture for the RFC-0002 `memory_review` decisions:
  `approve`, `reject`, `archive`, and `defer`
- the first-pass reviewer posture for `operator`, `steward`, and `system`
  review records while preserving operator authority over trusted memory
- the boundary that keeps review actions distinct from approved-memory writes
- the explicit deferred line between candidate review semantics and later
  workflow, tooling, and approved-memory packets

Exclude:

- approved-memory creation semantics, activation eligibility, retrieval order,
  lineage traversal, or promotion execution
- widening or narrowing scope as a review action, including promote or demote
  semantics
- contradiction handling, supersession, duplicate-linking, or review-inbox UX
- journal or candidate source policy changes, or reopening accepted `M8-P3`
- runtime work, UI work, schema work, or implementation

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M8-Journaling-And-Memory-Candidate-Review/`
- may create: one packet-local planning artifact inside the `M8` dossier
- must not edit: `M7` dossier files, RFCs, runtime source paths, or later
  milestone dossiers in this packet

## Ordered Work

1. Freeze the first-pass semantic posture for `approve`, `reject`, `archive`,
   and `defer`.
2. Freeze the reviewer-authority boundary so review records stay governed and
   inspectable.
3. Freeze the deferred boundary so later packets cannot smuggle in
   approved-memory behavior, scope-promotion semantics, or implementation
   detail.

## Validation And Evidence

- updated `M8` milestone README aligned with accepted `M8-P4` as the frozen
  first-pass review-action boundary after accepted `M8-P3`
- packet note naming the `memory_review` action boundary, reviewer posture, and
  deferred items
- explicit language preserving review as governance rather than trusted-memory
  creation

## Packet 4 Closure Position

- accepted `memory_candidate` proposals now map to one first-pass
  `memory_review` action floor: `approve`, `reject`, `archive`, or `defer`
- operator authority remains explicit even when steward or system review
  records exist
- first-pass review remains governance, not approved-memory creation or future
  activation influence
- later `M8` packets may refine workflow or tooling only if they preserve the
  accepted action floor and the separation between review and approved memory

## Packet 4 Working Contract

### Review Role And Boundary

- a `memory_review` record is a governance action on a candidate, not durable
  memory itself
- review should create an inspectable decision layer between candidate staging
  and any later approved-memory behavior
- this packet freezes review-action semantics only, not approved-memory write
  behavior or retrieval eligibility

### First-Pass Review Actions

- `approve` means the candidate has passed first-pass review and may move
  forward to later approved-memory handling, but this packet does not freeze
  the exact resulting `memory_entry` behavior
- `reject` means the candidate should not move forward as trusted memory from
  this proposal
- `archive` means the candidate is removed from active review without being
  treated as approved memory; later workflow may still inspect its provenance
- `defer` means the candidate remains unresolved for later review and must not
  affect future reasoning by default
- promote, demote, contradiction, superseded, and link actions remain outside
  first-pass `M8-P4` review semantics even if later workflow wants them

### Reviewer Posture

- the operator remains the final authority on what becomes trusted memory
- a `steward` review record may recommend or record a governed review step, but
  it must not silently bypass operator authority
- a `system` review record may exist only as an explicit audit or assistance
  artifact under operator-governed policy; autonomous approval remains out of
  scope for this packet
- `orbit-memory-gardener` is stewardship, not blanket approval authority

### Boundary To Later Packets

- a later packet may refine review workflow, queue posture, or tooling only if
  `memory_review` remains a distinct governance layer
- approved memory materialization, retrieval, lineage, and future activation
  influence remain outside `M8-P4`
- if later work wants scope widening, contradiction handling, or linked-memory
  review actions to become first-pass defaults, that should reopen `M8-P4`
  explicitly rather than slipping in as workflow convenience

## Open Risks And Review Decisions Needed

- if real review later proves that `approve`, `reject`, `archive`, and `defer`
  are too small a first-pass action set for honest operator workflow, later
  `M8` planning should add a bounded follow-on packet rather than overload
  these actions silently

## Failure Dispositions

- `blocked`
  accepted `M8-P3` candidate staging is not sufficient to define coherent
  first-pass review semantics without reopening earlier boundaries
- `needs-review`
  the packet is coherent but awaits AJ review before later review-workflow
  packetization continues
- `grounding-blocked`
  required local PersonaKit grounding or repo-local dossier inputs are not
  available
- `failed`
  the packet depends on approved-memory behavior, autonomous stewardship,
  hidden authority transfer, or implementation detail

## Stop Points

- stop if `approve` is treated as equivalent to a fully frozen approved-memory
  write or activation-time influence
- stop if steward or system review records become final trusted-memory
  authority without explicit reopen and review
- stop if the packet needs promotion, contradiction, runtime, UI, schema, or
  implementation detail to seem coherent
- stop if the work reopens accepted journal-first or candidate-staging
  boundaries without explicit review

## Closeout Return Format

- completed or shipped
- evidence produced
- open risks
- review decisions needed
- next recommended packet
