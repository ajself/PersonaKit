# PersonaKit Studio Visual Relationship Mapping Plan

## Progress Snapshot
- Last updated: 2026-02-17
- Overall status: **Complete**
- Phase 1 (Session map): **Complete**
- Phase 2 (Workspace-wide map): **Complete**
- Test suite status: **Passing (`swift test`)**
- Remaining follow-up: **None**

## Post-Review Fixes Applied (2026-02-17)
- Added workspace identity-triggered refresh in relationship map flows to prevent stale workspace-wide map state after workspace switches.
- Added synthetic-session guard (`active-session`) for `.session` map-node navigation to avoid invalid drill-down targets.
- Added targeted regression coverage for:
  - workspace relationship map lifecycle success/error/stale-clear paths
  - `.session` navigation guard behavior in map-node target resolution
- Added root-level navigation state transition assertions for map-node drill-down flows via `StudioRootNavigationState` tests.

## Summary
Build a **session-first visual dependency map** in Studio so users can understand and manage the big picture while editing.
Phase 1 adds a layered, interactive map in `Sessions` plus a live mini-map in the session editor.
Phase 2 extends the same graph system to a workspace-wide map.

## Locked Decisions
1. Primary scope is **session-first**.
2. Map lives in a **new Sessions tab**.
3. V1 is **read-only with drill-down navigation**.
4. Visual style is a **layered node graph**.
5. Include **health indicators** (missing refs/problems).
6. Use **pure SwiftUI** (no new graph dependency).
7. Include a **live mini-map in the session editor**.
8. Node click behavior is **navigate + select** existing Library targets.
9. Map refresh is **automatic**.
10. Plan includes a **concrete Phase 2** for workspace-wide mapping.

## Public API / Interface Additions
Status: **Complete**

Added in `ContextWorkspaceCore`:
- `Sources/Shared/ContextWorkspaceCore/WorkspaceSessionMapTypes.swift`
- `Sources/Shared/ContextWorkspaceCore/WorkspaceSessionMapBuilder.swift`
- `Sources/Shared/ContextWorkspaceCore/WorkspaceRelationshipMapBuilder.swift`

Added protocols/types:
- `WorkspaceSessionMapBuilding`
- `WorkspaceRelationshipMapBuilding`
- `WorkspaceSessionMapNodeKind`
- `WorkspaceSessionMapNode`
- `WorkspaceSessionMapEdge`
- `WorkspaceSessionMap`

## Phase 1 Implementation Status (Session Map)

### 1) Core Graph Builder
Status: **Complete**

- [x] `WorkspaceSessionMapBuilder` implemented in `ContextWorkspaceCore`.
- [x] Project/global scope resolution aligned with preview/session logic.
- [x] Deterministic node/edge ordering and stable sorting.
- [x] Resolver used for correctness signal and error surfacing.
- [x] Layering implemented: `session -> persona|directive -> kits -> intents -> skills -> essentials`.
- [x] Edge reason fields implemented.
- [x] Missing references represented as map nodes with `isMissing = true`.

### 2) Studio Foundation Integration
Status: **Complete**

- [x] Added `loadSessionMap(...)` to `WorkspaceOperationRunner`.
- [x] Added `WorkspaceSessionMapState`.
- [x] Extended `WorkspaceSessionFeatureModel` with map and draft-map lifecycle.
- [x] Added cancellation/stale-result protections for map loading.
- [x] Added `WorkspaceStore`/`WorkspaceStore+SessionActions` wrappers for map refresh/clear.

### 3) Sessions UI: New Map Tab
Status: **Complete**

- [x] Added `SessionsMapTabView`.
- [x] Added `Map` tab to sessions panel.
- [x] Auto-refresh on session change and relevant snapshot changes.
- [x] Loading/empty/error/rendered states implemented.

### 4) Graph Rendering (Pure SwiftUI)
Status: **Complete**

- [x] Added reusable `SessionDependencyMapView`.
- [x] Fixed-column lane layout with scroll support.
- [x] Edge rendering uses `Canvas` + anchor preferences.
- [x] Node cards include id, display name, scope badge, relationship badges, and missing-state styling.
- [x] Scope badge resolution derived from `WorkspaceSnapshot` lookups.

### 5) Health Overlay and Diagnostics Linking
Status: **Complete**

- [x] Header health summary shows resolved/issue count.
- [x] Resolver issues shown below map.
- [x] CTAs added for diagnostics and node highlighting.
- [x] Diagnostics remain source of truth.

### 6) Node Drill-Down Navigation
Status: **Complete**

- [x] Callback plumbing from sessions map through `SessionsPanelView` into `StudioRootView` state updates.
- [x] Node type mapping implemented for personas/directives/kits/intents/skills/essentials/sessions.
- [x] Added root-level state transition assertions for map-driven navigation updates.

