# M4 Decision Register

Status: Ready For Planning Closeout
Milestone: `M4`
Owner: `orbit-meeting-coordinator`
Last Updated: 2026-03-20

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

The decisions below are the remaining milestone-shaping questions inside that
posture.

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

Recommended default:

- treat `team` as the more durable organizational grouping and `squad` as the
  more focused initiative grouping, with both expanded only through explicit
  coordinator-owned membership data

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

Recommended default:

- keep one minimal role vocabulary and one minimal completion vocabulary that
  cover active, complete, partial, and failed paths without importing full
  meeting governance

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

Recommended default:

- record a compact reason model that ties each participant to the target source,
  role, or membership basis, and show explicit exclusion notes only when they are
  needed to explain the expansion outcome

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

Recommended default:

- require packet-specific examples, one validation and review matrix, and at
  least one explicit exclusion case plus one partial-failure case before runtime
  handoff is considered ready

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
