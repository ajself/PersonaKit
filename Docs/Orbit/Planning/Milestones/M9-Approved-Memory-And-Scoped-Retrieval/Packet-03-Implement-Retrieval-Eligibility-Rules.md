# M9 Packet 3: Implement Retrieval Eligibility Rules

Status: Current
Packet Id: `M9-P3`
Milestone: `M9`
Execution Owner: `orbit-memory-gardener`
Review Personas: `venture-product-steward`, `studio-coverage-architect`, `architectural-editor`
Last Updated: 2026-03-30

## Header

- status: `ready-for-dev`
- operator or reviewer required: `yes`
- packet type: `implementation`

## Objective

- Implement the smallest honest retrieval-eligibility slice that allows future
  activations to consider approved memory only through explicit, scoped rules.
- Preserve the accepted `M9-P1` scope meanings exactly and build only on the
  approved-memory runtime surface accepted in `M9-P2`.
- Keep this packet focused on eligibility, exclusions, and deterministic safe
  defaults rather than trace UI, broader lineage inspection, or governance
  redesign.

## Quality Bar

- retrieval eligibility is explicit for `workspace`, `workspace_persona`,
  `persona_global`, and optional `organization`
- candidate memory remains ineligible by default
- cross-scope retrieval stays blocked unless the frozen model explicitly allows
  it
- retrieval posture is deterministic and reviewable from code and tests
- the packet does not smuggle in trace UI, ranking, promotion, or contradiction
  work

## Preconditions

- `Docs/Current-State.md` identifies `M9-P3` as the current work item
- accepted `M8` closeout remains the authoritative handoff boundary into `M9`
- accepted `M9-P1` remains the authority for approved-memory scope meaning
- accepted `M9-P2` remains the authority for the durable approved-memory record
  surface and persona-global profile separation
- `RFC-0001` remains the authority for activation-time retrieval eligibility
  and ordering posture
- `RFC-0002` remains the runtime data-model floor for activation trace and
  memory-source records
- `RFC-0005` remains the lifecycle authority that keeps candidates separate
  from approved memory

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
- `Docs/Orbit/Planning/Milestones/M8-Journaling-And-Memory-Candidate-Review/Milestone-Closeout-Review-Artifact.md`
- `Docs/Orbit/RFCs/RFC-0001-Workspace-Persona-Contract-Resolution-and-Activation-Model.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md`
- accepted `M9-P2` implementation boundary in commit `55dc609`
- live grounding required: `yes`
- PersonaKit MCP grounding allowed: `no`

## Exact Scope

Include:

- activation-time eligibility rules for approved memory scopes
- deterministic default blocking of candidate memory from activation input
- deterministic default blocking of cross-scope retrieval that is outside the
  frozen scope contract
- the minimum runtime changes needed to resolve eligible approved memory for an
  activation and record that posture in tests
- narrow supporting docs only when needed to keep the packet reviewable

Exclude:

- trace UI or operator-facing activation-memory-source presentation
- broader lineage traversal, linked-memory traversal, or graph-like inspection
- retrieval ranking, scoring, semantic search, or indexing strategy
- promotion, demotion, contradiction, supersession, expiry, or linked-memory
  workflow semantics
- governance redesign, review workflow redesign, or new operator policy
  surfaces
- broader runtime/client/UI work not required for eligibility resolution

## Write Scope

- may edit:
  `Docs/Orbit/Planning/Milestones/M9-Approved-Memory-And-Scoped-Retrieval/`
- may edit:
  `Docs/Current-State.md`
- may edit:
  `Docs/current-state.json`
- may edit:
  `Sources/Features/OrbitServerRuntime/`
- may edit:
  `Tests/Features/OrbitServer/`
- must not edit:
  accepted `M8` packet files or RFCs
- must not widen into:
  Studio UI, trace UI, or later milestone dossiers

## Ordered Work

1. Confirm the accepted `M9-P1` scope contract and the accepted `M9-P2`
   approved-memory record boundary.
2. Freeze the first implementation posture for which approved-memory scopes are
   eligible versus ineligible during activation.
