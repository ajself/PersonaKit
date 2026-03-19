# M0 Decision Register

Status: Accepted
Milestone: `M0`
Owner: `samwise`
Last Updated: 2026-03-18

## Purpose

List the high-impact decisions that must be resolved or explicitly staged before
later milestones can delegate confidently.

Already-frozen stack choices for `M0` through `M3` live in
`Tech-Stack-Posture.md`.

This register is for the remaining high-impact decisions that should not be left
implicit.

## Decision 1. `ProdDoc` Identity

Question:

- should `ProdDoc` remain a product-facing collaborator label, become a formal
  PersonaKit persona, or be renamed to align with an existing persona?

Why it matters:

- `M1` and `M2` both depend on a precise founding-roster identity model

Resolution criteria:

- the answer preserves product clarity in the founding roster
- the answer preserves PersonaKit identity accuracy
- the answer can be used in runtime records and activation traces without
  ambiguity

Resolution:

- AJ approved keeping `ProdDoc` as the product-facing collaborator label mapped
  explicitly to `venture-product-steward` for the first checkpoint
- no formal `ProdDoc` persona is required during `M0`
- revisit formal persona creation only if a later milestone needs a distinct
  authored identity rather than a presentation alias

Delay cost:

- if delayed, `M1` and `M2` cannot honestly claim collaborator accuracy

## Decision 2. `orbit-meeting-coordinator`

Question:

- should this persona be created during `M0` or explicitly staged as a hard
  prerequisite before `M4`?

Why it matters:

- `M4` and `M5` both require trustworthy coordinator behavior

Resolution criteria:

- the persona has a clear job distinct from `samwise`
- the persona can explain participant inclusion and meeting transitions
- the persona's allowed behavior stays reviewable and bounded

Resolution:

- AJ approved staging `orbit-meeting-coordinator` as a hard prerequisite before
  delegating `M4`, `M5`, or coordinator-dependent `M12` work
- do not create the persona during `M0`

Delay cost:

- if left vague, later meeting work may quietly drift into ad hoc orchestration

## Decision 3. `orbit-memory-gardener`

Question:

- should this persona be created during `M0` or staged as a hard prerequisite
  before `M8`?

Why it matters:

- memory governance needs a steward persona before delegation becomes credible

Resolution criteria:

- the persona can represent reviewed learning rather than automatic drift
- the persona can own candidate review and scope discipline
- the persona does not blur into generic product or engineering roles

Resolution:

- AJ approved staging `orbit-memory-gardener` as a hard prerequisite before
  delegating `M8`, `M9`, or `M10`
- do not create the persona during `M0`

Delay cost:

- if unresolved, memory work can become under-governed and persona-blurry

## Decision 4. `orbit-platform-operator` vs `orbit-server-steward`

Question:

- which persona identity should own `M13` operations work?

Why it matters:

- `M13` needs one explicit operations owner for restore, replay, and deployment

Resolution criteria:

- the identity can own operational safety and evidence review
- the name matches the actual long-term product and deployment posture
- the role does not collapse into generic backend engineering

Resolution:

- AJ approved deferring final naming until `M13` is closer
- freeze now that one dedicated operations persona must exist before `M13`
  delegation begins
- do not create either persona during `M0`

Delay cost:

- low for near-term work, high if platform hardening begins without an explicit
  steward

## Decision 5. `orbit-workstream-runner`

Question:

- is `worktree-squad-lead` enough for `M7`, or will Orbit need a dedicated
  product-facing workstream execution identity?

Why it matters:

- `M7` may cross the line from generic delivery mechanics to a first-class Orbit
  product behavior

Resolution criteria:

- whether workstreams remain bounded human-reviewed lanes
- whether workstreams gain product-visible identity and orchestration semantics
- whether current personas become overstretched or misleading

Resolution:

- AJ approved keeping `worktree-squad-lead` for the first cut of `M7`
- reassess whether `orbit-workstream-runner` is needed before `M7`
  implementation begins in earnest

Delay cost:

- low now, but the question must not be answered implicitly during `M7`

## Decision 6. Dossier Freeze Level

Question:

- is the milestone dossier standard stable enough to require across later
  milestones?

Why it matters:

- if the dossier shape stays fluid, later lanes will each improvise their own
  packet standards

Resolution criteria:

- dossiers define quality, packet order, evidence, stop points, and handoff
- later milestones can use the structure without inventing new planning norms

Resolution:

- AJ approved freezing the dossier standard through
  `Docs/Orbit/Planning/Milestones/README.md` plus
  `Docs/Orbit/Planning/Milestones/_Templates/`
- later changes may refine additively, but must not change the meaning of the
  frozen sections

Delay cost:

- medium; weak dossier discipline creates uneven later planning quality

## Rule For Unresolved Decisions

If one of these decisions is not closed, the milestone that depends on it should
be marked `blocked` or `prerequisite-required`, not "ready enough."
