# Taskboard V2 Feature Lock

Status: Parked
Owner: AJ  
Last Reviewed: 2026-03-29

## Purpose

Freeze the expected board-and-card parity feature set for Taskboard v2 after
research is complete and before deeper parity implementation continues.

Historical posture:

- preserved as the approved Taskboard v2 feature-lock decision
- not the current repo-wide execution queue
- current repo-wide priority lives in `Docs/Current-State.md`

## Inputs

1. `Docs/Archive/PersonaKit/Research/taskboard-trello-benchmark.md`
2. `Docs/Archive/PersonaKit/Research/taskboard-trello-gap-matrix.md`
3. `Docs/Archive/PersonaKit/Research/taskboard-trello-image-catalog.md`
4. `Docs/Archive/PersonaKit/Plans/taskboard-v2-initiative-plan.md`
5. `Docs/Archive/PersonaKit/Plans/taskboard-trello-parity-execution-charter.md`

## Feature Lock Decision

Gate status: `approved`

Approver: AJ

Decision date: `2026-03-07`

## Current Parity Bar

Taskboard is not trying to match all of Trello. For this initiative, the bar is
`Board + Card Parity`:

1. a human user should be able to use the board and card-detail flows and
   reasonably think the experience is Trello-like
2. parity claims stop if blocker findings remain
3. broader view parity remains deferred

## Must Have (Current Initiative Scope)

1. `P0` Label model on tickets (create/edit/remove + visible on cards/detail)
2. `P0` Due-date model on tickets (set/clear + visible status)
3. `P0` Checklist model on tickets (item create/edit/complete/delete)
4. `P0` Board-level filtering (labels, owner/member, due-date state, keyword)
5. `P1` Keyboard speed-path baseline for core lane/ticket actions
6. `P1` Search UI/API across tickets and lanes
7. `P2` Rich assignment model beyond free-text owner
8. `P2` Markdown description/comments on ticket detail surface
9. `P2` Board/card interaction polish sufficient to clear parity review for the
   locked board/card scope

## Deferred

1. `P3` Table view
2. `P3` Dashboard view
3. `P3` Map view
4. `P3` Calendar view
5. `P3` Custom fields
6. Broader Trello ecosystem and multi-view parity

## Explicit Non-Goals For This Build

1. Full Trello parity across every view and integration.
2. Multi-user real-time collaboration.
3. Expanding the delegated commit experiment beyond the current initiative scope.

## Acceptance Contract

1. No Taskboard parity claim is valid while blocker findings remain.
2. Changes to the locked scope require AJ approval and a dated update entry.
3. Deferred items must remain explicitly deferred unless AJ reopens them.
4. Snapshot and red-pen review evidence are required for user-facing parity
   claims.

## Milestone Mapping

1. `P0`: staffing readiness and parity-contract wiring
2. `P1`: research + lock reset
3. `P2`: board interaction parity
4. `P3`: card detail parity
5. `P4`: visual + accessibility parity
6. `P5`: AI-operable parity
7. `P6`: closeout and retrospective

## Update Log

| Date | Change | Author | Approval |
| --- | --- | --- | --- |
| 2026-03-07 | Created feature-lock template | Samwise | Pending |
| 2026-03-07 | Added proposed must/should/later set from research gap matrix | Samwise | Pending AJ decision |
| 2026-03-07 | Approved feature lock and priority ordering (`P0` through `P3`) | AJ + Samwise | Approved |
| 2026-03-07 | Landed `P2` depth baseline (multi-assignee model, description/comments, lane WIP/collapse) | Samwise | Implementation completed; AJ review pending |
| 2026-03-08 | Reframed active lock around `Board + Card Parity`, added current staffing/parity milestones, and promoted search/assignment/markdown depth into the active locked scope | Samwise | Pending AJ review |
