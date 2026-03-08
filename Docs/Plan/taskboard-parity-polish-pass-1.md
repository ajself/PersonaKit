# Taskboard Parity Polish Review (Pass 1)

Status: Draft  
Owner: AJ  
Last Reviewed: 2026-03-07

## Scope Under Review

Post-ATP polish pass:

1. Lane selection model for focused actions
2. Keyboard shortcuts for quick lane/ticket actions
3. Drag-and-drop ticket movement between lanes
4. Selection continuity across persistence reloads and lane changes

## Build/Version Context

1. Branch: `main` (local parity-polish working changes)
2. Validation evidence:
   - `swift test --filter StudioHelpCatalogTests` passed
   - `swift test --filter StudioRootNavigationStateTests` passed
   - `xcodebuildmcp macos build --workspace-path PersonaKit.xcworkspace --scheme PersonaKitStudio` succeeded

## Flows Tested

1. Select lane, trigger `New Ticket` and `Edit Lane` quick actions.
2. Use keyboard shortcuts:
   - `Shift-Command-L` (`New Lane`)
   - `Shift-Command-T` (`New Ticket` in selected lane)
   - `Shift-Command-E` (`Edit selected lane`)
3. Drag a ticket from one lane and drop into another.
4. Verify selection remains stable after lane create/edit/delete and board reload.

## Scorecard By Rubric Dimension

| Dimension | Raw (0-5) | Weight | Weighted Score | Evidence |
| --- | --- | --- | --- | --- |
| Navigation clarity | 4 | 15 | 12 | Admin/Taskboard path remains clear and stable. |
| Lane workflow clarity | 4 | 15 | 12 | Lane CRUD + selection model improves clarity for focused actions. |
| Ticket CRUD flow quality | 4 | 20 | 16 | Ticket create/edit/delete remains complete and usable. |
| Move/reorder reliability | 5 | 20 | 20 | Menu-based and drag/drop ticket movement both supported with deterministic state updates. |
| Keyboard and accessibility efficiency | 4 | 15 | 12 | Shortcut path now exists for common lane/ticket operations. |
| Performance perception | 4 | 15 | 12 | Interaction remains responsive with workspace-local persistence. |

Total score: `84 / 100`

## Findings By Severity

### Minor

1. `IQ-301`
   - Severity: `minor`
   - Repro steps:
     1. Compare Taskboard interaction density against Trello-style boards with richer ticket metadata.
   - Expected behavior: Optional richer ticket content controls while keeping compact scanning.
   - Observed behavior: Current ticket card remains intentionally minimal (title/owner/priority only).
   - Proposed fix: Add optional expanded metadata view (`description`, `labels`) behind progressive disclosure.
   - Owner: AJ + Samwise
   - Disposition: `defer`

## Recommended Fixes (Ordered)

1. Add optional expanded ticket metadata panel with preserved compact default.
2. Add visual drop-target emphasis polish for drag/drop destination feedback.

## Stop/Go Recommendation

`go-with-notes`

Rationale:

1. No blockers or major issues found in this pass.
2. Core parity mechanics (ticket movement + keyboard acceleration) are in place.
3. Current score (`84`) is near parity-ready threshold (`85`) with only minor polish deltas.

## Next Checkpoint

1. Decide whether to run one more parity polish pass to target `>= 85`.
2. If yes, scope minimal drop-target visual feedback and optional ticket metadata expansion.
