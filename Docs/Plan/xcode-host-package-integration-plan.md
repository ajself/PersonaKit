# PersonaKit Xcode Host + Package Integration Plan

Date: 2026-03-06
Status: In Progress

## Summary

This plan aligns the new Xcode workspace targets with the existing Swift
package architecture so the macOS app and CLI run real PersonaKit behavior
instead of template placeholders.

Primary objective:

1. Keep `Sources/` and `Tests/` as the source of truth for product logic.
2. Keep Xcode project folders as thin host wrappers.
3. Ensure target wiring and test ownership are explicit and deterministic.

## Working Model

1. Use PersonaKit personas and directives to define lane constraints.
2. Use three lanes only:
   - Architecture/Ownership
   - Target Wiring
   - Tests/Validation
3. Enforce human stop points before implementation merge.

## Lane 1: Architecture and Ownership (blocking)

- Persona: `architectural-editor`
- Directive: `review-architecture-invariants`
- Kits: `architectural-editor-core`, `repo-constraints`, `swift-style`
- Scope: define what belongs to App host, CLI host, package `Sources`, and test
  roots.

Deliverables:

1. Ownership matrix by file/path class (host-only vs package-owned).
2. Migration list of misplaced files to move, keep, delete, or wrap.
3. Target membership contract:
   - what each Xcode target compiles directly,
   - what each Xcode target consumes from Swift package products/modules.

Stop point:

1. Human approval required before lane 2 code wiring changes are finalized.

## Lane 2: Target Wiring (implementation)

- Persona: `studio-integration-coordinator`
- Directive: `integrate-lanes-with-stop-points`
- Kits: `repo-constraints`, `swift-style`, `swiftui-style`
- Scope: apply lane 1 ownership decisions to Xcode target wiring.

Implementation goals:

1. macOS app target launches real Studio flow (not template `ContentView`).
2. CLI target invokes the real CLI entrypoint from package-owned code.
3. Xcode project removes or isolates template scaffolding once replaced.
4. No scope expansion into unrelated feature work.

Stop point:

1. Human review of project wiring diff before integration closeout.

## Lane 3: Tests and Validation

- Persona: `studio-coverage-architect`
- Directive: `expand-core-coverage`
- Kits: `repo-constraints`, `swift-style`
- Scope: run ownership questions for tests and enforce the final split.

Test ownership goals:

1. Package logic tests stay under `Tests/`.
2. Host-specific app/unit/UI checks stay in Xcode test targets only when needed.
3. Remove duplicate or placeholder test scaffolding that does not validate real
   behavior.
4. Add/update tests for wiring contracts where regressions are likely.

Stop point:

1. Human review of test ownership and coverage deltas before final merge.

## Execution Order

1. Lane 1 discovery and ownership matrix (blocking).
2. Human stop-point approval of lane 1 matrix.
3. Lane 2 and lane 3 execute in parallel with disjoint ownership.
4. Integration validation:
   - `make doctor`
   - `make build-app`
   - `make build-cli`
   - `make test` and/or `swift test` as applicable
   - `./Scripts/validate-repo.sh`
5. Final integration review and commit series.

## Acceptance Criteria

1. Running the macOS app uses package-backed Studio behavior.
2. Running the CLI target exercises package-backed CLI behavior.
3. `Sources/` and `Tests/` are authoritative for shared logic and coverage.
4. Xcode host files are minimal and intentional.
5. Validation/test gates pass with deterministic outcomes.

## Kickoff Status

1. Plan created.
2. Lane 1 started: ownership matrix discovery in progress.

## Lane 1 Findings (2026-03-06)

### Current Wiring Summary

1. macOS host scheme `PersonaKit` runs the template app entry in
   `PersonaKit/PersonaKit/PersonaKitApp.swift`, which renders
   `PersonaKit/PersonaKit/ContentView.swift` (`Hello, world!`).
2. Real Studio behavior lives in package-owned
   `Sources/App/Studio/PersonaKitStudioApp.swift` and
   `Sources/Features/Studio/...`.
