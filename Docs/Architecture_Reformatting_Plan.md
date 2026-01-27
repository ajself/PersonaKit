# Architecture Reformatting Plan — FOSA Alignment

This plan tracks a phased, low-risk reformatting of PersonaKit’s app architecture to
align with Feature-Oriented SwiftUI Architecture (FOSA). It prioritizes determinism,
scope control, and predictable execution.

## Sources of truth (read before starting)
- PersonaKit v1 Scope & Contract: `Docs/PersonaKit_v1_Scope_and_Contract.md`
- PersonaKit 2.0 Prompt Pack: `Docs/PersonaKit_2_0_Prompt_Pack_Index.md`
- PersonaKit agent rules: `AGENTS.md`
- FOSA rules and defaults: `FOSA` repo docs (`AGENTS.md`, `STYLE_GUIDE.md`, `SWIFT_STYLE_GUIDE.md`, `App/ArchitectureDefaults.md`)

## Guardrails (non-negotiable)
- No behavior changes to composition semantics or schema rules.
- No new product features or scope expansion.
- Determinism preserved: same input -> same output.
- IO never performed in SwiftUI views.
- Single-owner data; mutations traceable through named methods on explicit owners.
- No ELM-style reducers/actions/stores (per updated FOSA guidance).
- App and CLI stay in parity for identical inputs.

## Non-goals
- No redesign of UI/UX.
- No new runtime dependencies.
- No changes to storage format or schema versioning.
- No new “smart” behavior or inference.

## Deliverables
- A repo-wide target architecture map (feature-first, per FOSA).
- A concrete file move map (old path -> new path).
- `Sources/PersonaKitApp/App/ArchitectureDefaults.md` (repo defaults, minimal and stable).
- Incremental, low-risk refactors with parity tests.
- Updated docs reflecting the new structure.

---

## Phase 0 — Preflight and decisions

**Objective:** Lock down defaults and constraints before moving any files.

Checklist:
- Read FOSA `AGENTS.md` and `STYLE_GUIDE.md`.
- Read PersonaKit contract and 2.0 prompt pack.
- Decide default state-owner pattern (explicit Model owner).
- Create `Sources/PersonaKitApp/App/ArchitectureDefaults.md` with:
  - State-owner pattern
  - Concurrency rules
  - IO boundary rules
  - Testing expectations
- Define explicit “no behavior change” criteria and test gates.

Exit criteria:
- Defaults file committed.
- Plan for structure and sequencing agreed.

---

## Phase 1 — Inventory and mapping

**Objective:** Create a clear, scoped map of what exists and where it should go.

Checklist:
- Inventory current App/Core/CLI surface areas.
- Identify current state owners and view entry points.
- Identify IO usage and current boundaries (file, schema, OS APIs).
- Identify shared UI components and domain types.
- Identify tests tied to state owners and outputs.
- Draft target structure for each target:
  - App UI features
  - Shared UI utilities/modifiers
  - Clients and IO boundaries
  - Core domain and composition logic
- Produce a file move map (per feature, per module).

Exit criteria:
- Approved move map with explicit sequencing.
- Risk list with mitigation for each move set.

---

## Progress updates

### Sidebar pilot (completed)
- Added `Sources/PersonaKitApp/App/ArchitectureDefaults.md` with FOSA defaults.
- Introduced `SidebarModel` as the sidebar owner (no actions/state containers).
- Rewired sidebar UI, commands, and escape handling to call explicit model methods.
- Removed sidebar action routing (`AppStore+SidebarFeature.swift`) and filter helpers (`AppStore+Filters.swift`).
- Updated sidebar tests to use `store.sidebar`.
- Moved sidebar files into `Sources/PersonaKitApp/Features/Sidebar/`.

### Phase 2 foundations (completed)
- Moved app shell files into `Sources/PersonaKitApp/App/` and `App/Commands/`.
- Moved `AppClient` into `Sources/PersonaKitApp/Shared/Clients/`.
- Added `Shared/UI` and `Shared/Clients` folders for safe, low-risk structure.
- Moved `JSONEditorView` into `Sources/PersonaKitApp/Features/Preview/Components/`.

