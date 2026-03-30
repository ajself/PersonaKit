# M8 Packet 5: Freeze Memory Review Workflow And Inspection Surface

Status: Accepted
Packet Id: `M8-P5`
Milestone: `M8`
Execution Owner: `orbit-memory-gardener`
Review Personas: `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-30

## Header

- status: `done`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Freeze the first-pass `memory_review` workflow and operator inspection
  surface that govern how accepted `memory_candidate` proposals move through
  review without freezing approved-memory materialization, retrieval,
  promotion/demotion, contradiction handling, linked-memory actions, or
  implementation work.
- This packet exists now because `M8-P4` freezes review-action meanings and
  reviewer posture, but the dossier still lacks one explicit contract for how
  unresolved candidates enter review, what the operator must be able to
  inspect before deciding, and how review outcomes remain visible without
  acting like trusted memory.
- This is the right slice size because it completes the smallest honest
  first-pass review boundary for `M8` while staying out of approved memory,
  runtime, UI, schema, and implementation.

## Quality Bar

- first-pass review starts from the accepted `M8-P3` candidate boundary and
  the accepted `M8-P4` action floor rather than raw runtime reconstruction
- the operator can inspect enough candidate context to make `approve`,
  `reject`, `archive`, or `defer` decisions without hidden heuristics
- deferred and resolved candidates remain inspectable as governance history
  rather than implied approved memory
- the workflow does not smuggle in revise, promote, demote, contradiction, or
  linked-memory actions as first-pass defaults

## Preconditions

- `M8-P1` is accepted and remains the authoritative intake boundary from `M7`
- `M8-P2` is accepted and remains the authoritative journaling boundary
- `M8-P3` is accepted and remains the authoritative candidate-source and
  proposed-scope boundary
- `M8-P4` is accepted and remains the authoritative first-pass review-action
  floor
- `RFC-0002` remains the data-model floor for `memory_candidate` and
  `memory_review`
- `RFC-0005` remains the governance authority for manual review workflow and
  operator-controlled memory growth
- `orbit-memory-gardener` is available as the required owner, but this packet
  does not authorize autonomous approval, approved-memory writes, or runtime
  execution

## Grounding Requirements

- local `personakit` CLI grounding for `samwise` with directive `apply-style`
- `README.md`
- `Packet-01-Freeze-M7-To-Journal-Intake-Boundary.md`
- `Packet-02-Freeze-Journal-Entry-And-Source-Policy.md`
- `Packet-03-Freeze-Memory-Candidate-Source-And-Scope-Policy.md`
- `Packet-04-Freeze-Memory-Review-Action-Semantics.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md`
- live grounding required: `yes`
- PersonaKit MCP grounding allowed: `no`

## Exact Scope

Include:

- the first-pass workflow from staged `memory_candidate` proposals into
  operator-visible review
- the minimum operator inspection requirements for candidate summary, proposed
  scope, provenance, and prior review context
- the posture for active review, deferred follow-up, and resolved review
  history as governance surfaces without defining final UI
- the explicit deferred boundary between review workflow and later
  approved-memory, retrieval, or memory-gardening packets

Exclude:

- approved-memory creation semantics, activation eligibility, retrieval order,
  lineage traversal, or activation influence
- promote, demote, revise, contradiction, superseded, or linked-memory review
  actions
- queue ranking heuristics, reminders, digest cadence, or automation policy
- journal or candidate source-policy changes, or reopening accepted `M8-P3`
  and `M8-P4`
- runtime work, UI work, schema work, or implementation

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M8-Journaling-And-Memory-Candidate-Review/`
- may create: one packet-local planning artifact inside the `M8` dossier
- must not edit: `M7` dossier files, RFCs, runtime source paths, or later
  milestone dossiers in this packet

## Ordered Work

1. Freeze the first-pass review path from accepted candidate staging into one
   explicit operator-governed workflow.
2. Freeze the minimum operator inspection surface needed to decide `approve`,
   `reject`, `archive`, or `defer` honestly.
3. Freeze the boundary between active review, deferred follow-up, and resolved
   review history without implying approved-memory materialization.
4. Record the deferred items that belong to later approved-memory or
   memory-gardening packets instead of first-pass review.

## Validation And Evidence

- updated `M8` milestone README aligned with accepted `M8-P5` as the
  workflow and operator-inspection boundary after accepted `M8-P4`
- packet note naming the first-pass review flow, inspection surface, and
  deferred items
- explicit language preserving review as governance rather than trusted-memory
  creation

## Packet 5 Closure Position

- accepted `memory_candidate` proposals now map to one first-pass review
  workflow: inspect the candidate, record one explicit `memory_review`
  decision, and keep unresolved versus resolved outcomes visible without
  implying approved memory
- operator inspection begins from the accepted candidate artifact and its
  declared provenance rather than normal raw-thread or raw-run reconstruction
