# M4 Decision Register

Status: Closed for M4 Closeout
Milestone: `M4`
Owner: `orbit-meeting-coordinator`
Last Updated: 2026-03-21

## Purpose

List the high-impact decisions that should be resolved or explicitly staged
before `M4` runtime work begins.

This register should keep team-and-squad collaboration from turning into
coordinator-by-drift.

## Fixed Posture Already Chosen

The following are no longer open for `M4` unless AJ explicitly reopens them:

- `orbit-meeting-coordinator` is the real milestone owner
- `M4` is limited to inline group collaboration with visible coordinator
  expansion
- `M5` meeting promotion and continuity remain out of scope here
- `M7` workstream handoff behavior remains out of scope here
- `M4-P1` through `M4-P5` are packetized scope checkpoints inside one `M4`
  lane/worktree by default; they do not imply separate branches or worktrees
  unless AJ explicitly approves extra isolation
- the coordinator sessions remain candidate-state until runtime evidence exists

The decisions below are the milestone-shaping questions that must either close
or remain explicitly staged inside that posture.

`M4-P1` now proposes working closures for Decisions 1 and 2, `M4-P2` now
proposes a working closure for Decision 5, `M4-P3` now proposes a working
closure for Decision 3, `M4-P4` now proposes a working closure for Decision 4,
and `M4-P5` now proposes a working closure for Decision 6, but they still
require AJ review before later runtime-facing packets rely on them as accepted
milestone law.

## Decision 1. First-Pass Team And Squad Meaning

Question:

- what stable first-pass meaning should `team` and `squad` carry in Orbit before
  any runtime packet starts?

Why it matters:

- target expansion cannot be deterministic if the group types themselves are
  vague

Resolution criteria:

- aligns with `RFC-0003` structural ownership
- gives `M4-P1` one inspectable starting meaning for each group type
- avoids reopening broader organization design beyond the first collaboration
  slice

Resolution:

- AJ-closed `M4-P1` resolution:
  `team` means a durable workspace-defined coordination group with a stable
  remit and explicit membership over workspace persona instances
- AJ-closed `M4-P1` resolution:
  `squad` means a focused initiative-bound coordination group with explicit
  workspace persona membership and a narrower, more temporary objective than a
  team
- AJ-closed `M4-P1` resolution:
  both group types expand only through the persisted workspace model from
  `RFC-0003`, specifically `team`, `squad`, `workspace_persona`, and
  `workspace_persona_membership`; those records are the source of truth rather
  than the `RFC-0002` runtime collaboration store or a separate
  coordinator-local group surface, and runtime participation under `RFC-0004`
  is derived from them rather than mutating them
- AJ-closed `M4-P1` resolution:
  the existing `Founding Group` remains the seeded first team example in the
  current Orbit surface

Recommended default:

- treat `team` as the more durable organizational grouping and `squad` as the
  more focused initiative grouping, with both expanded only through persisted
  workspace-model membership data defined by `RFC-0003`

Decision owner:

- `orbit-meeting-coordinator` and `venture-product-steward`, with AJ review

Must close before:

- `M4-P1`

Delay cost:

- high; target expansion stays mushy if the group concepts stay fuzzy

Downstream impact:

- `M4-P1`
- `M4-P2`
- `M5`

## Decision 2. First Addressing Syntax And Inspection Surface

Question:

- what target forms and operator inspection path are explicitly supported in the
  first `M4` slice?

Why it matters:

- routing trust depends on both the target language and the operator's ability to
  inspect what Orbit interpreted

Resolution criteria:

- the supported forms are explicit and small
- the inspection surface is visible enough for trust review
- the first slice avoids speculative roster or target syntax complexity

Resolution:

- AJ-closed `M4-P1` resolution:
  the first slice supports explicit direct collaborator targets plus explicit
  team and squad targets resolved from persisted workspace-model group records
  defined by `RFC-0003`
- AJ-closed `M4-P1` resolution:
  the current seeded team target is `Founding Group`, which stays visible in
  the existing composer and expands only through its explicit persisted
  membership record; the initial seeded membership contains AI workspace
  personas only, not the human operator, and later visible collaborators do not
  join by roster drift
- AJ-closed `M4-P1` resolution:
  membership inspection begins from the visible workspace roster and named
  group-target surface, while expansion outcomes and reasons stay in the same
  conversation path through routing summaries and activation trace surfaces