### Phase 3 global wiring (completed)
- Renamed `AppStore` -> `AppModel` and moved files into `Sources/PersonaKitApp/App/Model/`.
- Replaced `AppStore.State` with direct stored properties on `AppModel`.
- Removed `Action` enums and `send(_:)` routing; views/commands now call explicit methods.
- Updated bindings and tests to use `AppModel` and direct methods.
- `AppModel+Composer` and `AppModel+Preview` currently live in `App/Model` and will move into
  `Features/Composer` and `Features/Preview` during feature migrations.
- Composer feature migrated to `ComposerModel`; moved composer files into `Features/Composer/`.
- Preview feature migrated to `PreviewModel`; moved preview files into `Features/Preview/`.
- Inspector feature moved into `Features/Inspector/`; diff IO routed through `AppModel`.

### Phase 4 parity hardening (in progress)
- App JSON preview now uses `PersonaOutputRenderer.resolvedJSON` to align with CLI output.
- Built-in pack loading now uses a shared core helper with optional repo-root fallback.
- Audit findings (app/CLI duplication):
  - Built-in pack loading: App uses bundle-only lookup; CLI uses bundle + repo-root fallback with shared diagnostics.
  - User pack loading: App gathers pack locations for UI; CLI loads packs only.
  - Index building: both targets build `sourcesByID`/`packsByID` maps from `PersonaSet`.
- Proposed Phase 4 tasks:
  - Extract a core helper for built-in pack loading (bundle + optional repo-root fallback) and reuse in App/CLI.
  - Extract a core index builder for `sourcesByID`/`packsByID` to remove duplication.
  - Add app-level parity tests for preview outputs (prompt + JSON) against `PersonaOutputRenderer`.

---

## Inventory snapshot (current state)

### PersonaKitApp (SwiftUI target)
- **State owners:** `AppModel` (`@MainActor`, explicit methods) plus feature owners (`SidebarModel` for sidebar).
- **Feature slices:** `SidebarModel` (explicit owner), `ComposerModel`, `PreviewModel` (state-only; logic lives in `AppModel+*` extensions).
- **Views:** `ContentView`, `SidebarView`, `ComposerView`, `PreviewView`, `InspectorView`, `PersonaSwitcherView`, `JSONEditorView`.
- **App shell:** `PersonaKitAppMain`, `PersonaKitCommands`.
- **Utilities:** `PreviewPanel`, `SidebarSearchEscapePolicy`.
- **Clients:** `AppClient` (AppKit IO).
- **IO + storage usage:** `AppModel` calls `FileClient`, `AppClient`. `SidebarModel` calls `SavedFiltersStore`, `PinnedPersonasStore`.
- **Known FOSA violations:** None currently identified.

### PersonaKitCore (domain + IO boundaries)
- **Domain logic:** models, resolver, loader, composer, validator, renderer.
- **IO boundaries:** `FileClient`, `LoggerClient`.
- **File-backed state:** `SavedFiltersStore`, `PinnedPersonasStore`.

### CLI + Schema tools
- CLI is a thin shell over core logic (`PersonaKitCLIMain.swift`).
- Schema validator uses core validation (`PersonaKitSchemaValidate`).

### Test coverage (not exhaustive)
- App tests: JSON preview debounce, composer preview recompute, sidebar escape policy, pinned view toggles, saved filters, reload selection.
- Core tests: decoding, metadata, storage, loader, resolver, import, describe, compose.

---

## Target structure (proposed, app-only)

Adapt FOSA layout to the SPM target root `Sources/PersonaKitApp/`.

