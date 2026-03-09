# Taskboard Interaction Quality Review (ATP-M1)

Status: Archived  
Owner: AJ  
Last Reviewed: 2026-03-08

## Scope Under Review

Admin `Taskboard` shell introduced in ATP-M1:

1. Sidebar destination (`Admin -> Taskboard`)
2. Placeholder board panel
3. Deterministic sample lanes/tickets
4. Taskboard help wiring

## Build/Version Context

1. Branch: `main` (with local ATP-M1 working changes)
2. Baseline commit before local ATP-M1 edits: `f1e6fe3`
3. Validation evidence:
   - `swift test --filter StudioHelpCatalogTests` passed
   - `swift test --filter StudioRootNavigationStateTests` passed
   - `xcodebuildmcp macos build --workspace-path PersonaKit.xcworkspace --scheme PersonaKitStudio` succeeded

## Flows Tested

1. Navigate to `Admin -> Taskboard`.
2. Inspect lane sequencing and ticket rendering in placeholder board.
3. Inspect Taskboard help content and related links.
4. Check for visible controls for lane/ticket create/edit/delete/move flows.
5. Check for obvious keyboard-first action path hints.

## Scorecard By Rubric Dimension

| Dimension | Raw (0-5) | Weight | Weighted Score | Evidence |
| --- | --- | --- | --- | --- |
| Navigation clarity | 4 | 15 | 12 | New sidebar section and destination are explicit and discoverable. |
| Lane workflow clarity | 3 | 15 | 9 | Lane sequence is readable, but flow is static in ATP-M1. |
| Ticket CRUD flow quality | 1 | 20 | 4 | No create/edit/delete controls yet. |
| Move/reorder reliability | 1 | 20 | 4 | No move/reorder interactions yet. |
| Keyboard and accessibility efficiency | 2 | 15 | 6 | Basic focusable UI only; no explicit keyboard workflow for core actions. |
| Performance perception | 4 | 15 | 12 | Shell feels responsive and deterministic with sample data. |

Total score: `47 / 100`

## Findings By Severity

### Blocker

1. `IQ-001`
   - Severity: `blocker`
   - Repro steps:
     1. Open `Admin -> Taskboard`.
     2. Try to create a lane or ticket.
   - Expected behavior: User can create at least one lane and one ticket.
   - Observed behavior: No creation controls are available in ATP-M1.
   - Proposed fix: Implement lane template create flow and ticket create flow in ATP-M2.
   - Owner: AJ + Samwise
   - Disposition: `fix-now`

2. `IQ-002`
   - Severity: `blocker`
   - Repro steps:
     1. Open `Admin -> Taskboard`.
     2. Try to move a ticket between lanes.
   - Expected behavior: User can move ticket across lanes with clear destination feedback.
   - Observed behavior: Tickets are static placeholders with no movement interaction.
   - Proposed fix: Add move/reorder interaction model and transfer action in ATP-M2/M3.
   - Owner: AJ + Samwise
   - Disposition: `fix-now`

### Major

1. `IQ-003`
   - Severity: `major`
   - Repro steps:
     1. Open Taskboard shell.
     2. Inspect affordances for primary actions.
   - Expected behavior: `Add Ticket` and lane actions should be visible.
   - Observed behavior: Primary action controls are not present yet.
   - Proposed fix: Add visible primary controls in lane headers and board toolbar in ATP-M2.
   - Owner: AJ + Samwise
   - Disposition: `fix-now`

### Minor

1. `IQ-004`
   - Severity: `minor`
   - Repro steps:
     1. Inspect placeholder ticket priority labels.
   - Expected behavior: Priority token vocabulary should align to final taxonomy.
   - Observed behavior: Placeholder includes `Done` as a priority token.
   - Proposed fix: Split status and priority vocab in ticket model before ATP-M3.
   - Owner: AJ + Samwise
   - Disposition: `defer`

## Recommended Fixes (Ordered)

1. Add lane template + ticket create actions (`ATP-M2`).
2. Add visible lane/ticket primary action affordances.
3. Add ticket move/reorder interactions (`ATP-M3`).
4. Normalize ticket status/priority vocabulary.

## Stop/Go Recommendation

`stop`

Rationale:

1. Blockers present (`IQ-001`, `IQ-002`).
2. Score (`47`) is below `75` minimum ship-with-notes threshold.
3. ATP-M1 shell is acceptable as a scaffold, not as a usable planning flow.

## Next Checkpoint

1. Execute ATP-M2 lane/ticket creation flows.
2. Re-run `studio-interaction-quality` red-pen pass after ATP-M2 implementation.
