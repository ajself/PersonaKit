# M9 Packet 4: Implement Trace And Lineage Inspection

Status: Current
Packet Id: `M9-P4`
Milestone: `M9`
Execution Owner: `orbit-memory-gardener`
Review Personas: `venture-product-steward`, `studio-coverage-architect`, `architectural-editor`
Last Updated: 2026-03-31

## Header

- status: `current`
- operator or reviewer required: `yes`
- packet type: `implementation`

## Objective

- Implement the smallest honest trace-inspection slice on top of the accepted
  `M9-P3` retrieval-eligibility posture.
- Persist the minimum durable runtime surfaces needed to inspect which
  activation ran, which resolved contract context governed it, which approved
  memory entries were loaded, and what minimum candidate ancestry exists for
  those loaded entries.
- Keep this packet runtime-first and store-first without widening into gateway
  routes, Studio UI, or broader lineage traversal.

## Quality Bar

- activation trace inspection is durable and deterministic
- contract snapshot persistence is explicit rather than inferred from transient
  realtime payloads
- traced memory sources reflect only approved memory that was already eligible
  and loaded under the accepted `M9-P3` rules
- first-slice lineage is minimum lineage only: approved memory entry back to
  `source_memory_candidate_id` when present
- the packet does not smuggle in gateway/UI work, `memory_link`, broader graph
  traversal, ranking, or governance redesign

## Preconditions

- `Docs/Current-State.md` identifies `M9-P4` as the current work item
- accepted `M9-P1` remains the authority for approved-memory scope meaning
- accepted `M9-P2` remains the authority for durable approved-memory records
  and persona-global profile separation
- accepted `M9-P3` remains the authority for retrieval eligibility and safe
  defaults
- `RFC-0001` remains the authority for contract resolution and activation-time
  trace expectations
- `RFC-0002` remains the runtime data-model floor for
  `activation_contract_snapshot` and `activation_memory_source`
- `RFC-0005` remains the lifecycle authority that keeps approved memory and
  candidate staging distinct

## Grounding Requirements

- local `personakit` CLI grounding for `samwise` with directive `apply-style`
- grounding command:
  `swift run personakit export --root .personakit --no-global --persona samwise --directive apply-style`
- grounding graph:
  `swift run personakit graph --root .personakit --no-global --persona samwise --directive apply-style`
- `README.md`
- `Docs/Current-State.md`
- `Docs/Orbit/Planning/Milestones/M9-Approved-Memory-And-Scoped-Retrieval/README.md`
- `Docs/Orbit/Planning/Milestones/M9-Approved-Memory-And-Scoped-Retrieval/Packet-01-Freeze-Approved-Memory-Scope-Rules.md`
- `Docs/Orbit/Planning/Milestones/M9-Approved-Memory-And-Scoped-Retrieval/Packet-03-Implement-Retrieval-Eligibility-Rules.md`
- `Docs/Orbit/Planning/Milestones/M8-Journaling-And-Memory-Candidate-Review/Milestone-Closeout-Review-Artifact.md`
- `Docs/Orbit/RFCs/RFC-0001-Workspace-Persona-Contract-Resolution-and-Activation-Model.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md`
- accepted `M9-P2` implementation boundary in commit `55dc609`
- accepted `M9-P3` implementation boundary in commit `ec4fb4f`
- live grounding required: `yes`
- PersonaKit MCP grounding allowed: `no`

## Exact Scope

Include:

- durable `activation_contract_snapshot` persistence for resolved contract
  context used by one activation
- durable `activation_memory_source` persistence for approved memory entries
  that were eligible and loaded for one activation
- one repository/runtime-store inspection bundle that loads activation context,
  contract snapshot, agent runs, traced memory sources, traced approved memory
  entries, and minimum candidate ancestry
- minimum lineage projection from `memory_entry.source_memory_candidate_id`
- narrow supporting docs only when needed to keep the packet reviewable

Exclude:

- gateway read routes, Studio UI, or other client-facing trace presentation
- room snapshot or realtime payload redesign beyond the already accepted
  surfaces
- general `memory_link` schema, broader linked-memory traversal, or graph-like
  lineage inspection
- retrieval ranking, semantic search, indexing strategy, or contradiction
  handling
- promotion, demotion, supersession, expiry-policy redesign, or broader
  governance workflow changes
- any change that weakens or redefines the accepted `M9-P3` eligibility posture

## Write Scope

- may edit:
  `Docs/Orbit/Planning/Milestones/M9-Approved-Memory-And-Scoped-Retrieval/`
- may edit:
  `Sources/Features/OrbitServerRuntime/`