```
Sources/PersonaKitApp/
  App/
    PersonaKitAppMain.swift
    ContentView.swift
    Commands/
      PersonaKitCommands.swift
    Model/
      AppModel.swift
      AppModel+Reload.swift
      AppModel+ImportReveal.swift
      AppModel+Bindings.swift
  Features/
    Sidebar/
      SidebarView.swift
      SidebarModel.swift
      AppModel+Sidebar.swift
      AppModel+Filters.swift
      SidebarSearchEscapePolicy.swift
      Components/ (optional extraction)
    Composer/
      ComposerView.swift
      ComposerModel.swift
      AppModel+Composer.swift
    Preview/
      PreviewView.swift
      PreviewPanel.swift
      PreviewModel.swift
      AppModel+Preview.swift
      AppModel+JSONPreview.swift
      Components/JSONEditorView.swift (or Shared/UI/Components)
    Inspector/
      InspectorView.swift
      PackDiffInputBuilder.swift (move to client/state-owner in Phase 3)
    PersonaSwitcher/
      PersonaSwitcherView.swift
  Shared/
    Clients/
      AppClient.swift
    UI/
      Components/ (if JSONEditorView is shared)
```

Notes:
- `AppModel` is the single state owner; feature behaviors are grouped as `AppModel+*` extensions.
- All `Action` enums and `send(_:)` routing are removed in favor of explicit model methods.
- Feature `State` containers are replaced with explicit owner models (`SidebarModel`, `ComposerModel`, `PreviewModel`).
- Any IO used by views must move behind AppModel + Clients (e.g., pack diff building).
- Core target stays unchanged unless a move is strictly necessary for parity or reuse.

---

## File move map (first pass)

App shell:
- `Sources/PersonaKitApp/PersonaKitAppMain.swift` -> `Sources/PersonaKitApp/App/PersonaKitAppMain.swift` (done)
- `Sources/PersonaKitApp/ContentView.swift` -> `Sources/PersonaKitApp/App/ContentView.swift` (done)
- `Sources/PersonaKitApp/PersonaKitCommands.swift` -> `Sources/PersonaKitApp/App/Commands/PersonaKitCommands.swift` (done)

App model:
- `Sources/PersonaKitApp/AppStore.swift` -> `Sources/PersonaKitApp/App/Model/AppModel.swift` (done)
- `Sources/PersonaKitApp/AppStore+Reload.swift` -> `Sources/PersonaKitApp/App/Model/AppModel+Reload.swift` (done)
- `Sources/PersonaKitApp/AppStore+ImportReveal.swift` -> `Sources/PersonaKitApp/App/Model/AppModel+ImportReveal.swift` (done)
- `Sources/PersonaKitApp/AppStore+Bindings.swift` -> `Sources/PersonaKitApp/App/Model/AppModel+Bindings.swift` (done)
- `Sources/PersonaKitApp/AppStore+SendHandlers.swift` -> **remove** (replaced by explicit `AppModel` methods) (done)

Sidebar feature:
- `Sources/PersonaKitApp/SidebarView.swift` -> `Sources/PersonaKitApp/Features/Sidebar/SidebarView.swift` (done)
- `Sources/PersonaKitApp/SidebarFeature.swift` -> `Sources/PersonaKitApp/Features/Sidebar/SidebarModel.swift` (done)
- `Sources/PersonaKitApp/AppStore+SidebarFeature.swift` -> **remove** (logic moved into `SidebarModel`) (done)
- `Sources/PersonaKitApp/AppStore+Filters.swift` -> **remove** (logic moved into `SidebarModel`) (done)
- `Sources/PersonaKitApp/SidebarSearchEscapePolicy.swift`
  -> `Sources/PersonaKitApp/Features/Sidebar/SidebarSearchEscapePolicy.swift` (done)

Composer feature:
- `Sources/PersonaKitApp/ComposerView.swift` -> `Sources/PersonaKitApp/Features/Composer/ComposerView.swift` (done)
- `Sources/PersonaKitApp/ComposerFeature.swift` -> `Sources/PersonaKitApp/Features/Composer/ComposerModel.swift` (done)
- `Sources/PersonaKitApp/AppStore+ComposerFeature.swift`
  -> `Sources/PersonaKitApp/App/Model/AppModel+Composer.swift` (done)

