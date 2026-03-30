# M9 Packet 1: Freeze Approved-Memory Scope Rules

Status: Accepted
Packet Id: `M9-P1`
Milestone: `M9`
Execution Owner: `orbit-memory-gardener`
Review Personas: `venture-product-steward`, `studio-coverage-architect`, `architectural-editor`
Last Updated: 2026-03-30

## Header

- status: `done`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Freeze the first-pass meaning of approved-memory scope for `workspace`,
  `workspace_persona`, `persona_global`, and optional `organization` without
  widening into retrieval behavior, activation influence, lineage, promotion or
  demotion execution, contradiction handling, linked-memory behavior, runtime,
  UI, schema, or implementation.
- This packet exists now because accepted `M8` closes the review and candidate
  boundary but explicitly does not authorize approved-memory writes, retrieval,
  activation influence, or later governance semantics.
- This is the smallest honest next slice because later `M9` packets need one
  stable scope contract before they can define approved-memory records,
  retrieval eligibility, or trace inspection.

## Quality Bar

- each approved-memory scope has one explicit first-pass meaning
- `workspace` and `workspace_persona` remain reviewably distinct
- `persona_global` remains separate from authored persona definitions
- optional `organization` scope stays bounded and default-off rather than
  ambient
- operator authority remains explicit for approved memory and any later scope
  widening

## Preconditions

- `Docs/Current-State.md` identifies `M9-P1` as the current work item
- accepted `M8` closeout remains the authoritative handoff boundary into `M9`
- `M8` candidate and review packets remain frozen and must not be reopened
  implicitly
- `RFC-0005` remains the semantic floor for candidate scopes, approved-memory
  scope labels, and persona-global profile separation
- `RFC-0001` remains the activation authority, but this packet does not freeze
  retrieval or activation semantics
- `RFC-0003` remains the authority for workspace and workspace-persona memory
  ownership boundaries
- `RFC-0002` remains the data-model floor for scope labels only, not runtime or
  schema implementation in this packet

## Grounding Requirements

- local `personakit` CLI grounding for `samwise` with directive `apply-style`
- grounding command:
  `swift run personakit export --root .personakit --no-global --persona samwise --directive apply-style`
- grounding graph:
  `swift run personakit graph --root .personakit --no-global --persona samwise --directive apply-style`
- `README.md`
- `Docs/Current-State.md`
- `Docs/Orbit/Planning/Milestones/M8-Journaling-And-Memory-Candidate-Review/README.md`
- `Docs/Orbit/Planning/Milestones/M8-Journaling-And-Memory-Candidate-Review/Milestone-Closeout-Review-Artifact.md`
- `Docs/Orbit/RFCs/RFC-0001-Workspace-Persona-Contract-Resolution-and-Activation-Model.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0003-Workspace-Group-and-Workspace-Persona-Instance-Model.md`
- `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md`
- live grounding required: `yes`
- PersonaKit MCP grounding allowed: `no`

## Exact Scope

Include:

- the first-pass meaning of approved-memory scope for `workspace`,
  `workspace_persona`, `persona_global`, and optional `organization`
- the non-overlap boundary between workspace-local shared memory and
  workspace-persona-local memory
- the explicit separation between persona-global memory and authored persona
  definitions
- the explicit operator-authority posture that prevents hidden scope widening

Exclude:

- retrieval order, retrieval eligibility, activation influence, or
  activation-memory-source behavior
- lineage, traversal, or linked-memory behavior
- promotion, demotion, or any other scope-change execution semantics
- contradiction, supersession, expiry, or review-action redesign
- runtime work, UI work, schema work, or implementation

## Write Scope

- may edit:
  `Docs/Orbit/Planning/Milestones/M9-Approved-Memory-And-Scoped-Retrieval/`
- may create:
  one packet-local planning artifact inside the `M9` dossier
- must not edit:
  accepted `M8` packet files, RFCs, runtime source paths, or later milestone
  dossiers in this packet

## Ordered Work

1. Confirm the exact accepted `M8` handoff boundary into approved-memory scope
   work.
2. Freeze one stable first-pass meaning for each approved-memory scope.
3. Freeze the boundary lines that later packets must respect so scope meaning
   does not collapse into retrieval, activation, lineage, or implementation.

## Packet 1 Working Contract

### Boundary From Accepted `M8`