- AJ-closed `M4-P1` resolution:
  freeform natural-language group parsing, ad hoc roster builders, hidden
  coordinator-only roster surfaces, and richer meeting controls remain deferred

Recommended default:

- support explicit team and squad targets first, and make the expansion output
  visible in the same interaction path rather than inventing a separate hidden
  roster surface

Decision owner:

- `orbit-meeting-coordinator` and `samwise`, with AJ review

Must close before:

- `M4-P1`

Delay cost:

- high; every later packet depends on knowing what the operator is allowed to ask
  for

Downstream impact:

- `M4-P1`
- `M4-P2`
- `M4-P3`

## Decision 3. Inline Reply Versus Meeting Promotion Boundary

Question:

- what stays inline during `M4`, and what is explicitly deferred to `M5` meeting
  promotion and continuity?

Why it matters:

- `M4` loses its shape if every useful collaboration path silently becomes a
  meeting feature

Resolution criteria:

- keeps inline collaboration believable on its own
- preserves a clean handoff to `M5`
- avoids requiring continuity payloads that belong to later milestones

Resolution:

- AJ-closed `M4-P3` resolution:
  successful group-targeted interaction remains in the origin post thread for
  the first `M4` slice and does not create a linked meeting post or leave the
  current discussion surface
- AJ-closed `M4-P3` resolution:
  the coordinator may use `lightweightMeeting` as the response-form label for a
  group-targeted inline exchange, but in this slice that means thread-scoped
  coordination metadata only rather than a separate meeting root, continuity
  package, or dedicated participant surface
- AJ-closed `M4-P3` resolution:
  one visible inline routing or expansion summary should appear before or with
  participant replies, and each participant reply remains an attributed
  workspace persona message in the same thread
- AJ-closed `M4-P3` resolution:
  promoted meeting posts, meeting continuity artifacts, post links, and durable
  meeting summaries remain explicitly deferred to `M5`

Recommended default:

- keep collaboration inline by default and capture only enough visible state to
  explain participation, attribution, and completion; treat promoted meeting
  records and continuity packages as `M5` work

Decision owner:

- `orbit-meeting-coordinator` and `studio-interaction-quality-lead`, with AJ
  review

Must close before:

- `M4-P3`

Delay cost:

- high; inline reply design becomes unstable if the promotion boundary is still
  implied

Downstream impact:

- `M4-P3`
- `M5`
- `M12`

## Decision 4. Participation Role And Completion Vocabulary

Question:

- what is the smallest role and state vocabulary that still makes group exchange
  status understandable?

Why it matters:

- participation trust depends on seeing what Orbit expects from each participant
  and whether the exchange is complete, partial, or still active

Resolution criteria:

- roles are explicit without overdesigning meeting governance
- completion states support partial failure visibly
- the vocabulary is small enough to keep the first slice legible

Resolution:

- AJ-closed `M4-P4` resolution:
  the first-slice visible role vocabulary is `contributor` plus `reviewer`
  only; deferred RFC roles such as `observer`, `summarizer`, and `facilitator`
  remain out of scope until Orbit can surface them without importing meeting
  governance into the inline path
- AJ-closed `M4-P4` resolution:
  `reviewer` names review-oriented participation intent rather than guaranteed
  reply order; sequencing remains independent unless a later packet closes a
  stricter ordering policy
- AJ-closed `M4-P4` resolution:
  first-slice participant-level visible states are `pending`, `replied`, and
  `failed`
- AJ-closed `M4-P4` resolution:
  first-slice exchange-level visible states are `active`, `completed`,
  `partial`, and `failed`
- AJ-closed `M4-P4` resolution:
  Packet 2 routing outcomes such as `blocked` and `empty` remain pre-exchange
  expansion results rather than becoming completion states in the group reply
  model
- AJ-closed `M4-P4` resolution:
  a partial exchange stays visibly `partial` whenever at least one
  reply-expected participant succeeds and at least one reply-expected
  participant fails

Recommended default:

- keep one minimal visible role vocabulary and one minimal visible state
  vocabulary that cover pending, replied, active, completed, partial, and
  failed paths without importing full meeting governance

Decision owner:

- `orbit-meeting-coordinator`, `studio-interaction-quality-lead`, and
  `studio-coverage-architect`, with AJ review

Must close before:

- `M4-P4`

Delay cost:

- medium-high; state and trust reviews get weaker if the vocabulary stays vague

Downstream impact:

