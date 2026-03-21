# M5 Packet 1: Freeze Meeting Trigger Rules

Status: Planned
Packet Id: `M5-P1`
Milestone: `M5`
Execution Owner: `orbit-meeting-coordinator`
Review Personas: `samwise`, `venture-product-steward`, `studio-interaction-quality-lead`
Last Updated: 2026-03-21

## Header

- status: `planned`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Freeze the first-pass rules that decide whether a group discussion stays
  inline, enters lightweight meeting mode, or promotes into a dedicated meeting
  post.
- This packet exists now because `M5` should not begin with hidden mode-change
  heuristics.
- This is the right slice size because it sharpens the transition contract
  without starting runtime state or continuity-link implementation.

## Quality Bar

- inline discussion remains the explicit default posture
- lightweight meeting mode and promoted meeting posts have distinct, inspectable
  trigger conditions
- operator inspection and override requirements are visible before runtime work
  starts

## Preconditions

- `M4` inline group collaboration is trusted and closed tightly enough for
  follow-on work
- `M3` canonical runtime and linking semantics remain the persistence baseline
- `RFC-0002` and `RFC-0004` have been reviewed together

## Grounding Requirements

- `.personakit/Sessions/orbit-meeting-coordinator-review.session.json`
- `README.md`
- `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/README.md`
- `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/Packet-07-M4-Closeout-And-Remaining-Work.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- live grounding required: `yes`

## Exact Scope

Include:

- first-pass trigger rules for staying inline versus entering lightweight
  meeting mode
- explicit promotion conditions for creating a linked meeting post
- operator inspection, override, and failure-visibility requirements for
  transition decisions

Exclude:

- meeting-state or meeting-member runtime records
- continuity-link implementation or structured meeting outputs
- workstream handoff semantics or memory promotion behavior

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/`
- may create: packet-local examples or trigger notes inside the `M5` dossier
- must not edit: runtime product implementation paths or later milestone
  artifacts in this packet

## Ordered Work

1. Freeze the default inline rule and the concrete conditions that justify
   lightweight meeting mode.
2. Freeze the concrete conditions that justify a promoted meeting post instead
   of inline or lightweight coordination.
3. Record the operator-facing inspection, override, and failure surfaces needed
   before `M5-P2`.

## Validation And Evidence

- updated packet note aligned with `M5` milestone scope
- explicit trigger matrix for inline, lightweight meeting, and promoted meeting
- explicit operator override and promotion-failure expectations
- explicit deferred list for later `M5` packets

## Packet 1 Working Contract

### Default Posture

- group interaction begins inline in the originating post thread by default
- staying inline is correct when scope is small, no formal meeting state is
  needed, and a lightweight multi-participant exchange is sufficient
- no team, squad, or other target class auto-promotes or defaults to
  lightweight meeting mode in `v1`; any such policy would reopen this packet
  explicitly

### Lightweight Meeting Mode

- lightweight meeting mode remains inside the originating thread
- it is appropriate when structured coordination is needed but a dedicated
  meeting post would be excessive
- the visible reason for entering this mode should be tied to explicit
  coordination needs such as participant roles, sequencing, or completion
  tracking rather than a hidden heuristic score

### Promoted Meeting Post

- promotion creates a linked meeting post with durable independent identity
- promotion is appropriate when the interaction needs a dedicated participant
  list, summary or lifecycle state, or follow-up coordination that should stay
  clearly separable from the origin thread
- promotion failure must stay visible on the originating discussion path and
  leave the source thread durable

### Operator Inspection And Override

- the operator must be able to inspect why the coordinator kept the discussion
  inline, entered lightweight meeting mode, or promoted to a meeting post
- the operator must remain able to steer or override the transition instead of
  accepting hidden coordinator-only policy
- transition reasoning should stay bounded to Orbit-owned surfaces and not
  depend on provider-specific inference labels

### Trigger Matrix

- stay inline:
  small-scope discussion, no formal meeting state needed, no separate meeting
  identity required
- enter lightweight meeting mode:
  structured coordination is needed in-thread, but a separate meeting post
  would add unnecessary ceremony
- promote to meeting post:
  durable independent meeting identity, dedicated participant list, explicit
  summary or lifecycle state, or clearly separable follow-up coordination is
  needed

### Explicitly Deferred

- automatic policy scoring or rank-based trigger systems
- workstream handoff rules
- structured meeting outputs beyond the minimum trigger boundary
- memory candidate or artifact promotion behavior

### Open Risks And Review Decisions Needed

- `RFC-0004` leaves open whether some team or squad invocations might eventually
  always promote or default to lightweight meeting mode; `M5-P1` closes that
  question for `v1` as "no"
- `M5-P2` must preserve the trigger contract when introducing durable
  meeting-state records
- `M5-P3` must keep continuity visible without reopening the inline-versus-
  promoted boundary

## Failure Dispositions

- `blocked`
  required upstream milestone trust or runtime assumptions are not accepted
- `needs-review`
  the trigger boundary is defined but not yet accepted for follow-on runtime
  work
- `grounding-blocked`
  required coordinator grounding is unavailable
- `failed`
  trigger rules cannot be frozen without smuggling in later-milestone work

## Stop Points

- stop if inline, lightweight, and promoted meeting states cannot be explained
  distinctly
- stop if operator override disappears behind coordinator-only heuristics
- stop if this packet starts defining workstream or memory behavior

## Closeout Return Format

- trigger rules closed or explicitly staged
- operator inspection and override surfaces named
- open risks
- review decisions needed
- next recommended packet: `M5-P2`
