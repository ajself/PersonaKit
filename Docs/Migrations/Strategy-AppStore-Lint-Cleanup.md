# Strategy - AppStore Lint Cleanup (SwiftUI Style Guide Alignment)

Date: 2026-01-25  
Status: in progress

## Goal
Reduce SwiftLint "serious" violations in the app target by:
- lowering cyclomatic complexity and function length in `AppStore`
- bringing `AppStore` under type/file length thresholds
- fixing attribute placement and import ordering in app views

Behavior must remain identical. No composition changes.

## Constraints (Non-Negotiable)
- Preserve deterministic output and app/CLI parity.
- Maintain UDF (`State`/`Action`/`send`) and main-actor isolation.
- No new product features or scope expansion.
- Keep changes small and reversible.

## Scope
In-scope:
- `Sources/PersonaPadApp/AppStore.swift` refactor (split into extensions/files).
- App view formatting fixes (attribute placement + import ordering).

Out-of-scope:
- Core/CLI/Validator refactors (separate milestones).
- Schema or composition semantics.

## Strategy Overview
1) **Decompose AppStore into focused extensions** to reduce type/file length.
2) **Split the `send(_:)` logic into small handlers** to lower cyclomatic complexity.
3) **Fix attribute placement and import ordering** across app views.
4) **Re-run format + lint + tests** to confirm compliance and no regressions.
5) **Commit after each phase** before proceeding to the next.

## Detailed Steps

### 1) AppStore split (structure only)
Create file-local extensions (same module) to keep context small:
- `AppStore+Bindings.swift` (bindings)
- `AppStore+Reload.swift` (reloadAll + recomputePreview)
- `AppStore+ImportReveal.swift` (import/reveal/remove actions)
- `AppStore+Filters.swift` (saved filters + pinned)
- `AppStore+JSONPreview.swift` (JSON preview state + formatting)

Keep `State`, `Action`, and initializer in `AppStore.swift`.

Completion gate:
- Ask to start Phase 1 before editing.
- Commit Phase 1 changes before starting Phase 2.

### 2) Reduce `send(_:)` complexity
Keep `Action` API intact. Implement a staged handler pipeline:

```
func send(_ action: Action) {
  if handleLifecycle(action) { return }
  if handleFocus(action) { return }
  if handleSelection(action) { return }
  if handleFiltering(action) { return }
  if handlePinned(action) { return }
}
```

Each handler is a small switch over a subset of cases. Target:
- `send(_:)` complexity <= 10
- each handler complexity <= 10
- `send(_:)` body <= 60 lines

Completion gate:
- Ask to start Phase 2 before editing.
- Commit Phase 2 changes before starting Phase 3.

### 3) View attribute placement + imports
Apply SwiftLint attribute rule: attributes with arguments go on their own line:

```
@Environment(AppStore.self)
private var store
```

Do this for `@Environment`, `@Binding`, and any `@FocusState` with arguments.
Ensure imports are sorted in app view files.

Completion gate:
- Ask to start Phase 3 before editing.
- Commit Phase 3 changes before starting Phase 4.

### 4) Validation
Run:
- `swift-format format --configuration swift-format.json --in-place --recursive Sources Tests`
- `swiftlint --config swiftlint.yml`
- `swift test`
- `./Scripts/release-check.sh`

Completion gate:
- Ask to start Phase 4 before running commands.
- Commit Phase 4 changes before finishing.

## Session State (2026-01-25)
Completed:
- Phase 1: AppStore split into extensions.
- Phase 2: `send(_:)` handler pipeline with smaller handlers.
- Phase 3: Attribute placement and import ordering in app views.
- Phase 4: Format, lint, tests, release check; fixed extension access regression.

Commits:
- `refactor(app): split AppStore into extensions`
- `refactor(app): split send handlers`
- `style(app): fix attribute placement`
- `fix(app): restore AppStore extension access`

Validation results:
- `swift-format` ran successfully.
- `swift test` passed.
- `./Scripts/release-check.sh` passed.
- `swiftlint` still reports existing warnings and 5 serious errors outside this refactor scope.

Outstanding (app target):
- `AppStore+Reload.swift` still over cyclomatic complexity and function body length limits.

Out of scope (existing serious SwiftLint errors):
- `Sources/PersonaPadCore/Metadata.swift` (large_tuple)
- `Sources/PersonaPadCLI/main.swift` (cyclomatic_complexity, function_body_length)
- `Sources/PersonaPadSchemaValidate/main.swift` (cyclomatic_complexity)
- `Tests/PersonaPadCoreTests/PersonaPadCoreTests.swift` (type_body_length)

Next suggested step:
- Reduce `reloadAll()` complexity/body length in `Sources/PersonaPadApp/AppStore+Reload.swift` without behavior changes.

## Acceptance Criteria
- AppStore type body length <= 450 lines (SwiftLint).
- `send(_:)` cyclomatic complexity <= 10.
- No SwiftLint "serious" violations in app target.
- Tests and release check pass with identical behavior.

## Notes for New Agents
- Do not change Action cases or view call sites unless required.
- Keep UDF and dependency usage intact.
- JSON preview debounce must remain dependency-controlled via `continuousClock`.