Preview feature:
- `Sources/PersonaKitApp/PreviewView.swift` -> `Sources/PersonaKitApp/Features/Preview/PreviewView.swift` (done)
- `Sources/PersonaKitApp/PreviewPanel.swift` -> `Sources/PersonaKitApp/Features/Preview/PreviewPanel.swift` (done)
- `Sources/PersonaKitApp/PreviewFeature.swift` -> `Sources/PersonaKitApp/Features/Preview/PreviewModel.swift` (done)
- `Sources/PersonaKitApp/AppStore+PreviewFeature.swift`
  -> `Sources/PersonaKitApp/App/Model/AppModel+Preview.swift` (done)
- `Sources/PersonaKitApp/AppStore+JSONPreview.swift`
  -> `Sources/PersonaKitApp/App/Model/AppModel+JSONPreview.swift` (done)
- `Sources/PersonaKitApp/JSONEditorView.swift`
  -> `Sources/PersonaKitApp/Features/Preview/Components/JSONEditorView.swift` (done; feature-local)

Inspector feature:
- `Sources/PersonaKitApp/InspectorView.swift`
  -> `Sources/PersonaKitApp/Features/Inspector/InspectorView.swift` (done)
- `Sources/PersonaKitApp/PackDiffInputBuilder.swift`
  -> `Sources/PersonaKitApp/Features/Inspector/PackDiffInputBuilder.swift` (done)

Persona switcher feature:
- `Sources/PersonaKitApp/PersonaSwitcherView.swift`
  -> `Sources/PersonaKitApp/Features/PersonaSwitcher/PersonaSwitcherView.swift` (done)

Clients:
- `Sources/PersonaKitApp/Dependencies/AppClient.swift`
  -> `Sources/PersonaKitApp/Shared/Clients/AppClient.swift` (done)

---

## Phase 2 — Foundations (structure and safe moves)

**Objective:** Create the target skeleton and move safe, low-risk components.

Checklist:
- Add feature-first folders under App target.
- Add Shared folders for UI, Clients, Domain, Utilities.
- Move UI-only components into `Shared/UI` or feature `Components`.
- Move IO boundary code into `Shared/Clients` (no behavior changes).
- Ensure any shared domain types live in Core (not UI targets).

Exit criteria:
- Build passes with no logic changes.
- Tests still pass.

---

## Phase 3 — Feature-by-feature migration

**Objective:** Re-home each feature in small, reviewable steps.

For each feature:
1. Define entry view (`<Feature>View`) and state owner.
2. Ensure state owner is single-owner and `@MainActor` if UI-backed.
3. Move IO to Clients; update state owner to call clients.
4. Update imports and paths; keep API stable.
5. Add/adjust tests for state owner behavior.
6. Confirm no view performs IO.

Exit criteria (per feature):
- Compiles and tests pass.
- No behavior changes and no new dependencies.

---

## De-ELM refactor checklist (explicit owners, no actions)

Use this checklist per feature when removing `Action` enums and `send(_:)` flows.

### A) Owner type conversion (App + feature)
- Convert `AppStore` -> `AppModel` (`@Observable @MainActor`).
- Replace `AppStore.State` with direct stored properties on `AppModel`
  (or introduce explicit feature owner models where appropriate).
- Replace `Feature.State` types with `FeatureModel` (explicit owner).
- Remove `Feature.Action` enums entirely.
- Remove `send(_:)` and `handle*` routing.

### B) Method mapping (explicit intent)
- For each action, create a direct method on the owner:
  - `send(.reloadAll)` -> `reloadAll()`
  - `send(.importPack)` -> `importPack()`
  - `send(.sidebar(.setSearchText))` -> `sidebar.updateSearchText(_:)` or `updateSidebarSearchText(_:)`
  - `send(.composer(.setComposerValue))` -> `composer.updateValue(key:value:)` or `updateComposerValue(key:value:)`
  - `send(.preview(.setJSONPreview))` -> `preview.updateJSONPreview(_:)`
- Ensure names are verbs and express intent (per FOSA / Swift style).

