# M0 Sprint Plan

Status: Draft
Milestone: `M0`
Orchestrator: `samwise`
Last Updated: 2026-03-18

## Purpose

Break `M0` into completion-based sprints so an AI lane can work deliberately,
stay anchored in PersonaKit personas, and reach milestone closeout without
rushing through unresolved decisions.

These are not calendar sprints.
They are bounded execution stages with explicit owners, outputs, and stop points.

## Sprint Model

- one primary execution persona per sprint
- one review ring per sprint
- one active sprint in flight at a time
- all execution work runs in a dedicated non-main worktree
- a sprint closes only when its evidence is reviewable, not when a document exists

## North Star

`M0` succeeds when later Orbit construction lanes can begin with:

- one stable planning scaffold
- one stable handoff packet shape
- one frozen early stack posture
- one frozen worktree execution rule
- one honest persona coverage map
- one AJ-approved unresolved-decision posture

## Sprint Sequence

### Sprint 1. Scaffold And Handoff Discipline

Status:

- ready

Execution owner:

- `samwise`

Review ring:

- `architectural-editor`
- `venture-product-steward`

Goal:

- freeze the dossier standard and delegated handoff contract so later lanes do
  not improvise execution mechanics

Primary outputs:

- validated `README.md`
- validated `Delegated-Handoff-Packet-Template.md`
- validated `Quality-Bar.md`
- sprint closeout note for handoff readiness

Exit signal:

- later milestones can start from one packet standard without thread
  reconstruction

### Sprint 2. Tech Posture And Worktree Freeze

Status:

- planned; blocked on Sprint 1 closeout

Execution owner:

- `architectural-editor`

Review ring:

- `samwise`
- `venture-product-steward`

Goal:

- hard-freeze the early Orbit stack posture and worktree execution rule so AI
  lanes build Orbit instead of redefining it

Primary outputs:

- validated `Tech-Stack-Posture.md`
- any required touch-ups to `Evidence-And-Exit-Criteria.md`
- sprint closeout note for stack and worktree fidelity

Exit signal:

- `M1`, `M2`, and `M3` can no longer treat stack or execution-boundary choices
  as open implementation decisions

### Sprint 3. Persona Coverage And Identity Closure

Status:

- planned; blocked on Sprint 1 and Sprint 2 closeout

Execution owner:

- `venture-product-steward`

Review ring:

- `samwise`
- `architectural-editor`

Goal:

- close or explicitly stage the identity and persona decisions that later
  milestones depend on

Primary outputs:

- validated `Persona-Coverage-Matrix.md`
- validated `Decision-Register.md`
- explicit `ProdDoc` recommendation packet
- explicit missing-persona staging packet

Exit signal:

- no later milestone is left with hidden owner ambiguity, and the founding-roster
  identity posture is sharp enough for AJ review

### Sprint 4. AJ Closeout And Release Gate

Status:

- planned; blocked on Sprint 1, Sprint 2, and Sprint 3 closeout

Execution owner:

- `samwise`

Review ring:

- `venture-product-steward`
- `architectural-editor`

Goal:

- convert the sprint outputs into one AJ decision packet that either closes `M0`
  or names the remaining blockers honestly

Primary outputs:

- milestone closeout packet
- AJ review packet
- explicit go or no-go recommendation for `M1` and `M2`
- explicit note that active construction is authorized through `M3` only and
  pauses afterward until AJ restarts it

Exit signal:

- AJ can approve, reject, or narrow the release gate for post-`M0` construction

## Critical Path

The sprint order is intentionally strict:

1. handoff discipline before stack posture freeze
2. stack posture freeze before persona and identity closure
3. persona and identity closure before AJ closeout

Do not run Sprint 3 or Sprint 4 as if Sprint 1 and Sprint 2 were informal.

## Worktree Rule

All sprints should execute in a dedicated non-main worktree.

That worktree may be used for repo-wide planning edits that materially support
`M0`, but the sprint does not authorize unrelated cleanup or speculative product
work.

## Review And Stop Rules

- stop any sprint if a later sprint dependency is being answered implicitly
- stop any sprint if persona anchoring becomes blended or fuzzy
- stop any sprint if work begins redefining Orbit product or stack direction
- stop Sprint 4 if AJ review materials are still weak or contradictory

## Construction Gate After `M0`

If `M0` closes successfully, active Orbit construction may proceed into `M1`,
`M2`, and `M3`.

After `M3`, construction pauses until AJ explicitly restarts work beyond that
point.
