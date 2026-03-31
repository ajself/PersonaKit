# Taskboard Trello-Parity Execution Charter

Status: Parked
Owner: AJ + Samwise
Last Reviewed: 2026-03-29

## Purpose

Define the active execution charter for getting Taskboard to board-and-card
parity that a human user could reasonably mistake for Trello.

Historical posture:

- preserved as the Taskboard parity execution charter for the parked initiative
- not the current repo-wide execution queue
- current repo-wide priority lives in `Docs/Current-State.md`

## Summary

1. Finish Taskboard to `Board + Card Parity` for the board and card-detail
   experience.
2. Use Samwise as orchestrator over bounded squads in the active Taskboard
   initiative worktree.
3. Staff the missing specialist personas before relying on squads for parity
   work.
4. Use delegated commit approval only for the current Taskboard initiative
   branch/worktree, with AJ retaining release approval for main-affecting
   integration.

## Staffing Gate

Required personas:

1. `studio-swiftui-product-engineer`
2. `taskboard-parity-designer`

Rule:

1. No new persona joins a live squad until `samwise-persona-hiring` scores it at
   `>= 80`, verdict `qualified`, and no unresolved high-severity gap remains.
2. Hiring passes are persisted to `Docs/Development/hiring-reviews/` and
   `Docs/Development/logs/persona-hiring-reviews.jsonl`.

## Active Squads

1. `Parity Product Squad`
   - `venture-product-steward`
   - `studio-interaction-quality-lead`
2. `Board Experience Squad`
   - `studio-swiftui-product-engineer`
   - `worktree-squad-lead`
   - `studio-interaction-quality-lead`
3. `Card Systems Squad`
   - `architectural-editor`
   - `studio-reliability-engineer`
   - `studio-integration-coordinator`
   - `worktree-squad-lead`
4. `Visual QA Squad`
   - `taskboard-parity-designer`
   - `studio-coverage-architect`
   - `studio-interaction-quality-lead`

## Current Milestone Order

1. `P0` Staffing readiness
2. `P1` Research and lock reset
3. `P2` Board interaction parity
4. `P3` Card detail parity
5. `P4` Visual and accessibility parity
6. `P5` AI-operable parity
7. `P6` Closeout and retrospective

## Commit and Release Policy

1. Samwise may approve commits only within the current Taskboard parity
   initiative branch/worktree under `samwise-feature-commit-approved`.
2. This approval never applies to repository `main`.
3. AJ remains release manager for rebases or merges that affect `main`.
4. The delegated commit experiment must be reviewed in a retrospective before
   any broader rollout.

## Related Docs

1. `Docs/Archive/PersonaKit/Plans/taskboard-v2-initiative-plan.md`
2. `Docs/Archive/PersonaKit/Plans/taskboard-v2-feature-lock.md`
3. `Docs/Archive/PersonaKit/Plans/taskboard-ai-mutation-contract.md`
4. `Docs/Archive/PersonaKit/Plans/taskboard-v2-snapshot-lane.md`
