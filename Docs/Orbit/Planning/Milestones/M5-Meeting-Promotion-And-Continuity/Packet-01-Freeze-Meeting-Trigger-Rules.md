# M5 Packet 1: Freeze Meeting Trigger Rules

Status: Done - AJ Closed Out
Packet Id: `M5-P1`
Milestone: `M5`
Execution Owner: `orbit-meeting-coordinator`
Review Personas: `samwise`, `venture-product-steward`, `studio-interaction-quality-lead`
Last Updated: 2026-03-21

## Header

- status: `done`
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

## Packet 1 Closure Position

- `M5-P1` closes the `v1` trigger contract for planning review with inline as
  the default, lightweight meeting mode as an explicit in-thread exception, and
  promoted meeting posts as a narrower, separately justified outcome
- no team, squad, or other target class auto-promotes or defaults to
  lightweight meeting mode in `v1`; reopening this packet is required before
  any class-based default may be introduced
- later `M5` packets may add runtime state, links, or outputs, but they must
  preserve this trigger boundary rather than redefining it
- any future trigger proposal that depends on structured-output depth or
  workstream follow-through belongs to a later packet and must not be smuggled
  into `M5-P1`

## Packet 1 Working Contract

### Default Posture

- group interaction begins inline in the originating post thread by default
- staying inline is correct when scope is small, no formal meeting state is
  needed, and a lightweight multi-participant exchange is sufficient
- team, squad, and ad hoc targeting do not change that default by themselves in
  `v1`
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
- lightweight meeting mode requires an operator-visible trigger reason; target
  class, roster size, or generic collaboration intent alone is not sufficient

### Promoted Meeting Post

- promotion creates a linked meeting post with durable independent identity
- promotion is appropriate when the interaction needs a dedicated participant
  list, summary or lifecycle state, or follow-up coordination that should stay
  clearly separable from the origin thread
- promotion must be justified by that separable meeting need itself, not by a
  team or squad label and not by anticipated workstream behavior
- promotion failure must stay visible on the originating discussion path and
  leave the source thread durable
- promotion failure visibility must include the attempted transition, the fact
  that promotion did not complete, and whether the system remained inline or
  was explicitly overridden into lightweight coordination
- the default `v1` fallback after promotion failure is to remain inline; moving
  into lightweight meeting mode after failure requires explicit operator
  override

### Operator Inspection And Override

- the operator must be able to inspect why the coordinator kept the discussion
  inline, entered lightweight meeting mode, or promoted to a meeting post
- the operator must be able to inspect the minimum trigger facts behind that
  decision from the originating discussion path even when a promoted meeting
  post is also created
- the operator must remain able to steer or override the transition instead of
  accepting hidden coordinator-only policy
- the operator must be able to see promotion-attempt failures without losing
  the source-thread context needed to retry, force inline, or force lightweight
  mode
- transition reasoning should stay bounded to Orbit-owned surfaces and not
  depend on provider-specific inference labels

### Trigger Matrix

- stay inline:
  explicit default for every target class; use when scope is small, no formal
  meeting state is needed, and no separate meeting identity is required
- enter lightweight meeting mode:
  use only when structured coordination is needed in-thread and a separate
  meeting post would add unnecessary ceremony; team, squad, or ad hoc targeting
  alone is not enough
- promote to meeting post:
  use only when durable independent meeting identity, dedicated participant
  list, explicit summary shell or lifecycle state, or clearly separable
  follow-up coordination is needed; anticipated workstream follow-through alone
  is not enough

### Explicitly Deferred

- automatic policy scoring or rank-based trigger systems
- workstream handoff rules
- structured meeting outputs beyond the minimum trigger boundary
- memory candidate or artifact promotion behavior
- any class-based default that would force lightweight meeting mode or
  auto-promotion for teams, squads, or other target classes

## AJ Closeout Decision

- Packet 1 is now considered closed for `M5` planning with the `v1` meeting
  trigger boundary frozen.
- Follow-on `M5` runtime packets may proceed only if they preserve inline as
  the default, keep class-based auto-promotion out of scope, and keep
  inspection, override, and promotion-failure visibility explicit.

### Open Risks And Review Decisions Needed

- `RFC-0004` leaves open whether some team or squad invocations might eventually
  always promote or default to lightweight meeting mode; `M5-P1` closes that
  question for `v1` as "no"
- exact operator-facing UI and event payload shape for inspection, override, and
  promotion-failure visibility still belongs to later runtime packets and
  review, even though the visibility requirement is now explicit
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
