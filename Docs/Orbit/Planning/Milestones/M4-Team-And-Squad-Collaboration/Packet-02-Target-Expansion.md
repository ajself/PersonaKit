# M4 Packet 2: Target Expansion

Status: Ready For Planning Closeout
Packet Id: `M4-P2`
Milestone: `M4`
Execution Owner: `orbit-meeting-coordinator`
Review Personas: `venture-product-steward`, `studio-coverage-architect`
Last Updated: 2026-03-20

## Header

- status: `needs-review`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Define the deterministic target-expansion contract that turns a team or squad
  target into explicit participants and visible reasons.
- This packet exists now because trust depends on knowing who was asked before
  inline collaboration can feel believable.
- This is the right slice size because it isolates expansion logic from reply
  rendering and later meeting behavior.

## Quality Bar

- the same target yields the same participants under the same workspace state
- inclusion and exclusion reasons are visible enough to defend
- expansion results are inspectable without provider-owned magic

## Preconditions

- `M4-P1` froze team and squad semantics
- `orbit-meeting-coordinator` is approved and available through `PHR-0009`
- the operator-visible trace posture from `M3` is trusted

## Grounding Requirements

- `.personakit/Sessions/orbit-meeting-coordinator-review.session.json`
- `.personakit/Sessions/orbit-meeting-coordinator-delivery.session.json`
- `Packet-01-Group-Structure-Assumptions.md`
- `Validation-And-Review-Matrix.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- live grounding required: `yes`

## Exact Scope

Include:

- the expansion input and output contract
- inclusion and exclusion reason categories
- operator-visible examples for successful and negative expansion cases

Exclude:

- inline reply sequencing or rendering
- promoted meeting behavior
- heuristic ranking or provider-specific routing logic

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/`
- may create: expansion examples and review notes inside the `M4` dossier
- must not edit: runtime collaboration code or later milestone dossiers in this
  packet

## Ordered Work

1. Define the participant-expansion contract and the minimum explanation shape.
2. Add examples that cover inclusion, exclusion, and empty-or-blocked cases.
3. Return explicit validation expectations needed by `M4-P5`.

## Validation And Evidence

- target expansion examples for at least one team and one squad
- one explicit exclusion example
- review note confirming the reasoning stays operator-visible

## Packet 2 Proposed Closure

### Expansion Input Contract

- target expansion resolves against one active workspace and one explicit target
  at a time
- the first-slice contract keeps the current runtime addressing shape of
  `addressedTargetKind` plus `addressedTargetReferenceID`, with supported kinds
  limited to `collaborator`, `team`, and `squad`
- direct collaborator targets resolve from one workspace persona reference in
  the active workspace and do not perform group-member expansion
- team and squad targets resolve only from the persisted workspace model
  defined by `RFC-0003`, specifically the active workspace's `team`, `squad`,
  `workspace_persona`, and `workspace_persona_membership` records
- heuristic ranking, provider-owned routing, compound multi-target requests, and
  ad hoc roster builders remain deferred from this packet

### Expansion Output Contract

- every expansion emits a visible `resolved target` summary with target kind,
  target reference, and active workspace scope
- every successful expansion emits an `included participants` list of workspace
  persona instances ordered deterministically by `workspace_persona.id` until a
  later packet explicitly introduces a different presentation order
- trust-relevant exclusions emit an `excluded participants` list ordered the
  same way, rather than disappearing silently
- every participant-level reason uses one structured shape:
  `reasonCategory`, `sourceTargetKind`, `sourceTargetReferenceID`, and a short
  operator-visible explanation derived from those fields
- every expansion also emits one explicit status:
  `resolved`, `blocked`, or `empty`
- an expansion that includes some members and excludes or cannot resolve others
  still remains `resolved`; the exclusions explain degraded membership
  resolution without introducing a second `partial` state at the routing layer

### First-Slice Reason Categories

- inclusion categories:
  `direct_target`, `team_membership`, `squad_membership`
- exclusion categories:
  `persona_unavailable`, `membership_unresolved`
- blocked or empty expansion outcomes:
  `missing_or_ambiguous_target`, `empty_group`
- first-slice exclusions should appear only when a persisted target member was
  materially skipped or could not be resolved; non-members should not generate
  synthetic exclusion rows

### Packet 2 Examples

- team target example:
  `Founding Group` resolves in the active workspace through the persisted
  `team` plus `workspace_persona_membership` records and includes `samwise`
  plus `proddoc` with `team_membership` reasons sourced from
  `addressedTargetReferenceID=founding-group`
- squad target example:
  `Command Center Feedback Squad` resolves through the persisted `squad` plus
  `workspace_persona_membership` records and includes only the workspace
  personas assigned to that initiative with `squad_membership` reasons
- exclusion example:
  `Founding Group` includes `samwise` and `proddoc`, but one archived workspace
  persona member is emitted under `excluded participants` with
  `reasonCategory=persona_unavailable` rather than disappearing from the review
  surface
- blocked or empty example:
  an addressed squad target that is missing, ambiguous, or resolves to zero
  eligible members emits `status=blocked` or `status=empty` with no participant
  activations and one visible routing-failure note in the conversation path

### Validation Expectations Returned To `M4-P5`

- validation should prove that the same workspace state and target reference
  always produce the same included and excluded participant sets in the same
  order
- validation should include one happy-path team expansion, one happy-path squad
  expansion, one exclusion case, and one blocked-or-empty case
- validation evidence should show the participant-level reason fields as
  operator-visible artifacts rather than debugger-only logs

### Open Risks And Review Decisions Needed

- AJ still needs to approve whether `workspace_persona.id` is sufficient as the
  deterministic ordering key for this slice or whether another explicit
  structural order should be named before runtime work begins
- AJ still needs to approve whether `persona_unavailable` and
  `membership_unresolved` are enough exclusion categories for the first slice
- `M4-P3` must decide how the expansion summary appears relative to inline
  replies without reopening the target-expansion contract
- later packets may introduce richer narrowing or ranking policy only through
  explicit reviewable rules, not hidden coordinator heuristics

## Failure Dispositions

- `blocked`
  `M4-P1` decisions are still unresolved
- `needs-review`
  AJ needs to review the reason model before runtime work begins
- `grounding-blocked`
  required coordinator grounding is unavailable
- `failed`
  expansion remains opaque or inconsistent after the packet work

## Stop Points

- stop if participant selection cannot be explained without hidden heuristics
- stop if exclusions cannot be shown clearly when they materially affect trust

## Closeout Return Format

- expansion contract defined
- examples and evidence produced
- open risks
- review decisions needed
- next recommended packet: `M4-P3`
