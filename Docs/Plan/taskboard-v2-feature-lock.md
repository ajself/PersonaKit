# Taskboard V2 Feature Lock

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Freeze the expected Trello-like feature set for Taskboard v2 after research is
complete and before implementation begins.

## Inputs

1. `Docs/Research/taskboard-trello-benchmark.md`
2. `Docs/Research/taskboard-trello-gap-matrix.md`
3. `Docs/Research/taskboard-trello-image-catalog.md`
4. `Docs/Plan/taskboard-v2-initiative-plan.md`

## Feature Lock Decision

Gate status: `approved`

Approver: AJ

Decision date: `2026-03-07`

## Must Have (V2 Build Scope)

1. `P0` Label model on tickets (create/edit/remove + lane-level visibility).
2. `P0` Due-date model on tickets (set/clear + visible status).
3. `P0` Checklist model on tickets (item create/edit/complete/delete).
4. `P0` Board-level filtering (labels, owner/member, due-date state, keyword).
5. `P1` Keyboard speed-path baseline for core lane/ticket actions.

## Should Have (V2.1 Candidate)

1. `P1` Search UI/API across tickets and lanes.
2. `P2` Rich assignment model beyond free-text owner.
3. `P2` Markdown description/comments on ticket detail surface.

## Later / Deferred

1. `P3` Table view.
2. `P3` Dashboard view.
3. `P3` Map view.
4. `P3` Calendar view.
5. `P3` Custom fields.

## Explicit Non-Goals For This Build

1. Full Trello parity across every view and integration.
2. Multi-user real-time collaboration.

## Acceptance Contract

1. No Taskboard feature implementation starts before this document is approved.
2. Changes to `Must Have` require AJ approval and a dated update entry.
3. Deferred items must include rationale.

## Milestone Mapping

1. `TV2-M2A`:
   - P0 metadata foundation (labels, due date, checklist)
   - P0 board filtering
2. `TV2-M2B`:
   - P1 keyboard speed paths
   - P1 search baseline
3. `TV2-M3+`:
   - P2 assignment and markdown depth
   - P3 advanced views and custom fields

## Update Log

| Date | Change | Author | Approval |
| --- | --- | --- | --- |
| 2026-03-07 | Created feature-lock template | Samwise | Pending |
| 2026-03-07 | Added proposed must/should/later set from research gap matrix | Samwise | Pending AJ decision |
| 2026-03-07 | Approved feature lock and priority ordering (`P0` through `P3`) | AJ + Samwise | Approved |
| 2026-03-07 | Landed `P2` depth baseline (multi-assignee model, description/comments, lane WIP/collapse) | Samwise | Implementation completed; AJ review pending |