- may edit:
  `Tests/Features/OrbitServer/`
- must not edit:
  `Docs/Current-State.md`
- must not edit:
  `Docs/current-state.json`
- must not edit:
  gateway routes, Studio/UI files, realtime transport payloads, or room
  snapshot payload shape
- must not widen into:
  `memory_link`, general lineage traversal, or later governance packets

## Ordered Work

1. Confirm the accepted `M9-P3` eligibility posture remains the governing input
   boundary for any traced memory source.
2. Add the minimum durable runtime records needed to persist activation
   contract context and activation memory sources.
3. Add one repository/runtime-store load surface that returns a deterministic
   activation trace bundle.
4. Add tests for empty trace, eligible traced memory, minimum lineage, and
   ineligible-memory exclusion.
5. Stop before gateway/UI presentation, broader lineage traversal, or
   `memory_link` design.

## Packet 4 Working Contract

### Trace Persistence Posture

- `activation_contract_snapshot` is in scope because trace inspection is not
  honest enough if contract context survives only in transient event payloads
- `activation_memory_source` is in scope only for approved memory entries that
  were already eligible and loaded under accepted `M9-P3` rules
- trace persistence must not bypass, weaken, or reinterpret approved-memory
  eligibility

### First Inspection Surface

- the first inspection surface is store-first only
- repository and runtime-store APIs may load one activation trace bundle
- no gateway route is added in `M9-P4`
- no Studio or operator-facing UI is added in `M9-P4`
- no room snapshot or realtime payload expansion is added in `M9-P4`

### Minimum Lineage Posture

- first-slice lineage means approved-memory entry back to
  `source_memory_candidate_id` only
- approved memory with no candidate ancestry must remain inspectable and simply
  report no source candidate
- `memory_link` is deferred
- broader graph traversal, contradiction, reinforcement, and supersession
  semantics are deferred

### Eligibility Preservation

- `workspace` memory remains traceable only when eligible in the same workspace
- `workspace_persona` memory remains traceable only when eligible for the same
  workspace persona instance in the same workspace
- `persona_global` memory remains traceable only when eligible for the same
  persona template
- `organization` memory remains default-off in this repo posture and must not
  appear in trace records unless a future packet explicitly changes that
  posture
- candidate memory remains ineligible by default and must not appear as a
  traced activation input
- non-active approved-memory records remain ineligible by default and must not
  appear as traced activation input

## Validation And Evidence

- packet note naming the runtime-first, store-first trace posture
- repository/runtime-store tests for contract-snapshot persistence and
  activation-memory-source persistence
- tests for empty trace loading, eligible traced memory loading, minimum
  candidate ancestry, and no-ancestry handling
- proof that traced memory sources still honor the accepted `M9-P3`
  eligibility posture
- one deterministic activation-trace example showing activation context,
  contract context, and approved-memory influence

## Packet 4 Closure Position

- one activation trace bundle can now show which contract and approved memory
  influenced a response
- minimum candidate ancestry is inspectable when present
- approved memory with no candidate ancestry is still inspectable cleanly
- later packets may add gateway/UI presentation or broader lineage only if they
  preserve the accepted trace and eligibility posture

## Open Risks And Review Decisions Needed

- if product review wants operator-facing trace inspection immediately, that
  should be split into a later bounded packet rather than folded into `M9-P4`
- if future lineage work needs richer relationship semantics than
  `source_memory_candidate_id`, that should reopen as a new bounded design
  packet rather than be improvised under this packet
- if operator review needs trace bundles keyed by a broader context than one
  activation id, that should remain a later store/gateway packet

## Failure Dispositions

- `blocked`
  trace inspection cannot be implemented without reopening accepted
  `M9-P2` or `M9-P3` boundaries
- `needs-review`
  the packet is coherent but awaits AJ review before later trace-presentation
  work depends on it
- `grounding-blocked`
  required local PersonaKit grounding or repo-local dossier inputs are not
  available
- `failed`
  the packet depends on gateway/UI work, `memory_link`, broader traversal, or
  eligibility redesign to remain coherent

## Stop Points

- stop if trace persistence begins recording memory that was not eligible and
  loaded under `M9-P3`
- stop if `organization` memory quietly becomes default-on in this repo posture
- stop if the implementation requires gateway/UI work to remain reviewable
- stop if minimum lineage expands into `memory_link`, traversal graphs, or
  governance redesign
- stop if contract snapshot persistence starts redefining resolved contract
  semantics rather than recording them

## Closeout Return Format

- completed or shipped
- evidence produced
- open risks
- review decisions needed
- next recommended packet