- `M8` hands forward only the right to freeze approved-memory scope meaning
- `M8` does not authorize approved-memory writes, retrieval, activation
  influence, promotion or demotion semantics, contradiction handling,
  linked-memory actions, runtime, UI, schema, or implementation
- if this packet needs any of those deferred areas to seem coherent, `M9-P1`
  should stop rather than quietly widen

### First-Pass Scope Meanings

- `workspace`:
  approved memory that belongs to one workspace as a shared local operating
  surface; it may describe norms, terminology, decisions, or durable context
  for that workspace, but it is not attached to one specific workspace persona
  instance and it does not imply cross-workspace reuse
- `workspace_persona`:
  approved memory that belongs to one workspace persona instance inside one
  workspace; it captures local learned expertise or preferences for that
  collaborator-in-context and must not be treated as workspace-wide memory
  merely because it was learned in the same workspace
- `persona_global`:
  approved cross-workspace expertise attached to a persona template's separate
  memory profile rather than to the authored persona definition itself; this
  packet freezes that identity boundary only and does not define how memory is
  promoted into this scope
- `organization`:
  optional higher-level approved memory for bounded cross-workspace learning
  when a deployment explicitly chooses to support it; this scope is not assumed
  to exist in every deployment and remains default-off in smaller or
  self-hosted setups unless enabled deliberately

### Scope Separation Tests

- if the memory should stay true for the workspace regardless of which
  workspace persona instance later acts there, it is `workspace`
- if the memory is specific to one workspace persona instance's learned local
  behavior or expertise in that workspace, it is `workspace_persona`
- if the memory describes reusable persona expertise that is intentionally kept
  separate from authored persona definitions across workspaces, it is
  `persona_global`
- if the memory would only make sense as a deployment-level cross-workspace
  pattern and the deployment explicitly supports that posture, it is
  `organization`

### Guardrails Preserved For Later Packets

- scope meaning is separate from retrieval behavior
- scope meaning is separate from activation eligibility or activation influence
- scope meaning is separate from lineage and linked-memory behavior
- scope meaning is separate from promotion or demotion execution
- scope meaning is separate from contradiction or supersession handling
- approved memory remains operator-governed, and any later scope widening must
  stay explicit rather than ambient
- approved memory remains separate from authored persona definitions

## Validation And Evidence

- updated `M9` milestone README aligned with `M9-P1` as the current packet
- packet note naming one explicit first-pass meaning for each approved-memory
  scope
- explicit language separating scope meaning from retrieval, activation,
  lineage, linked-memory behavior, and implementation work

## Packet 1 Closure Position

- `workspace`, `workspace_persona`, `persona_global`, and optional
  `organization` now have one first-pass meaning suitable for review
- workspace-local shared memory and workspace-persona-local memory are now
  bounded enough to review without hidden overlap
- persona-global memory is explicitly separate from authored persona
  definitions
- later `M9` packets may build approved-memory records, retrieval rules, and
  trace inspection only if they preserve the scope contract frozen here

## Open Risks And Review Decisions Needed

- if review cannot distinguish `workspace` from `workspace_persona` without
  importing retrieval or activation behavior, `M9-P1` is not honest enough yet
- if product review wants organization scope to be absent rather than optional,
  that should be decided here before retrieval or lineage work depends on it
- if later work tries to use scope meaning to smuggle in promotion,
  contradiction, or linked-memory semantics, that should stop and reopen review

## Failure Dispositions

- `blocked`
  accepted `M8` boundaries are not sufficient to define approved-memory scope
  meaning without reopening `M8`
- `needs-review`
  the packet is coherent but awaits AJ review before later `M9` packets depend
  on it
- `grounding-blocked`
  required local PersonaKit grounding or repo-local dossier inputs are not
  available
- `failed`
  the packet depends on retrieval, activation influence, lineage,
  contradiction, promotion, linked-memory behavior, or implementation detail to
  remain coherent

## Stop Points

- stop if `M9-P1` would need to reopen accepted `M8` boundaries to define scope
  meaning honestly
- stop if workspace and workspace-persona meaning collapse into one another
- stop if persona-global memory starts mutating authored persona definitions
- stop if organization scope quietly becomes default-on or mandatory everywhere
- stop if the work widens into retrieval, activation, lineage, promotion,
  contradiction, linked-memory behavior, runtime, UI, schema, or
  implementation

## Closeout Return Format

- completed or shipped
- evidence produced
- open risks
- review decisions needed
- next recommended packet
