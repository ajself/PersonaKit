# M7 Packet 3: Freeze Handoff From Discussion To Execution

Status: Accepted
Packet Id: `M7-P3`
Milestone: `M7`
Execution Owner: `worktree-squad-lead`
Review Personas: `samwise`, `venture-product-steward`, `studio-integration-coordinator`, `studio-coverage-architect`
Last Updated: 2026-03-27

## Header

- status: `done`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Freeze the first-pass handoff contract that turns a message post or meeting
  post into a linked workstream post without hiding authority or failure state.
- This packet exists now because `M7-P1` already froze who may own a workstream
  lane and `M7-P2` already froze what runtime records a workstream is, but Orbit
  still needs one explicit answer to how discussion intentionally becomes
  execution.
- This is the right slice size because it freezes launch eligibility, carried
  context, and failure visibility without starting progress-return behavior,
  UI design, or implementation work.

## Quality Bar

- a handoff starts only from explicit source conditions rather than discussion
  heat or hidden coordinator magic
- the source post remains durable and inspectable whether handoff succeeds,
  blocks, or fails
- the launched workstream receives enough carried context to execute inside the
  accepted `M7-P1` and `M7-P2` boundaries without reconstructing source intent
- later `M7` packets can implement handoff plumbing without relitigating launch
  authority, source lineage, or failure visibility

## Preconditions

- `M7-P1` is accepted and remains the governing owner, approval, and stop-point
  contract
- `M7-P2` is accepted and remains the governing runtime-model contract
- `M5` continuity rules remain the baseline for preserving origin discussion
  and visible failure handling
- `RFC-0004` remains the authority for coordinator-proposed or
  coordinator-triggered workstream handoff behavior
- `RFC-0002` remains the authority for linked post continuity and partial
  creation visibility

## Grounding Requirements

- local `personakit` CLI grounding for `samwise` with directive `apply-style`
- `README.md`
- `Packet-01-Freeze-Workstream-Ownership-And-Contract.md`
- `Packet-02-Freeze-Workstream-Runtime-Model.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- `Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/README.md`
- `Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/Packet-01-Freeze-Meeting-Trigger-Rules.md`
- `Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/README.md`
- `Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md`
- live grounding required: `yes`
- PersonaKit MCP grounding allowed: `no`

## Exact Scope

Include:

- source-post eligibility rules for workstream handoff
- the required carried context from source discussion into the launched
  workstream
- the launch output contract tying source post, linked workstream post, and
  initial runtime state together
- the blocked, failed, and partial-creation visibility rules for handoff
- the explicit boundary between handoff creation and later progress/artifact
  return behavior

Exclude:

- workstream runtime-record semantics already frozen in `M7-P2`
- progress updates, artifact return, or closeout rendering
- final event-payload design, API shape, or schema details
- hidden background execution helpers or autonomous loop behavior
- any `M7-P4+`, `M8`, or memory-policy work

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/`
- may create: one packet-local planning artifact inside the `M7` dossier
- must not edit: runtime source paths, `M5` or `M6` dossier files, or later
  milestone dossiers in this packet

## Ordered Work

1. Freeze the source conditions that justify handoff into a workstream.
2. Freeze the launch packet payload and minimum created runtime records.
3. Freeze blocked, failed, and partial-creation handling so later packets do
   not imply execution started when it did not.

## Validation And Evidence

- updated `M7` milestone README aligned with `M7-P3` as the active planning
  packet
- packet note naming handoff eligibility, carried context, launch outputs, and
  deferred items
- explicit failure-visibility language preserving the accepted `M5` and `M7-P1`
  trust boundaries

## Packet 3 Closure Position

- a linked workstream handoff remains a follow-up outcome from discussion, not a
  hidden side effect of group interaction
- message posts and meeting posts may hand off into workstream posts, but they
  do not surrender their own durability or continuity when they do
- successful handoff creates one explicitly linked workstream post carrying the
  minimum execution packet context needed by the accepted `M7-P1` and `M7-P2`
  contracts
- later `M7` packets may implement the mechanics of launch, progress, and
  artifact return, but they must preserve the handoff boundary frozen here or
  reopen `M7-P3`

## Packet 3 Working Contract

### Eligible Source Posts

- the first slice allows handoff only from:
  - `post_type = message`
  - `post_type = meeting`
- the source discussion must have reached a concrete execution step rather than
  remaining in open-ended debate
- the next action must belong in a workstream more than in continued source
  discussion
- the source must already have enough explicit context to satisfy the accepted
  `M7-P1` launch packet floor without inventing missing scope or authority
- a workstream handoff is never implied solely by:
  - target class
  - roster size
  - meeting completion by itself
  - the mere presence of structured objects

### Handoff Initiation Contract

- the Meeting Coordinator or equivalent routing layer may propose or trigger a
  linked workstream post as a follow-up outcome
- that routing layer does not own workstream execution itself
- every handoff still requires explicit operator approval of owner, scope, and
  review expectations before the launched workstream may begin execution