- `M4-P4`
- `M4-P5`
- `M5`

## Decision 5. Inclusion And Exclusion Reason Shape

Question:

- what minimum explanation fields must Orbit show so inclusion and exclusion
  reasoning is useful instead of theatrical?

Why it matters:

- trust is not gained merely by saying "these are the participants"; the operator
  needs reviewable reasons

Resolution criteria:

- reasons are concise, stable, and not model-rhetoric dependent
- exclusions are visible when they materially affect trust
- the explanation shape supports validation examples

Resolution:

- AJ-closed `M4-P2` resolution:
  target expansion emits one visible `resolved target` summary, one explicit
  `status` of `resolved`, `blocked`, or `empty`, one deterministic `included
  participants` list, and a trust-relevant `excluded participants` list when
  persisted members were materially skipped or unresolved
- AJ-closed `M4-P2` resolution:
  an expansion that includes some members and excludes or cannot resolve others
  still remains `resolved`; exclusions explain degraded membership resolution
  rather than introducing a second `partial` routing state
- AJ-closed `M4-P2` resolution:
  the first-slice deterministic ordering key is `workspace_persona.id` for both
  included and excluded participant lists until a later packet explicitly names
  a separate presentation order
- AJ-closed `M4-P2` resolution:
  every participant-level reason uses the same structured fields:
  `reasonCategory`, `sourceTargetKind`, `sourceTargetReferenceID`, and a short
  operator-visible explanation derived from those fields
- AJ-closed `M4-P2` resolution:
  first-slice inclusion categories are `direct_target`, `team_membership`, and
  `squad_membership`; first-slice exclusion categories are
  `persona_unavailable` and `membership_unresolved`
- AJ-closed `M4-P2` resolution:
  `missing_or_ambiguous_target` and `empty_group` are expansion-status outcomes
  with visible routing-failure notes, not synthetic participant exclusions

Recommended default:

- record a compact reason model that ties each participant to the target source
  and membership basis, keep the participant ordering deterministic, and show
  explicit exclusion notes only when they are needed to explain the expansion
  outcome

Decision owner:

- `orbit-meeting-coordinator` and `venture-product-steward`, with AJ review

Must close before:

- `M4-P2`

Delay cost:

- medium-high; reason visibility becomes hand-wavy if the explanation contract is
  not named up front

Downstream impact:

- `M4-P2`
- `M4-P5`

## Decision 6. Trust Evidence Required Before Runtime Handoff

Question:

- what evidence package must exist before any runtime-facing `M4` packet can be
  treated as trustworthy?

Why it matters:

- the milestone should not advance on optimism or a single happy-path demo

Resolution criteria:

- evidence covers expansion, inline replies, visible state, and trust review
- validation owners are explicit
- AJ can review the packet set without reconstructing missing expectations

Resolution:

- AJ-closed `M4-P5` resolution:
  runtime-facing `M4` work requires one packet-complete dossier set, one
  target-expansion example set, one inline interaction example set, one
  role-and-state evidence set, and one named review artifact set
- AJ-closed `M4-P5` resolution:
  the named review passes before runtime handoff are scope and owner review,
  product and interaction review, validation review, and AJ closeout review
- AJ-closed `M4-P5` resolution:
  the evidence package must include at least one explicit exclusion case, one
  blocked-or-empty case, one completed inline exchange, one partial-failure
  inline exchange, and one fully failed inline exchange
- AJ-closed `M4-P5` resolution:
  implementer explanation, debugger-only proof, or one happy-path demo is not
  sufficient evidence for runtime trust claims
- AJ-closed `M4-P5` resolution:
  if any packet claim lacks named evidence, the milestone remains
  `needs-review` or `blocked` rather than `ready enough`

Recommended default:

- require packet-specific examples, one named review artifact per required pass,
  and at least one explicit exclusion case, one blocked-or-empty case, one
  partial-failure case, and one failed-exchange case before runtime handoff is
  considered ready

Decision owner:

- `samwise` and `studio-coverage-architect`, with AJ review

Must close before:

- `M4-P5`

Delay cost:

- medium; weak evidence posture will keep the milestone feeling risky even if the
  implementation looks plausible

Downstream impact:

- `M4-P5`
- `M5`

## Rule For Unresolved Decisions

If one of these decisions is not closed, the dependent packet should be marked
`blocked`, `needs-review`, or `prerequisite-required`, not `ready enough`.