### 7) Session Editor Live Mini-Map
Status: **Complete**

- [x] Mini-map section added to `SessionEditorView`.
- [x] Reused map component in compact mode.
- [x] Debounced recompute (200ms) with cancellation.
- [x] Save validation flow remains unchanged.

## Phase 2 Implementation Status (Workspace-Wide Map)
Status: **Complete**

- [x] Added sidebar item `Relationship Map`.
- [x] Added `WorkspaceRelationshipMapPanelView`.
- [x] Reused node/edge rendering from Phase 1.
- [x] Added workspace-wide dependency graph builder.
- [x] Added filters: entity types, scope, and search.
- [x] Added session-context focus mode for subgraph filtering.
- [x] Kept read-only drill-down interaction model.

## Tests and Scenarios

### Core Tests
Status: **Complete**

- [x] Added `Tests/Shared/Core/WorkspaceSessionMapBuilderTests.swift`.
- [x] Covered deterministic ordering.
- [x] Covered fixture happy path.
- [x] Covered missing reference scenarios.
- [x] Covered override dedup/badging.
- [x] Covered project/global merge behavior.

### Studio Feature Tests
Status: **Complete**

- [x] Added `Tests/Features/Studio/WorkspaceSessionFeatureModelMapTests.swift`.
- [x] Covered selected-session map refresh.
- [x] Covered stale/cancel overlap behavior.
- [x] Covered draft mini-map refresh behavior.
- [x] Covered error surfacing.
- [x] Covered workspace relationship map lifecycle success/error/stale-clear behavior.

### UI Wiring Tests
Status: **Complete**

- [x] Extended `Tests/Features/Studio/WorkspaceStoreTests.swift` with map-state coverage.
- [x] Covered map state clearing on workspace clear.
- [x] Covered selected-session map refresh flows.
- [x] Covered `.session` map-node navigation guard rules in resolver-level tests.
- [x] Added direct assertion coverage for root-level node drill-down navigation state transition.

### Acceptance Scenarios
Status: **Implemented; validated via behavior and tests where practical**

- [x] Session selection renders dependency map.
- [x] Missing references are visible and called out.
- [x] Node selection pathways for drill-down are implemented.
- [x] Editor mini-map updates with draft changes.
- [x] Determinism maintained and tests pass.

## Assumptions and Defaults
1. Keep architecture local-first and deterministic; no background automation.
2. No schema/model changes to PersonaKit pack files.
3. No inline graph editing in v1.
4. No new external dependencies for graph rendering.
5. Health indicators are based on resolver errors plus existing workspace semantics.
6. Scope badges use current Project/Global coloring conventions already used in list rows.

## Implemented File Index

### New files
- `Sources/Shared/ContextWorkspaceCore/WorkspaceSessionMapTypes.swift`
- `Sources/Shared/ContextWorkspaceCore/WorkspaceSessionMapBuilder.swift`
- `Sources/Shared/ContextWorkspaceCore/WorkspaceRelationshipMapBuilder.swift`
- `Sources/Features/Studio/Foundation/WorkspaceSessionMapState.swift`
- `Sources/Features/Studio/UI/WorkspaceSessionFeatureModel+MapLifecycle.swift`
- `Sources/Features/Studio/UI/SessionDependencyMapView.swift`
- `Sources/Features/Studio/UI/SessionsMapNavigationResolver.swift`
- `Sources/Features/Studio/UI/SessionsMapTabView.swift`
- `Sources/Features/Studio/UI/StudioRootNavigationState.swift`
- `Sources/Features/Studio/UI/WorkspaceRelationshipMapPanelView.swift`
- `Tests/Features/Studio/SessionsMapNavigationResolverTests.swift`
- `Tests/Features/Studio/StudioRootNavigationStateTests.swift`
- `Tests/Shared/Core/WorkspaceSessionMapBuilderTests.swift`
- `Tests/Features/Studio/WorkspaceSessionFeatureModelMapTests.swift`

### Updated files
- `Sources/Features/Studio/Foundation/WorkspaceOperationRunner.swift`
- `Sources/Features/Studio/UI/WorkspaceSessionFeatureModel.swift`
- `Sources/Features/Studio/UI/WorkspaceStore.swift`
- `Sources/Features/Studio/UI/WorkspaceStore+SessionActions.swift`
- `Sources/Features/Studio/UI/WorkspaceStore+WorkspaceFlow.swift`
- `Sources/Features/Studio/UI/SessionsPanelView.swift`
- `Sources/Features/Studio/UI/SessionEditorView.swift`
- `Sources/Features/Studio/UI/StudioRootView.swift`
- `Sources/Features/Studio/UI/StudioSidebarView.swift`
- `Tests/Features/Studio/WorkspaceStoreTests.swift`
- `Tests/Features/Studio/WorkspaceLoadFeatureModelTests.swift`
