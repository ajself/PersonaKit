# M7 Packet 1: Freeze Workstream Ownership And Contract

Status: Accepted
Packet Id: `M7-P1`
Milestone: `M7`
Execution Owner: `worktree-squad-lead`
Review Personas: `samwise`, `venture-product-steward`, `studio-integration-coordinator`, `studio-coverage-architect`
Last Updated: 2026-03-26

## Header

- status: `done`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Freeze the first-pass workstream ownership and launch contract before `M7`
  starts runtime, UI, or schema work.
- This packet exists now because `M5` and `M6` can now hand forward bounded
  continuity and structured evidence, but `M7` still needs an explicit answer
  to who owns execution lanes and what approvals make a launch legitimate.
- This is the right slice size because it freezes owner authority, handoff
  shape, and review gates without starting workstream runtime records,
  interaction surfaces, or background execution behavior.

## Quality Bar

- every first-cut workstream lane has one named execution owner with authority
  that can be defended from repo-local evidence
- the launch packet makes source context, scope, validation, and closeout
  expectations explicit before work begins
- approval, escalation, and stop-point rules stay visible enough that
  workstreams do not read as hidden autonomy
- later `M7` packets can implement runtime state and surfaces without
  redefining who may own or launch a lane

## Preconditions

- `M5` meeting continuity is stable enough to hand work forward intentionally
- `M6` structured outputs are stable enough to supply bounded context and
  evidence to a later workstream packet
- `M0` still stands on the owner question: `worktree-squad-lead` is approved
  for the first cut of `M7`, with reassessment required if the role broadens
- `RFC-0002` and `RFC-0004` have been reviewed together so ownership and
  runtime boundaries are not inferred ad hoc

## Grounding Requirements

- local `personakit` CLI grounding for `samwise` with directive `apply-style`
- `README.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- `Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/README.md`
- `Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/Product-And-Interaction-Review-Artifact.md`
- `Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/README.md`
- `Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/Product-And-Interaction-Review-Artifact.md`
- `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Decision-Register.md`
- `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Persona-Coverage-Matrix.md`
- `.personakit/Packs/personas/worktree-squad-lead.persona.json`
- live grounding required: `yes`
- PersonaKit MCP grounding allowed: `no`

## Exact Scope

Include:

- the first-cut execution-owner decision for `M7`
- the explicit criteria that would reopen the owner decision in favor of
  `orbit-workstream-runner`
- the required handoff packet shape for launching a bounded workstream lane
- the approval rules, review gates, stop points, and closeout expectations that
  later `M7` packets must preserve

Exclude:

- runtime workstream state, assignment-record, or lifecycle implementation
- UI surfaces for launch, progress, artifacts, or closeout
- schema design, migrations, or API payload definition
- memory, journaling, or later milestone behavior
- hidden autonomous loop design or background consequential execution

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/`
- may create: one packet-local planning artifact inside the `M7` dossier
- must not edit: runtime source paths, `M5` or `M6` dossier files, or later
  milestone dossiers in this packet

## Ordered Work

1. Freeze the owner decision using repo-local evidence instead of implied future
   architecture.
2. Freeze the workstream handoff packet shape that turns discussion context into
   a bounded execution lane.
3. Freeze approval rules, review gates, stop points, and failure dispositions so
   later `M7` packets cannot smuggle in hidden autonomy.

## Validation And Evidence

- updated `M7` milestone README aligned with the first-cut owner decision
- packet note naming the owner decision, reopen criteria, handoff packet shape,
  and deferred items
- explicit review-gate and stop-point language that later `M7` packets must
  preserve

## Packet 1 Closure Position

- `worktree-squad-lead` is sufficient for the first cut of `M7` while
  workstream execution remains a bounded, human-reviewed, worktree-aligned lane
  launched with one explicit handoff packet
- that sufficiency is conditional, not permanent; `orbit-workstream-runner`
  remains an explicit unresolved need if workstreams become a durable
  product-visible execution identity or exceed the worktree-squad contract
- no workstream may launch from a message post or meeting post on implied
  authority alone
- later `M7` packets may add runtime state, launch plumbing, and return
  surfaces, but they must preserve the owner and gate contract frozen here or
  reopen `M7-P1`

## Packet 1 Working Contract

### First-Cut Owner Decision

- `worktree-squad-lead` remains the first-cut execution owner for `M7`
  because repo-local evidence already approves that role for early `M7` work:
  the roadmap, `M0` decision register, and persona coverage matrix all retain
  it as the approved first-cut owner while warning against implicit drift into a
  broader product identity
- the existing persona contract is a match only for bounded, review-heavy
  execution lanes: it already encodes one explicit objective, deterministic
  evidence, approval gates, staff-level review, and explicit coordination with
  Samwise
- this packet does not reinterpret `worktree-squad-lead` as a hidden runtime
  service or a background coordinator; it keeps the role as a visible execution
  owner for one approved lane at a time

### Owner Sufficiency Boundary

