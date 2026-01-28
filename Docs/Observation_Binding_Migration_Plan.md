# Observation Binding Migration Plan

Goal: replace singleton `bindingFor...` helpers with `@Bindable` where appropriate,
while preserving deterministic behavior and keeping changes small and reviewable.

Non-goals:
- No schema changes.
- No new features or behavior changes.
- No refactors unrelated to bindings.

## Phase 0: Inventory and guardrails (no code changes)
- Locate all `bindingFor...` call sites.
- Classify each helper as:
  - Singleton binding (no parameters, one property)
  - Keyed/parameterized binding (requires a key)
- Confirm deployment target supports Observation / `@Bindable`.
- Define acceptance criteria (tests pass, no behavior regressions).

Phase 0 notes:
- Deployment target: `Package.swift` sets `.macOS(.v26)` so Observation / `@Bindable` is available.
- Current `bindingFor...` usage:
  - Singleton:
    - `PreviewModel+Bindings.bindingForJSONPreview()` used by `PreviewView`.
    - `AppModel+Bindings.bindingForSelectedPersonaID()` used by `ContentView`.
  - Keyed/parameterized:
    - `ComposerModel+Bindings.bindingForComposerValue(key:)` used by `ComposerView`.
  - Forwarders:
    - `AppModel+Bindings.bindingForJSONPreview()` and `bindingForComposerValue(key:)` forward to feature models.

## Phase 1: POC on one singleton binding
- Convert JSON preview binding to `@Bindable` in the view.
- Remove the `bindingForJSONPreview()` helper.
- Preserve side effects deterministically (e.g., `didSet` or existing callback).
- Run tests; commit.

## Phase 2: Remaining singleton bindings
- Convert remaining singleton bindings (e.g., selected persona) to `@Bindable`.
- Remove corresponding helpers and call sites.
- Run tests; commit.

## Phase 3: Keyed/parameterized bindings decision
- Evaluate composer value binding.
- Default to keeping the helper unless a simpler alternative is approved.
- If change is approved, keep it minimal; run tests; commit.

## Phase 4: Docs and cleanup
- Update `Docs/ArchitectureDefaults.md` with `@Bindable` guidance if needed.
- Final test run; commit.