- if approval is missing, the correct result is a visible non-launch posture,
  not a speculative `pending` workstream

### Carried Source Context

Every successful first-slice handoff must carry forward:

- source post identifier and source post type
- source thread reference, and meeting-post reference when the source is a
  meeting
- one concise handoff reason explaining why the next step belongs in a
  workstream
- requested outcome and execution scope
- explicit in-scope and out-of-scope boundaries
- proposed execution owner and required review personas
- validation owner and minimum acceptance criteria
- any structured references, decisions, or artifacts that are required context
  for the launched workstream rather than optional source history

### Launch Output Contract

- a successful handoff creates:
  - one linked `workstream` post
  - one workstream thread
  - one initial `workstream_state` record
  - the required `post_link` back to the source post
  - the minimum `post_participant` and `workstream_assignment` records needed
    to show intended ownership and review visibility
- the launched workstream starts in `draft` or `pending`, never directly in
  `in_progress`, until the accepted execution-lane approval conditions are
  satisfied
- the source post remains durable and inspectable after launch
- the source path must be able to show:
  - that a workstream was launched
  - which workstream post was created
  - what requested outcome was handed forward

### Source Continuity And Visibility

- handoff does not replace the source post or source thread
- the source post should retain visible continuity to:
  - the linked workstream post
  - handoff reasoning
  - blocked or failed handoff state when launch did not succeed
- if the source is a meeting post, the meeting may still complete successfully
  even when the workstream handoff blocks or fails, as long as that state is
  visible
- if the source remains active after handoff, the workstream still counts as a
  follow-up outcome rather than proof that the source discussion must remain
  open

### Blocked, Failed, And Partial-Creation Rules

- `blocked` means handoff did not create a workstream because a required
  approval, owner assignment, source context field, or review gate was missing
- `failed` means handoff creation was attempted but did not complete
  successfully
- on blocked handoff:
  - preserve the source discussion
  - record the blocked state visibly
  - do not imply that execution started
- on failed handoff creation:
  - preserve the source discussion
  - record the failure visibly
  - do not imply that execution started successfully
  - allow retry from the preserved source context
- on partial creation:
  - partial creation must not leave an unlinked orphan workstream post silently
  - if a workstream post survives a partial failure, it must remain visibly
    linked to the source and visibly marked as not successfully launched
  - the operator must be able to tell whether retry should repair the partial
    object or create a fresh handoff

### Boundary To Later Packets

- `M7-P3` freezes only how discussion becomes a linked workstream
- `M7-P2` remains the authority for the runtime record boundary once the
  workstream exists
- `M7-P4` owns progress and artifact return behavior after launch
- `M7-P5` owns validation and proof that lane discipline remains intact

### Explicitly Deferred

- exact UI surfaces for launch controls and failure states
- exact event taxonomy and payloads for launch attempts or retries
- automated retry behavior or background reconciliation flows
- progress-stream and artifact-return behavior after launch
- any launch from one workstream post into another beyond the already accepted
  dependency-link meaning in `M7-P2`

## Open Risks And Review Decisions Needed

- the first-slice choice to allow only message and meeting posts as handoff
  sources is intentionally narrow; any broader source set should reopen review
- the `draft` versus `pending` launch-start rule depends on operator approval
  staying explicit; later packets must not skip directly into execution
- partial-creation repair policy is intentionally limited to visibility and
  retryability here; deeper repair mechanics should be deferred rather than
  improvised
- `M7-P4` must preserve the source continuity bar rather than treating launch as
  a thread-disappearing transition

## Failure Dispositions

- `blocked`
  required source context, owner approval, or review gate is missing
- `needs-review`
  the handoff contract is coherent but not yet accepted for downstream work
- `grounding-blocked`
  required local PersonaKit grounding or repo-local authority evidence is not
  available
- `failed`
  the handoff model still depends on hidden authority or ambiguous failure
  semantics to make sense

## Stop Points

- stop if handoff eligibility cannot be explained without hidden coordinator
  policy
- stop if the source discussion would lose continuity when handoff blocks or
  fails
- stop if `M7-P4+`, UI, schema, or hidden-autonomy behavior is required to make
  the handoff contract coherent
- stop if handoff would imply execution started without satisfying the accepted
  `M7-P1` approval contract

## Closeout Return Format

- handoff eligibility frozen or explicitly blocked
- carried source context and launch outputs named
- blocked and failure visibility rules named
- open risks
- next recommended packet: `M7-P4`

## AJ Review Outcome

- AJ approved `M7-P3` as the handoff baseline for `M7`.
- Workstream handoff remains an explicit follow-up outcome from `message` and
  `meeting` posts rather than a hidden side effect of discussion.
- The first-slice carried-context floor, `draft` or `pending` launch-start
  rule, and blocked/failed/partial-creation visibility rules are accepted for
  the current milestone slice.
- `M7-P4` may proceed only if it preserves the accepted `M7-P1`, `M7-P2`, and
  `M7-P3` contracts rather than weakening launch authority, source continuity,
  or failure visibility.
