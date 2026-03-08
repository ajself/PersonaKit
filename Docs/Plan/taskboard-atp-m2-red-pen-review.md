# Taskboard Interaction Quality Review (ATP-M2)

Status: Draft  
Owner: AJ  
Last Reviewed: 2026-03-07

## Scope Under Review

ATP-M2 implementation slice:

1. Lane template creation
2. Lane edit/delete/reorder
3. Ticket creation
4. Workspace-local Taskboard persistence

## Build/Version Context

1. Branch: `main` (with local ATP-M1/M2 working changes)
2. Validation evidence:
   - `swift test --filter StudioHelpCatalogTests` passed
   - `swift test --filter StudioRootNavigationStateTests` passed
   - `xcodebuildmcp macos build --workspace-path PersonaKit.xcworkspace --scheme PersonaKitStudio` succeeded

## Flows Tested

1. Review `Admin -> Taskboard` navigation and panel wiring.
2. Verify lane template add flow and lane actions (`Edit`, `Move Left/Right`, `Delete`) in Taskboard panel.
3. Verify ticket creation flow and per-lane insertion.
4. Verify workspace-local persistence load/save behavior in panel state transitions.
5. Re-check help content and guidance links for Taskboard.

## Scorecard By Rubric Dimension

| Dimension | Raw (0-5) | Weight | Weighted Score | Evidence |
| --- | --- | --- | --- | --- |
| Navigation clarity | 4 | 15 | 12 | Admin section and Taskboard destination remain clear and discoverable. |
| Lane workflow clarity | 4 | 15 | 12 | Lane template create/edit/delete/reorder actions are present and bounded. |
| Ticket CRUD flow quality | 3 | 20 | 12 | Ticket create flow exists; edit/delete are not implemented yet. |
| Move/reorder reliability | 3 | 20 | 12 | Lane reorder is deterministic; ticket move between lanes is not implemented yet. |
| Keyboard and accessibility efficiency | 3 | 15 | 9 | Form-based create flows are keyboard reachable; no dedicated shortcut model yet. |
| Performance perception | 4 | 15 | 12 | Local state and persistence path remain lightweight and responsive. |

Total score: `69 / 100`

## Findings By Severity

### Major

1. `IQ-101`
   - Severity: `major`
   - Repro steps:
     1. Open Taskboard.
     2. Create a ticket.
     3. Attempt to edit or delete that ticket from the lane.
   - Expected behavior: Ticket edit/delete controls are available.
   - Observed behavior: Ticket creation exists, but edit/delete controls are not present.
   - Proposed fix: Add ticket edit/delete actions with confirmation behavior in ATP-M3.
   - Owner: AJ + Samwise
   - Disposition: `fix-now`

2. `IQ-102`
   - Severity: `major`
   - Repro steps:
     1. Open Taskboard with multiple lanes.
     2. Attempt to move ticket to a different lane.
   - Expected behavior: Ticket can move between lanes with clear destination behavior.
   - Observed behavior: Lane reorder exists; ticket cross-lane movement is not implemented.
   - Proposed fix: Add ticket move action (menu or drag/drop) and update persistence state in ATP-M3.
   - Owner: AJ + Samwise
   - Disposition: `fix-now`

### Minor

1. `IQ-103`
   - Severity: `minor`
   - Repro steps:
     1. Use Taskboard for repeated lane/ticket updates.
     2. Inspect status messaging text.
   - Expected behavior: Persistence messaging is concise and minimally noisy.
   - Observed behavior: Save/load status messages can become chatty during frequent updates.
   - Proposed fix: Convert persistent messages to lightweight transient status or reduce update frequency.
   - Owner: AJ + Samwise
   - Disposition: `defer`

## Recommended Fixes (Ordered)

1. Implement ticket edit/delete controls.
2. Implement ticket move between lanes with deterministic state updates.
3. Add a compact interaction status model for persistence messaging.

## Stop/Go Recommendation

`stop`

Rationale:

1. Score (`69`) is below `75` minimum `go-with-notes` threshold.
2. Remaining major gaps are core to expected board behavior (`ticket` lifecycle and movement).
3. ATP-M2 successfully upgraded the shell, but ATP-M3 is required before usability claims.

## Next Checkpoint

1. Execute ATP-M3: ticket edit/delete + lane-to-lane ticket movement.
2. Re-run `studio-interaction-quality` red-pen pass after ATP-M3 changes.