3. Xcode CLI host `PersonaKit/PersonaKitCLI/main.swift` is template-only and
   does not delegate to package CLI entrypoints.
4. Package CLI behavior is correctly owned by `Sources/App/CLI` and
   `Sources/Features/CLI`.
5. Package tests under `Tests/` are the real behavioral suite; Xcode test
   targets are still template scaffolding.

### Ownership Matrix

| Area | Owner | Keep In | Notes |
| --- | --- | --- | --- |
| App bundle host shell | Xcode host target | `PersonaKit/PersonaKit/` | Keep assets, signing, host bootstrap only. |
| Studio app behavior and UI | Swift package | `Sources/App/Studio`, `Sources/Features/Studio`, `Sources/Shared` | Source of truth for macOS app behavior. |
| CLI host shell | Xcode host target | `PersonaKit/PersonaKitCLI/` | Keep only a tiny wrapper entrypoint. |
| CLI behavior | Swift package | `Sources/App/CLI`, `Sources/Features/CLI`, `Sources/Shared` | Source of truth for CLI commands and logic. |
| Package/unit behavior tests | Swift package tests | `Tests/**` | Primary regression and deterministic behavior coverage. |
| Host wiring and UI launch smoke tests | Xcode test targets | `PersonaKit/PersonaKitTests`, `PersonaKit/PersonaKitUITests` | Keep only host integration/UI launch checks. |

### Minimal Migration Steps

1. Rewire macOS host `PersonaKitApp` to launch package-backed Studio behavior
   (remove template `ContentView` ownership).
2. Rewire CLI host `main.swift` to delegate into package CLI entrypoint.
3. Expose an importable package product/API for host delegation where needed
   (instead of relying on executable product linking semantics).
4. Replace/remove template-only tests in Xcode test targets and keep package
   logic tests in `Tests/`.
5. Resolve test-target naming ambiguity between package `PersonaKitTests` and
   Xcode `PersonaKitTests` (recommended rename in Xcode target).

### Stop-Point Outcome

1. Lane 1 discovery complete.
2. Ready for human approval to start Lane 2 (target wiring) and Lane 3
   (tests/validation) implementation.

## Lane 2 Progress (2026-03-06)

Status: Implemented in working tree, pending review.

1. Added package library products for host integration:
   - `StudioFeatures`
   - `ContextCLI`
2. Rewired Xcode app target dependency from executable package product usage to
   `StudioFeatures`.
3. Rewired Xcode CLI target dependency to `ContextCLI`.
4. Updated host app entrypoint to render `StudioRootView` with `WorkspaceStore`
   and retained open-workspace command behavior.
5. Updated host CLI entrypoint to call `ContextCLIEntrypoint.main()`.
6. Removed template `ContentView.swift`.

## Lane 3 Progress (2026-03-06)

Status: Initial host-test cleanup implemented, pending deeper coverage pass.

1. Replaced placeholder Xcode unit test with launch-configuration behavior tests.
2. Replaced placeholder UI tests with Studio launch smoke assertions.
3. Kept package behavioral test ownership unchanged under `Tests/`.

## Validation Snapshot

1. `swift build` passed.
2. `xcodebuild -list -workspace PersonaKit.xcworkspace` passed.
3. `xcodebuild -workspace PersonaKit.xcworkspace -scheme PersonaKitCLI -configuration Debug build` passed.
4. `xcodebuild -workspace PersonaKit.xcworkspace -scheme PersonaKit -configuration Debug build` passed.
5. `swift test` passed.
6. `xcodebuild ... test` invocations reported test start completion but were
   inconclusive in this environment due process-hang behavior after execution.
7. Direct host-CLI runtime smoke check passed:
   - `PersonaKitCLI list personas --root /Users/ajself/Code/PersonaKit/.personakit`
     returned real persona IDs (not template output).
8. Direct host-app binary smoke launch was inconclusive in this environment:
   process exited quickly with no stderr/stdout, consistent with headless launch
   constraints outside a normal interactive app session.
