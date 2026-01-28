# Swift Testing Migration Plan

Goal: migrate all tests in `Tests/` from XCTest to Swift Testing, while preserving determinism,
coverage, and CI signal.

## Phase 1: Inventory + Guardrails
- Enumerate current XCTest test targets and files; classify by module (Core vs App).
- Identify XCTest-only utilities (e.g., XCTestCase base helpers) and map to Swift Testing equivalents.
- Define migration rules:
  - Preserve test names/intent.
  - Prefer value-typed helpers over inheritance.
  - Keep dependency overrides (swift-dependencies) explicit in each test.

Deliverable: checklist of tests to convert with owner modules and dependencies.

## Phase 2: Shared Test Utilities
- Create a small Swift Testing helper layer (if needed) under `Tests/Support/`:
  - Assertions and common setup helpers.
  - In-memory file clients or clocks used by multiple suites.
- Ensure helpers are framework-agnostic and do not introduce new dependencies.

Deliverable: reusable helpers available to both Core and App tests.

## Phase 3: Core Tests Migration
- Convert `PersonaKitCoreTests/*` XCTest suites to Swift Testing.
- Preserve deterministic ordering checks and failure messaging.
- Replace XCTest-specific APIs with Swift Testing `#expect` and structured tests.

Deliverable: all Core tests running under Swift Testing with matching coverage.

## Phase 4: App Tests Migration
- Convert `PersonaKitAppTests/*` to Swift Testing.
- Validate dependency overrides and UI-logic behaviors remain deterministic.
- Confirm new tests still run quickly and do not touch disk/network.

Deliverable: all App tests running under Swift Testing.

## Phase 5: Cleanup + CI
- Remove XCTest-only imports and any leftover `XCTestCase` scaffolding.
- Update the Xcode project or build scripts if needed (target settings, test discovery).
- Run full test suite to confirm parity with pre-migration behavior.

Deliverable: clean test targets, green `xcodebuild -project PersonaKit.xcodeproj -scheme PersonaKitApp -configuration Debug test`, and no XCTest dependencies in test code.

## Acceptance Criteria
- All tests are implemented in Swift Testing.
- No behavioral regressions or coverage gaps.
- `xcodebuild -project PersonaKit.xcodeproj -scheme PersonaKitApp -configuration Debug test` passes without XCTest-based suites.