- steward or system review records may assist or annotate the workflow, but
  they must not bypass operator authority or hide the basis for a later
  operator decision
- later `M8` closeout or `M9` packets may rely on this workflow only if they
  preserve the accepted `M8-P3` and `M8-P4` boundaries plus the explicit
  deferred items frozen here

## Packet 5 Working Contract

### Review Workflow Role And Boundary

- first-pass review begins only from accepted `memory_candidate` proposals that
  already satisfy the `M8-P3` source and proposed-scope posture
- first-pass review is a governance flow, not approved-memory execution or
  retrieval behavior
- one completed review step should culminate in one explicit `memory_review`
  record using one of the accepted `M8-P4` actions
- if a candidate cannot be judged honestly without scope changes,
  contradiction-handling, linked-memory actions, or approved-memory semantics,
  the workflow should stop and stage later packet work instead of overloading
  `M8-P5`

### First-Pass Review Flow

- active review starts from a staged candidate that already exposes its
  proposed memory text, proposed scope, and declared primary provenance
- the operator should inspect the candidate before any final review action is
  treated as complete
- steward or system review records may appear as preparatory or assistive
  context, but they remain recommendations until the operator acts
- the operator may choose only the accepted `M8-P4` actions: `approve`,
  `reject`, `archive`, or `defer`
- `approve` means the candidate has cleared first-pass governance review and
  may be handed forward to later approved-memory handling; it does not
  materialize a `memory_entry` in `M8-P5`
- `reject` and `archive` remove the candidate from active review while
  preserving inspectable governance history
- `defer` keeps the candidate out of trusted memory and visible for later
  reconsideration without implying approval

### Operator Inspection Surface

- the operator must be able to inspect the candidate's proposed memory content
  and stated confidence before deciding
- the operator must be able to inspect the candidate's proposed scope clearly
  and distinguish it from any later approved-memory scope behavior
- the operator must be able to inspect declared provenance from the accepted
  `M8-P3` source path, including whether the candidate came from the normal
  journal-first posture or an allowed structured-source exception
- the operator must be able to inspect enough supporting review context to
  understand prior steward or system notes without treating those notes as
  final authority
- the normal first-pass inspection path should stay anchored to accepted
  journal and candidate artifacts rather than requiring raw thread, message, or
  run replay to make a decision

### Review Surface Posture

- first-pass review should distinguish active review from deferred follow-up and
  resolved review history
- active review contains candidates awaiting an operator decision
- deferred follow-up contains candidates explicitly held for later operator
  reconsideration and must remain outside trusted memory by default
- resolved review history contains approved, rejected, and archived outcomes as
  inspectable governance records, even though approved-memory behavior belongs
  to later packets
- the workflow may name these surfaces conceptually now without freezing exact
  UI layout, queue controls, or implementation detail

### Explicitly Deferred

- approved-memory materialization and exact `memory_entry` behavior
- retrieval order, activation influence, and activation-memory-source linkage
- scope widening or narrowing semantics, including promote and demote actions
- contradiction, supersession, duplicate-linking, or linked-memory review
  actions
- edit-in-place or revise semantics for candidate content
- queue ranking, reminders, digest scheduling, automation, or final UI

## Open Risks And Review Decisions Needed

- if real operator review later proves that reject/defer plus restaging is too
  weak without an explicit revise flow, later `M8` planning should add a
  bounded follow-on packet rather than quietly overloading `M8-P5`
- if honest first-pass review regularly requires raw thread or run replay
  rather than accepted journal and candidate artifacts, that should reopen
  `M8-P2` and `M8-P3` instead of weakening the review boundary by convenience

## Failure Dispositions

- `needs-review`
  the packet is coherent but still needs sharper wording or reviewer judgment
  before it should anchor `M8`
- `blocked`
  accepted `M8-P3` and `M8-P4` are not sufficient to define an honest review
  workflow without reopening earlier boundaries
- `grounding-blocked`
  required local PersonaKit grounding or repo-local dossier inputs are not
  available
- `failed`
  the packet depends on approved-memory behavior, retrieval design,
  contradiction handling, hidden authority transfer, or implementation detail

## Stop Points

- stop if first-pass review cannot be explained without approved-memory
  materialization, retrieval, or activation influence
- stop if steward or system context becomes final trusted-memory authority
  without explicit reopen and review
- stop if the workflow needs promote, demote, contradiction, superseded, or
  linked-memory actions to seem coherent
- stop if normal operator inspection depends on raw thread, message, or run
  replay instead of the accepted journal and candidate boundary
- stop if the work widens into runtime, UI, schema, or implementation

## Closeout Return Format

- workflow boundary closed or explicitly staged
- operator inspection requirements named
- open risks
- review decisions needed
- next recommended step: `M8` closeout or `M9-P1`
