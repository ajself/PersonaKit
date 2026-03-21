# M4 Packet 3: Inline Group Reply Flow

Status: Ready For Planning Closeout
Packet Id: `M4-P3`
Milestone: `M4`
Execution Owner: `orbit-meeting-coordinator`
Review Personas: `venture-product-steward`, `studio-interaction-quality-lead`
Last Updated: 2026-03-20

## Header

- status: `needs-review`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Define how group collaboration stays inline, attributable, and readable inside
  the existing discussion surface.
- This packet exists now because `M4` needs a trustworthy inline path before
  meeting promotion can be justified later.
- This is the right slice size because it keeps reply behavior separate from
  participation state and trust-proof work.

## Quality Bar

- group replies remain attributable inside the current thread
- the operator can understand the exchange without thinking it secretly became a
  meeting
- inline collaboration stays bounded and legible

## Preconditions

- `M4-P1` and `M4-P2` are coherent enough to define who was asked and why
- `orbit-meeting-coordinator` is approved and available through `PHR-0009`
- current post and thread attribution from earlier milestones remains trusted

## Grounding Requirements

- `.personakit/Sessions/orbit-meeting-coordinator-review.session.json`
- `.personakit/Sessions/orbit-meeting-coordinator-delivery.session.json`
- `Packet-02-Target-Expansion.md`
- `Decision-Register.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- live grounding required: `yes`

## Exact Scope

Include:

- inline group reply sequencing expectations
- attribution rules for participant replies
- the explicit boundary between inline collaboration and later meeting promotion

Exclude:

- promoted meeting posts
- continuity packages or meeting summaries
- workstream handoff behavior

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/`
- may create: inline-flow examples and product-review notes inside the `M4`
  dossier
- must not edit: `M5` meeting-continuity artifacts or runtime implementation
  paths in this packet

## Ordered Work

1. Define how group replies stay inline and attributable inside the current post
   or thread model.
2. Record the exact boundary that keeps this packet out of `M5`.
3. Return product and interaction review expectations for the inline path.

## Validation And Evidence

- inline group reply walkthrough examples
- explicit note describing what stays deferred to `M5`
- interaction review questions aligned with the validation matrix

## Packet 3 Proposed Closure

### Inline Reply Contract

- successful team and squad targets remain in the origin post thread for the
  first `M4` slice; they do not create a linked meeting post or leave the
  current discussion surface
- the coordinator may label the response form as `lightweightMeeting` when a
  group target expands, but in this slice that label means inline
  thread-scoped coordination metadata only, not a separate meeting root,
  separate participant surface, or continuity package
- the inline path should emit one visible routing or expansion summary in the
  same thread before or with participant replies so the operator can tell who
  was asked and why
- participant replies remain normal attributed workspace persona messages in the
  same thread, each tied back to the triggering user message and its resolved
  target context
- the coordinator may add thread-local post events or equivalent coordination
  metadata to preserve rationale and state, but it must not collapse the
  exchange into one merged coordinator-authored answer

### Boundary From `M5`

- `M4` inline collaboration does not create a dedicated meeting identity,
  linked meeting post, continuity package, meeting summary artifact, or
  post-link handoff
- `M4` inline collaboration may show lightweight coordination cues in the
  current thread, but participant lifecycle, promotion, and durable meeting
  continuity remain deferred to `M5`
- completion can be hinted through inline coordination traces in this packet,
  but the explicit role and completion vocabulary still closes in `M4-P4`
- any interaction that only makes sense with a separate meeting surface,
  durable meeting summary, or promoted follow-up artifact is out of scope here

### Packet 3 Examples

- inline team example:
  AJ targets `Founding Group`, Orbit shows one inline routing summary for the
  `founding-group` expansion, then `samwise` and `proddoc` reply as separate
  attributed thread messages in the same discussion
- inline squad example:
  AJ targets `Command Center Feedback Squad`, Orbit keeps the exchange in the
  same thread, shows the resolved squad rationale, and the selected workspace
  personas reply independently without a separate meeting post
- partial-arrival example:
  the expansion summary appears first, one participant replies immediately, and
  another remains pending; the thread still reads as one bounded inline group
  exchange rather than a silently promoted meeting
- out-of-scope example:
  if the operator needs a dedicated participant list, durable meeting summary,
  or a separately resumable coordination artifact, the interaction belongs to
  `M5` promotion rather than this inline packet

### Product And Interaction Review Expectations

- a reviewer should be able to identify the triggering user message, the
  resolved group target, and each participant reply without reconstructing hidden
  coordinator state
- the inline exchange should still read like the current thread became
  multi-participant, not like the product secretly jumped to another mode
- the coordinator rationale should remain visible enough to build trust without
  taking over the conversation as a synthetic narrator
- participant replies should stay attributable even when arrival order differs
  from the expansion ordering

### Open Risks And Review Decisions Needed

- AJ still needs to approve whether one inline routing summary is sufficient for
  first-slice trust or whether a second explicit coordinator note is needed once
  replies begin arriving
- `M4-P4` must define how inline pending, complete, partial, and failed states
  are shown without reopening the `M4` versus `M5` boundary
- later packets may add richer sequencing or facilitator behavior only through
  explicit reviewable policies, not by turning the inline path into implicit
  meeting governance

## Failure Dispositions

- `blocked`
  expansion behavior is still unclear enough that inline replies would be
  misleading
- `needs-review`
  AJ needs to approve the inline boundary before any runtime-facing reply work
- `grounding-blocked`
  required coordinator grounding is unavailable
- `failed`
  the packet cannot keep inline replies legible without quietly depending on
  meeting behavior

## Stop Points

- stop if the inline path only makes sense by importing `M5` continuity behavior
- stop if reply attribution becomes weaker than the single-participant baseline

## Closeout Return Format

- inline reply contract defined
- examples and evidence produced
- open risks
- review decisions needed
- next recommended packet: `M4-P4`
