# M7 Packet 2: Freeze Workstream Runtime Model

Status: Accepted
Packet Id: `M7-P2`
Milestone: `M7`
Execution Owner: `worktree-squad-lead`
Review Personas: `samwise`, `venture-product-steward`, `studio-integration-coordinator`, `studio-coverage-architect`
Last Updated: 2026-03-26

## Header

- status: `done`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Freeze the first-pass runtime model for workstream posts before `M7` begins
  launch plumbing, progress return, UI, or schema work.
- This packet exists now because `M7-P1` already froze who may own a workstream
  lane and how a launch must be approved, but later packets still need one
  explicit answer to what runtime records a workstream actually is.
- This is the right slice size because it defines the durable record boundary
  and lifecycle semantics without starting handoff creation, artifact-return
  behavior, or implementation work.

## Quality Bar

- a workstream is modeled as one clear post-based runtime object instead of a
  note, thread convention, or hidden sidecar process
- state, roster, and assignment records are explicit enough that progress and
  closeout can later be surfaced without reconstructing hidden history
- the runtime model preserves the accepted `M7-P1` owner and gate contract
  rather than softening it through ambiguous state semantics
- later `M7` packets can implement launch, progress, and validation behavior
  without relitigating what records exist or which record owns which meaning

## Preconditions

- `M7-P1` is accepted and remains the governing owner and approval contract
- `M5` continuity is stable enough to provide explicit origin-post context
- `M6` structured-object rules remain the attachment boundary for evidence and
  artifacts
- `RFC-0002` remains the authoritative runtime model baseline for posts,
  threads, links, subtype state, and participant records
- `RFC-0004` remains the boundary for workstream proposal or trigger behavior,
  not workstream execution itself

## Grounding Requirements

- local `personakit` CLI grounding for `samwise` with directive `apply-style`
- `README.md`
- `Packet-01-Freeze-Workstream-Ownership-And-Contract.md`
- `AJ-Closeout-Review-Artifact.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- `Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/README.md`
- `Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/Product-And-Interaction-Review-Artifact.md`
- `Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/README.md`
- `Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/Product-And-Interaction-Review-Artifact.md`
- `Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md`
- live grounding required: `yes`
- PersonaKit MCP grounding allowed: `no`

## Exact Scope

Include:

- the required runtime record set for a workstream post
- the first-pass linkage rule from origin post to workstream post
- the first-pass participant and assignment model for a workstream post
- the lifecycle-state contract and field semantics later packets must preserve
- the explicit runtime boundary between workstream state, thread activity,
  structured attachments, and later launch/progress surfaces

Exclude:

- launch-path implementation from message posts or meeting posts
- progress-stream, artifact-return, or closeout UI behavior
- final SQL schema, migrations, API shape, or event payload details
- hidden execution helpers, autonomous loops, or background job behavior
- any `M7-P3+`, `M8`, or memory-policy work

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/`
- may create: one packet-local planning artifact inside the `M7` dossier
- must not edit: runtime source paths, `M5` or `M6` dossier files, or later
  milestone dossiers in this packet

## Ordered Work

1. Freeze the minimum runtime record set a workstream post requires.
2. Freeze the lifecycle and assignment semantics those records carry.
3. Freeze the explicit deferred list so later `M7` packets do not smuggle launch
   plumbing, UI, schema, or autonomy into this slice.

## Validation And Evidence

- updated `M7` milestone README aligned with `M7-P2` as the active planning
  packet
- packet note naming the runtime records, lifecycle semantics, and deferred
  items
- explicit record-boundary language tying `M7-P2` back to the accepted `M7-P1`
  owner and approval contract

## Packet 2 Closure Position

- a workstream remains a `post_type = workstream` object inside Orbit's
  post-first runtime model rather than a separate root entity
- every workstream post owns one thread, one subtype state record, one explicit
  participant roster, and zero or more workstream-specific assignments
- workstream continuity remains explicit through post links back to source
  posts; launch behavior may be implemented later, but source lineage must not
  be implicit
- later `M7` packets may implement launch, progress, artifact return, and
  validation behavior, but they must preserve the runtime record boundary frozen
  here or reopen `M7-P2`

## Packet 2 Working Contract

### First-Slice Runtime Record Set

- every workstream exists as one `post` with `post_type = workstream`
- every workstream post owns one `thread`; progress notes, reviewer comments,
  and closeout discussion remain attached to that thread rather than scattering
  into a separate work log
- every workstream post carries one `workstream_state` record as the detailed
  execution lifecycle source of truth
- every named participant on the workstream carries one `post_participant`
  record
- every workstream-specific role assignment carries one
  `workstream_assignment` record layered on top of the base post roster
- every workstream post must support explicit `post_link` continuity to its
  origin post and any later dependency links to other posts
- workstream lifecycle and notable transitions must remain traceable through
  `post_event`, but this packet does not freeze the full event taxonomy

### Source Linkage And Post Boundary

- the workstream runtime object belongs to Orbit's post model, not to the
  source discussion thread alone
- a workstream launched from a message post or meeting post must preserve one
  explicit origin link back to that source context
- the first-cut link posture is:
  - source message or meeting post to launched workstream post:
    `link_type = follow_up`
  - workstream-to-workstream prerequisite relationships:
    `link_type = dependency`
  - meeting promotion remains `M5` territory and should continue using the
    promotion-specific boundary from that dossier rather than being redefined
    here
- `M7-P2` freezes link meaning only after a workstream post exists; `M7-P3`
  still owns how and when that linked post is created from source discussion

