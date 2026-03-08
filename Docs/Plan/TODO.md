# TODO

Status: Active  
Owner: AJ + Samwise  
Last Reviewed: 2026-03-08

## Purpose

Keep execution focused. This file lists only actionable, in-order tasks.

## Action Queue (In Order)

### 1) Taskboard Trello-Parity Initiative (Next)

Plan source:

- `Docs/Plan/taskboard-trello-parity-execution-charter.md`
- `Docs/Plan/taskboard-v2-initiative-plan.md`
- `Docs/Plan/taskboard-v2-feature-lock.md`
- `Docs/Plan/taskboard-ai-mutation-contract.md`
- `Docs/Plan/taskboard-v2-snapshot-lane.md`
- `Docs/Plan/night-shift-taskboard-rival-plan.md`

Historical baseline:

- `Docs/Plan/Archive/admin-ticket-planning-feature-brief.md`
- `Docs/Plan/Archive/taskboard-parity-polish-pass-2.md`

Objective:

- Get Taskboard to board-and-card parity that a human user could reasonably
  mistake for Trello, while keeping the AI-operable contract deterministic and
  safe.

Actions:

1. Complete `P1` research and lock reset:
   - keep `Board + Card Parity` explicit across active Taskboard planning docs
   - keep out-of-scope boundaries explicit
2. Execute `P2` board interaction parity:
   - complete `NS0` reporting loop
   - continue `NS1` throughput work with remaining interaction polish
3. Execute `P3` card-detail parity and `P4` visual/accessibility parity.
4. Execute `P5` AI-operable parity through the approved callable local surface.
5. Close out active Taskboard work and run the delegated-commit retrospective.

Exit criteria:

1. Trello parity checklist is active and reviewable.
2. Snapshot lane required scenario coverage is complete (`7/7`).
3. Final parity review has `0` blockers.
4. AI-operable contract is callable, deterministic, and safe.
5. No dangling active Taskboard tasks remain in `Docs/Plan/`.

Execution note:

- `P0` staffing readiness is complete in the current working tree:
  - `studio-swiftui-product-engineer` is qualified
  - `taskboard-parity-designer` is qualified
  - squad delivery and retrospective sessions validate cleanly
- Taskboard snapshot lane required coverage is complete in the current working tree:
  - `7/7` required scenarios are implemented and validated on this branch
  - editor-open snapshots use a board-plus-editor harness because plain macOS
    `NSHostingView` snapshots do not capture `.sheet` content
- `NS1` inline quick edit is implemented in the current working tree:
  - cards now support in-place editing for title, assignees, and labels
  - snapshot coverage includes a dedicated inline quick-edit state
- Keyboard-first ticket movement baseline is implemented in the current working tree:
  - selected-ticket state exists alongside lane selection
  - header shortcuts now navigate selected tickets and open inline quick edit
  - selected tickets can now hand off left/right between lanes from the keyboard
  - selected tickets can now reorder up/down within the active lane from the keyboard
- Header command density has been reduced in the current working tree:
  - primary board actions stay visible, while selection/movement/report actions moved into one overflow menu
  - keyboard shortcuts remain available even though the default board chrome is calmer
  - remaining `P2` work is now interaction polish plus the open `NS0` evidence loop
- Card label scanning has been upgraded in the current working tree:
  - cards now render up to three colored label chips before the title instead of a plain comma-separated label line
  - dense-board snapshots now read more like a Trello board at a glance while keeping the label mapping deterministic
  - remaining `P2` work is still interaction polish plus the open `NS0` evidence loop
- Card chrome has been simplified in the current working tree:
  - the always-visible quick-edit and lane-move buttons are gone from the card face
  - cards now keep one overflow menu visible while double-click opens the full ticket editor
  - remaining `P2` work is deeper card/detail polish plus the open `NS0` evidence loop
- Default card action chrome has been reduced again in the current working tree:
  - unselected cards no longer show even the overflow menu icon by default
  - selected or inline-edited cards still surface the overflow menu so keyboard and menu-driven actions remain available
  - remaining `P2` work is deeper card/detail polish plus the open `NS0` evidence loop

## Plan Hygiene Rules

1. Keep only active plans in `Docs/Plan/`.
2. Move completed plans to `Docs/Plan/Archive/`.
3. Keep durable operational records in `Docs/Development/`, not here.
4. Keep this TODO ordered and current after each milestone.
