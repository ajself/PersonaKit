# TODO

Status: Active  
Owner: AJ + Samwise  
Last Reviewed: 2026-03-08

## Purpose

Keep execution focused. This file lists only actionable, in-order tasks.

## Action Queue (In Order)

### 1) Taskboard V2 Initiative (Next)

Plan source:

- `Docs/Plan/taskboard-v2-initiative-plan.md`
- `Docs/Plan/taskboard-v2-feature-lock.md`
- `Docs/Plan/taskboard-ai-mutation-contract.md`
- `Docs/Plan/taskboard-v2-snapshot-lane.md`
- `Docs/Plan/night-shift-taskboard-rival-plan.md`

Historical baseline:

- `Docs/Plan/Archive/admin-ticket-planning-feature-brief.md`
- `Docs/Plan/Archive/taskboard-parity-polish-pass-2.md`

Objective:

- Evolve Taskboard from parity baseline to a genuinely useful, AI-operable
  planning surface with rigorous product/UX evidence.

Actions:

1. Expand Taskboard snapshot baselines from `2/7` to `7/7` required scenarios
   in `Docs/Plan/taskboard-v2-snapshot-lane.md`.
2. Complete `NS0` reporting loop in `night-shift-taskboard-rival-plan.md`
   using the landed telemetry foundation from `9242fcb`.
3. Continue `NS1` throughput work after `NS0` evidence is green:
   - inline quick edit for title/assignees/labels
   - keyboard-first path for triage and movement
4. Re-run interaction-quality review before starting `NS2` visual polish work.

Exit criteria:

1. Snapshot lane required scenario coverage is complete (`7/7`).
2. `NS0` evidence is recorded and reviewable.
3. `NS1` core throughput slice reaches a fresh red-pen pass with no blocker findings.
4. Taskboard remains deterministic and validation-clean.

Execution note:

- `P0` Taskboard metadata + filtering and M2A contract lock completed on
  2026-03-07.
- Mutation engine + deterministic contract tests landed on 2026-03-07.
- `TV2-M2B` (`P1`) baseline landed on 2026-03-07:
  - keyboard speed-path baseline
  - search baseline across lanes and tickets
- `P2` depth baseline landed on 2026-03-07:
  - richer assignment model (multi-assignee ticket model)
  - markdown description/comments on ticket detail + cards
  - lane WIP limit + collapse controls

## Plan Hygiene Rules

1. Keep only active plans in `Docs/Plan/`.
2. Move completed plans to `Docs/Plan/Archive/`.
3. Keep ongoing operational records in `Docs/Development/`, not here.
4. Keep this TODO ordered and current after each milestone.
