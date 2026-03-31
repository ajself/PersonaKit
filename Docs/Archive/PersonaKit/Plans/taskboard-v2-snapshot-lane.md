# Taskboard V2 Snapshot Lane

Status: Parked
Owner: AJ  
Last Reviewed: 2026-03-29

## Purpose

Define the visual QA lane for Taskboard so UI changes are reviewed with stable
snapshot evidence instead of subjective memory.

Historical posture:

- preserved as the Taskboard visual QA and snapshot policy baseline
- not the current repo-wide execution queue
- current repo-wide priority lives in `Docs/Current-State.md`

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

1. Implemented and validated on this branch:
   - Empty board state
   - Default seeded board state
   - Dense board state
   - Selected lane state
   - Selected ticket state (extra parity scenario)
   - Lane editor open
   - Ticket editor open
   - Active drag target highlight state
   - Inline quick edit state (extra parity scenario)
2. Harness note:
   - Lane-editor and ticket-editor baselines use a board-plus-editor composite
     harness because plain macOS `NSHostingView` image snapshots do not capture
     `.sheet` content reliably
3. Verification completed:
   - `swift test --filter TaskboardSnapshotTests`
   - `swift test`
   - `xcodebuildmcp macos build --workspace-path PersonaKit.xcworkspace --scheme PersonaKitStudio --derived-data-path .build/DerivedData`

## Fixture policy

1. Use deterministic fixture data with stable IDs and sort order.
2. No time-dependent values in fixtures.
3. Keep fixtures local to Taskboard snapshot target.
4. Update fixture docs when schema changes.

## Review policy

1. Any Taskboard UI change requires snapshot diff review.
2. If diff materially changes hierarchy, spacing, contrast, or controls:
   - run a red-pen pass
   - log findings in `Docs/Archive/PersonaKit/Plans/`
3. Block release for blocker-level visual regressions.

## Command contracts

Use `swift test` as the standard runner for package and snapshot verification in
this repo, and use `xcodebuildmcp` for app build verification. All build
artifacts stay rooted under `.build`.

1. Baseline capture command:
   - `swift test --filter TaskboardSnapshotTests`
2. Diff verification command:
   - `swift test --filter TaskboardSnapshotTests`

Note:

1. Shared app verification command:
   - `xcodebuildmcp macos build --workspace-path PersonaKit.xcworkspace --scheme PersonaKitStudio --configuration Debug --derived-data-path .build/DerivedData`

## Exit criteria

1. Snapshot suite is committed and deterministic.
2. Baselines exist for all required scenarios.
3. Diff-review checklist is documented and used.
4. Failures are actionable and linked to a remediation owner.

## Related docs

1. [Taskboard V2 Initiative Plan](./taskboard-v2-initiative-plan.md)
2. [Taskboard Trello Image Catalog](../Research/taskboard-trello-image-catalog.md)
3. [Taskboard ATP M3 Red Pen Review](./Archive/taskboard-atp-m3-red-pen-review.md)