3. Implement the narrow runtime logic and tests needed to enforce that posture
   deterministically.
4. Stop before trace presentation, broader lineage, or governance redesign.

## Packet 3 Working Contract

### Boundary From Accepted `M9-P1`

- `workspace` memory may be considered only for that same workspace
- `workspace_persona` memory may be considered only for that same workspace
  persona instance in that same workspace
- `persona_global` memory may be considered as separate persona-profile memory
  for the same persona template and must not mutate authored persona
  definitions
- `organization` memory remains optional and default-off unless the deployment
  explicitly supports it

### Boundary From Accepted `M9-P2`

- approved memory is now a durable runtime artifact separate from candidates
- persona-global memory is now represented through a separate profile surface
- candidate-to-approved lineage is preserved minimally through durable record
  linkage
- `M9-P3` should build on that persistence surface rather than reopening record
  shape design

### First Retrieval Eligibility Posture

- approved `workspace` memory is eligible only when the activation workspace
  matches the memory workspace
- approved `workspace_persona` memory is eligible only when both the activation
  workspace and resolved workspace persona instance match
- approved `persona_global` memory is eligible only when the resolved persona
  template matches
- approved `organization` memory is ineligible by default in the current repo
  until an explicit deployment posture is added
- candidate memory remains ineligible by default
- archived, superseded, expired, deferred, rejected, and otherwise non-active
  records remain ineligible by default

### Retrieval Order Posture

- preserve the RFC-0001 ordering posture as the semantic floor
- do not turn this packet into a ranking or search-system packet
- if implementation needs richer ranking to seem coherent, stop and reopen
  packet scope rather than improvising

### Guardrails Preserved For Later Packets

- eligibility is separate from trace presentation
- eligibility is separate from broader lineage or traversal inspection
- eligibility is separate from promotion or contradiction workflow semantics
- activation-memory-source UI remains a later packet even if the runtime starts
  recording enough state to support it

## Validation And Evidence

- updated current-state authority aligned with `M9-P3` as the current packet
- packet note naming the exact first eligibility posture and explicit defaults
- tests proving eligible versus ineligible retrieval paths for the supported
  scopes
- tests proving candidate memory is excluded from activation input by default
- tests proving organization memory remains default-off in this repo posture

## Packet 3 Closure Position

- approved memory eligibility is now explicit and deterministic for the
  supported scopes
- candidate memory is still excluded from future reasoning by default
- the repo has a reviewable baseline for later activation-memory-source and
  trace inspection work
- later `M9` packets may add trace and lineage inspection only if they preserve
  the accepted eligibility posture

## Open Risks And Review Decisions Needed

- if product review wants `organization` memory enabled in this repo posture,
  that should be decided explicitly before retrieval code depends on it
- if real implementation needs a richer retrieval source-kind model than the
  current records expose, that should be handled as a bounded follow-on within
  `M9-P3` rather than widened into UI or lineage work
- if RFC-0001 ordering proves too coarse for implementation, that should be
  called out explicitly instead of hidden behind search heuristics

## Failure Dispositions

- `blocked`
  the accepted `M9-P1` and `M9-P2` boundaries are not sufficient to implement
  retrieval eligibility without reopening earlier packets
- `needs-review`
  the packet is coherent but awaits AJ review before later `M9` trace work
  depends on it
- `grounding-blocked`
  required local PersonaKit grounding or repo-local dossier inputs are not
  available
- `failed`
  the packet depends on trace UI, broader lineage, promotion semantics, or
  ranking/indexing behavior to remain coherent

## Stop Points

- stop if candidate memory begins influencing activation by default
- stop if scope meaning must be redefined to implement eligibility
- stop if persona-global retrieval starts mutating authored persona definitions
- stop if `organization` memory quietly becomes default-on in this repo
- stop if the work widens into trace UI, broader lineage inspection, ranking,
  semantic search, promotion, contradiction handling, or governance redesign

## Closeout Return Format

- completed or shipped
- evidence produced
- open risks
- review decisions needed
- next recommended packet
