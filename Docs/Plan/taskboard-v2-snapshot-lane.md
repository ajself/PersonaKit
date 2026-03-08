# Taskboard V2 Snapshot Lane

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Define the visual QA lane for Taskboard so UI changes are reviewed with stable
snapshot evidence instead of subjective memory.

## Scope

1. Taskboard panel rendering states in Studio macOS app.
2. Snapshot baselines for core board states and critical interactions.
3. Review policy for snapshot diffs and red-pen escalation.

## Baseline scenarios (required)

1. Empty board state.
2. Default seeded board state.
3. Dense board state (multi-lane, high ticket count).
4. Selected lane state.
5. Lane editor sheet open.
6. Ticket editor sheet open.
7. Active drag target highlight state.

## Current coverage

1. Implemented and committed:
   - Empty board state
   - Default seeded board state
2. Remaining to add:
   - Dense board state (multi-lane, high ticket count)
   - Selected lane state
   - Lane editor sheet open
   - Ticket editor sheet open
   - Active drag target highlight state

## Fixture policy

1. Use deterministic fixture data with stable IDs and sort order.
2. No time-dependent values in fixtures.
3. Keep fixtures local to Taskboard snapshot target.
4. Update fixture docs when schema changes.

## Review policy

1. Any Taskboard UI change requires snapshot diff review.
2. If diff materially changes hierarchy, spacing, contrast, or controls:
   - run a red-pen pass
   - log findings in `Docs/Plan/`
3. Block release for blocker-level visual regressions.

## Command contracts

Use `xcodebuildmcp` as the standard runner for Xcode project build/test flows in
this repo.

1. Baseline capture command:
   - `xcodebuildmcp macos test --scheme PersonaKitTests --only-testing <TaskboardSnapshotSuite>`
2. Diff verification command:
   - `xcodebuildmcp macos test --scheme PersonaKitTests --only-testing <TaskboardSnapshotSuite>`

Note:

1. Replace `<TaskboardSnapshotSuite>` with concrete test target names when the
   suite lands.
2. Current local baseline command (SwiftPM target filter):
   - `swift test --filter TaskboardSnapshotTests`

## Exit criteria

1. Snapshot suite is committed and deterministic.
2. Baselines exist for all required scenarios.
3. Diff-review checklist is documented and used.
4. Failures are actionable and linked to a remediation owner.

## Related docs

1. [Taskboard V2 Initiative Plan](./taskboard-v2-initiative-plan.md)
2. [Taskboard Trello Image Catalog](../Research/taskboard-trello-image-catalog.md)
3. [Taskboard ATP M3 Red Pen Review](./taskboard-atp-m3-red-pen-review.md)