### C) View integration
- Replace `store.send(...)` in views with explicit model calls.
- Replace `@Environment(AppStore.self)` with `@Environment(AppModel.self)`.
- Replace `bindingFor*` helpers to call explicit model methods (no action enums).
- Ensure any view `.task` or `.onChange` does not do IO; call model methods only.

### D) IO boundaries
- Keep IO only in owner types (AppModel / FeatureModel) and Clients.
- For any feature that does IO in a view (e.g., pack diff), move the call
  into the owner and expose a method (`computeDiff(...)`) that the view calls.

### E) Tests
- Update App tests to call model methods directly (no actions).
- Replace action-based tests with method-based tests.
- Keep deterministic output checks unchanged.

### F) Acceptance gate (per feature)
- No action enums remain for the feature.
- Views only call explicit model methods.
- All behavior unchanged and tests green.

---

## Feature-by-feature task list (concrete)

Use this as a scoped execution checklist. Each line should map to a small PR.

### App shell (global wiring)
- Rename `AppStore` -> `AppModel` (`@MainActor @Observable`). (done)
- Replace `state` access with direct stored properties or feature models. (done)
- Remove `Action` + `send(_:)` and `AppStore+SendHandlers.swift`. (done)
- Update environment injection in `PersonaKitAppMain` + `ContentView` + `PersonaKitCommands`. (done)
- Update bindings to call explicit model methods (no action enums). (done)

### Sidebar feature
Owner: `SidebarModel` (explicit model type).

Tasks:
- Replace `SidebarFeature.State` with `SidebarModel` properties.
- Delete `SidebarFeature.Action` enum.
- Move logic from `AppStore+SidebarFeature.swift` into `AppModel+Sidebar.swift` methods.
- Move filter + pin logic from `AppStore+Filters.swift` into `AppModel+Filters.swift` or `SidebarModel` methods.
- Update view call sites:
  - `store.send(.sidebar(.setSearchText))` -> `model.updateSidebarSearchText(_:)`
  - `store.send(.sidebar(.setSelectedTag))` -> `model.updateSidebarSelectedTag(_:)`
  - `store.send(.sidebar(.applyAllPersonasFilter))` -> `model.applyAllPersonasFilter()`
  - `store.send(.sidebar(.applySavedFilter))` -> `model.applySavedFilter(_:)`
  - `store.send(.sidebar(.saveCurrentFilter))` -> `model.saveCurrentFilter(name:)`
  - `store.send(.sidebar(.renameSavedFilter))` -> `model.renameSavedFilter(id:newName:)`
  - `store.send(.sidebar(.deleteSavedFilter))` -> `model.deleteSavedFilter(id:)`
  - `store.send(.sidebar(.setPinnedViewActive))` -> `model.togglePinnedViewActive()`
  - `store.send(.sidebar(.togglePinnedPersona))` -> `model.togglePinnedPersona(id:)`
  - `store.send(.sidebar(.requestSearchFocus))` -> `model.requestSidebarSearchFocus()`
  - `store.send(.sidebar(.requestSearchBlur))` -> `model.requestSidebarSearchBlur()`
  - `store.send(.sidebar(.setSearchFocused))` -> `model.setSidebarSearchFocused(_:)`
- Update tests:
  - `PinnedViewToggleTests`, `AppModelSavedFiltersTests`, `SidebarSearchEscapePolicyTests` to call methods.

### Composer feature
Owner: `ComposerModel` (explicit model type).

Tasks:
- Replace `ComposerFeature.State` with `ComposerModel` properties. (done)
- Delete `ComposerFeature.Action` enum. (done)
- Move logic from `AppStore+ComposerFeature.swift` into `AppModel+Composer.swift` methods. (done)
- Update view call sites: (done)
  - `store.send(.composer(.requestFocus))` -> `model.requestComposerFocus(sectionKey:)`
  - `store.send(.composer(.setSelectedPersonaID))` -> `model.selectPersona(id:)`
  - `store.send(.composer(.setComposerValue))` -> `model.updateComposerValue(key:value:)`