### Workstream Post Floor

- `post.title` should be explicit for every first-slice workstream post even
  though the base post model keeps title nullable across post types
- `post.status` remains a coarse cross-type presentation field and must not be
  treated as the detailed execution lifecycle source of truth
- `workstream_state.requested_outcome` is required and remains the concise
  statement of what completion should achieve
- `workstream_state.workstream_type` is limited in the first slice to the RFC
  floor:
  `research`, `design`, `implementation`, `review`, `release`, and
  `documentation`
- later packets may add richer metadata only if these baseline meanings remain
  intact

### Participant And Assignment Contract

- source-thread or meeting participants do not automatically become workstream
  participants by continuity alone; workstream participation must be explicit
- every assigned workstream participant must appear in both:
  - the base `post_participant` roster
  - a `workstream_assignment` record when that participant has a workstream role
- first-slice assignment roles remain the RFC floor:
  `owner`, `contributor`, `reviewer`, and `executor`
- every first-slice workstream must have exactly one active `owner`
  assignment so the accepted `M7-P1` owner contract stays visible at runtime
- reviewers may be represented as assigned participants even when they are not
  currently producing thread activity; review visibility should not depend on
  whether a reviewer has already spoken
- no hidden executor or background actor may produce consequential workstream
  progress without appearing in the runtime participant and assignment records

### Lifecycle And Status Contract

- `workstream_state` remains the detailed lifecycle source of truth for a
  workstream post
- first-slice statuses keep the RFC floor and mean:
  - `draft`
    the workstream object exists as a proposed execution unit, but execution is
    not yet approved to begin
  - `pending`
    the workstream is approved to launch, but active execution has not started
  - `idle`
    the workstream remains open and resumable, but no active execution is
    underway and no explicit blocker is currently asserted
  - `in_progress`
    work is actively underway inside the approved lane
  - `blocked`
    the workstream cannot currently progress because an explicit blocker exists
  - `completed`
    the requested outcome is judged complete and closed out explicitly
  - `failed`
    the workstream ended without reaching its requested outcome
  - `cancelled`
    the workstream was intentionally stopped without claiming completion
- `requested_by_participant_type`, `requested_by_participant_id`, and
  `requested_at` are required for every workstream state record
- `started_by_participant_type`, `started_by_participant_id`, and `started_at`
  remain nullable until the workstream actually enters `in_progress`
- `completed_at` should be populated for terminal states:
  `completed`, `failed`, and `cancelled`
- `failure_reason` is required for `failed` and remains optional otherwise
- blocked-state explanation must remain explicit through runtime-visible context
  such as thread messages or post events; it must not become a silent status bit

### Thread, Event, And Attachment Boundary

- the workstream thread is the durable place for authored progress notes,
  clarifications, and closeout discussion
- `post_event` is the durable place for system-visible lifecycle transitions and
  trace reconstruction
- structured outputs such as notes, decisions, references, and artifacts remain
  attached to the workstream post through the accepted `M6` attachment model
  rather than a new workstream-only artifact system
- `M7-P2` freezes only the runtime ownership of those surfaces; `M7-P4` still
  owns how progress and artifacts return to Orbit in operator-facing form

### Explicitly Deferred

- launch-path creation rules from source posts and meetings
- exact event taxonomy and event-payload structure
- progress-stream rendering, artifact-return rendering, and closeout UI
- final schema, migration, storage-layout, and API decisions
- any automation or hidden background execution helper

## Open Risks And Review Decisions Needed

- the `follow_up` origin-link choice for first-cut workstream launches is the
  smallest coherent runtime link posture, but `M7-P3` must preserve that meaning
  instead of inventing a second source-link model
- the difference between `pending` and `idle` is now intentionally explicit;
  later packets must not collapse them without reviewable reason
- the model now requires one explicit workstream owner assignment; later packets
  must not allow ownerless execution lanes or hidden executor progress
- `M7-P4` must preserve the accepted `M6` attachment boundary rather than
  creating a separate workstream-only artifact store

## Failure Dispositions

- `blocked`
  required upstream runtime semantics or packet-one owner rules are still unclear
- `needs-review`
  the runtime model is coherent but not yet accepted for downstream work
- `grounding-blocked`
  required local PersonaKit grounding or repo-local runtime authority evidence
  is unavailable
- `failed`
  the runtime model still depends on hidden launch or progress behavior to make
  sense

## Stop Points

- stop if the runtime model cannot stay post-based without creating a separate
  root workstream system
- stop if explicit owner, participant, or assignment visibility disappears
- stop if launch-path, UI, schema, or hidden-autonomy design is required to make
  the runtime model coherent
- stop if `M7-P3+` work is being defined here rather than deferred clearly

## Closeout Return Format

- runtime record set frozen or explicitly blocked
- lifecycle and assignment semantics named
- deferred items named
- open risks
- next recommended packet: `M7-P3`

## AJ Review Outcome

- AJ approved `M7-P2` as the runtime-model baseline for `M7`.
- Workstreams remain accepted as post-based runtime objects with explicit
  thread, state, participant, assignment, link, and event boundaries.
- The `follow_up` source-link posture, explicit `pending` versus `idle`
  distinction, and single active owner-assignment rule are accepted for the
  first slice.
- `M7-P3` may proceed only if it preserves the accepted `M7-P1` and `M7-P2`
  contracts rather than weakening owner visibility, link meaning, or lifecycle
  semantics.