- `worktree-squad-lead` is sufficient only when the launched workstream lane:
  - has one explicit objective and source context
  - names one execution owner and one review ring
  - carries explicit write scope, acceptance criteria, and validation ownership
  - runs in an explicitly approved non-main execution lane rather than by
    ambient authority on the source thread
  - returns progress, artifacts, blocked state, and closeout visibly instead of
    asking the operator to infer completion
- if any planned `M7` behavior needs execution that feels ambient,
  continuously backgrounded, or detached from a bounded reviewed lane, this
  packet is no longer enough

### Explicit Reopen Criteria For `orbit-workstream-runner`

- stop and record an unresolved owner gap if a later packet requires a
  product-visible execution identity distinct from a generic delivery lead
- stop and record an unresolved owner gap if workstream ownership no longer maps
  cleanly to explicit, approved execution lanes
- stop and record an unresolved owner gap if the operator would reasonably read
  the owner as an Orbit-native workstream actor rather than a bounded delivery
  lead
- stop and record an unresolved owner gap if multi-lane or long-running routing
  semantics would overstate what the current worktree-squad contract honestly
  covers

### Workstream Handoff Packet Shape

Every launched workstream lane should start from one packet that names all of
the following before execution begins:

- packet identity:
  `packet_id`, status, and reviewer-required state
- source context:
  originating post type and identifier, source thread or meeting reference,
  reason the work should leave discussion, and the accepted context bundle
  carried forward from `M5` or `M6`
- objective boundary:
  goal summary, in-scope work, out-of-scope work, and why the lane is bounded
  enough to execute separately
- ownership and grounding:
  execution owner persona, supporting review personas, approval authority,
  grounding source, and any static-export marker if the lane starts from a
  snapshot rather than live grounding
- execution lane:
  explicit write scope, validation owner, and the approved lane or launch gate
  required before runtime work starts
- acceptance and verification:
  acceptance criteria, validation commands or review evidence, and required
  structured references or artifacts that must remain linked to the source
- stop points and failure:
  required review gates, escalation triggers, blocked and failed states, and
  the rule that scope expansion reopens approval instead of being silently
  absorbed
- return contract:
  required progress updates, artifact-return expectations, explicit closeout
  summary, and the reviewer needed before the lane can be considered complete

### Approval Rules And Review Gates

- no workstream launch is implied by discussion heat, meeting completion, or the
  presence of structured objects alone
- a workstream launch requires explicit operator approval of the owner, scope,
  and review expectations before any execution lane begins
- if `worktree-squad-lead` is the owner, the lane must still remain bounded to
  an explicitly approved non-main execution context rather than inheriting
  ambient authority from the source post
- any material scope expansion, owner reassignment, or gate removal requires a
  new review pass instead of a progress update
- closeout requires explicit validation evidence and an explicit return record;
  quiet inactivity or transcript drift is never sufficient evidence of
  completion

### Stop Points

- stop if one explicit execution owner cannot be named honestly from repo-local
  evidence
- stop if the handoff packet needs hidden autonomy to make sense
- stop if runtime, UI, or schema details are required to explain packet
  ownership or approval semantics
- stop if `M7-P2+` work is being defined here rather than deferred clearly

### Failure Dispositions

- `blocked`
  required owner approval, lane approval, or source context is missing
- `needs-review`
  the packet contract is coherent but not yet approved for downstream runtime
  work
- `grounding-blocked`
  required local PersonaKit grounding or repo-local authority evidence is not
  available
- `failed`
  the launch contract cannot be explained without hidden autonomy or broader
  owner authority than this packet allows

### Explicitly Deferred

- workstream runtime model, records, and lifecycle transitions
- launch plumbing from message posts and meeting posts
- progress and artifact return implementation
- closeout UI and validation mechanics
- any Orbit-native owner persona creation beyond the explicit reopen criteria

## Open Risks And Review Decisions Needed

- the current owner decision is honest only while `M7` stays a bounded execution
  contract; later packets must not quietly turn it into a product-runtime
  identity
- the handoff packet shape is frozen here as a planning contract, not as final
  runtime schema; later packets may implement it differently only if the same
  semantics remain visible
- `M7-P2` must preserve explicit owner and approval semantics when it introduces
  runtime records
- `M7-P3` and `M7-P4` must preserve explicit launch and return contracts when
  they add handoff and progress plumbing

## Closeout Return Format

- owner decision closed or explicitly blocked
- launch packet fields frozen
- approval and review gates named
- open risks
- next recommended packet: `M7-P2`

## AJ Review Outcome

- AJ approved `M7-P1` as the planning baseline for `M7`.
- `worktree-squad-lead` remains accepted for the first cut only within the
  bounded non-`main` execution-lane conditions frozen in this packet.
- `orbit-workstream-runner` remains staged as an explicit reopen condition, not
  an approved new owner for current work.
- `M7-P2` may proceed only if it preserves the owner, handoff, approval, and
  stop-point contract frozen here.