- Ensure preview recompute is still triggered on persona selection/value changes. (done)
- Update tests: (done)
  - `ComposerPreviewRecomputeTests` to call model methods.

### Preview feature
Owner: `PreviewModel` (explicit model type).

Tasks:
- Replace `PreviewFeature.State` with `PreviewModel` properties. (done)
- Delete `PreviewFeature.Action` enum. (done)
- Move logic from `AppStore+PreviewFeature.swift` into `AppModel+Preview.swift` methods. (done)
- Move JSON formatting from `AppStore+JSONPreview.swift` into `AppModel+JSONPreview.swift` or `PreviewModel`. (done)
- Update view call sites: (done)
  - `store.send(.preview(.setJSONPreview))` -> `model.updatePreviewJSON(_:)`
- Ensure debounce behavior stays deterministic. (done)
- Update tests: (done)
  - `JSONPreviewDebounceTests` to call model methods.

### Inspector feature
Owner: `InspectorModel` optional (only if needed); keep UI state local unless it needs ownership.

Tasks:
- Remove IO from `InspectorView`:
  - Move pack diff computation into `AppModel` method (or a `PackDiffClient`). (done)
  - `InspectorView` calls `model.computePackDiff(primary:comparison:)` and receives diff + diagnostics. (done)
- Keep view-local UI state for sheets/selection if no cross-feature ownership is required. (done)

### PersonaSwitcher feature
Owner: view-local state OK (UI-only); AppModel owns selection.

Tasks:
- Replace `store.send(.composer(.setSelectedPersonaID))` with `model.selectPersona(id:)`.
- Keep local query/selection state in view. (done)

### Shared clients + IO boundaries
- Move `AppClient` to `Shared/Clients`.
- Ensure any file/OS access is only in `AppModel` or Clients.
- Confirm no view performs IO after refactor.

---

## Phase 4 — App/CLI parity hardening

**Objective:** Ensure shared logic remains in Core and outputs match.

Checklist:
- Audit for duplicated logic between App and CLI.
- Move shared logic into `PersonaKitCore` where appropriate.
- Add parity tests for identical inputs.
- Confirm deterministic output and stable ordering.

Exit criteria:
- CLI and App parity tests green.
- No divergence in composition behavior.

---

## Phase 5 — Cleanup, docs, and release readiness

**Objective:** Remove legacy structure and confirm documentation accuracy.

Checklist:
- Remove empty/legacy folders.
- Update docs and internal references to new paths.
- Verify style guide and lint alignment.
- Capture final architecture summary in README or docs.

Exit criteria:
- Clean tree, docs updated, no regressions.

---

## Risk management

Primary risks and mitigations:
- **Scope creep:** enforce “no behavior changes” and per-feature move limits.
- **Hidden IO in views:** run targeted searches before/after each move.
- **Parity regressions:** add/extend parity tests early.
- **Concurrency issues:** ensure state owners are `@MainActor`.

---

## Sequencing rules (to prevent explosion)
- One feature per change set unless the feature is trivial.
- Move code before renaming symbols.
- Avoid refactoring logic while relocating files.
- Do not introduce new abstractions during moves.

---

## Open decisions (filled)
- Default owner shape: **Explicit model types** (`AppModel`, `SidebarModel`, `ComposerModel`, `PreviewModel`).
- Target top-level feature list: **Sidebar, Composer, Preview, Inspector, PersonaSwitcher**.
- Shared UI location: **Feature-local `Components/`** unless a component is reused.
- Client boundaries: **AppClient** (AppKit IO) under `Shared/Clients`; Core clients remain in core.
- Parity test approach: **Expand App/Core parity tests** for prompt/JSON output stability.

---

## Tracking log

Record each phase’s status, owner, and date here.

```
Phase 0:
Phase 1:
Phase 2: completed — Codex — 2026-01-27
Phase 3: completed — Codex — 2026-01-27
Phase 4: in progress — Codex — 2026-01-27
Phase 5:
```
