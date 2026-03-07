# PersonaKit Xcode Host + Package Integration Plan

Last Updated: 2026-03-07
Status: Implementation complete in local `main`; pending remote push and final interactive smoke confirmation.

## Goal

Align the Xcode host workspace with package-owned app and CLI logic so host targets are thin wrappers and shared behavior remains in `Sources/` and `Tests/`.

## Outcome Snapshot

1. App host now launches package-backed Studio UI instead of template `ContentView`.
2. CLI host now delegates to package-backed CLI entrypoint.
3. Template host scaffolding has been reduced.
4. Xcode host test target naming now avoids ambiguity with SwiftPM tests.

## Delivered Work (Commit Evidence)

1. `57ab979` `feat(xcode): scaffold PersonaKit workspace with app and cli targets`
2. `fe52aa5` `build(make): adopt xcodebuildmcp-first workflow`
3. `9b08c7d` `feat(xcode): wire host app and cli to package modules`
4. `01389f3` `test(xcode): replace template host tests with studio launch smoke`
5. `c5f59e3` `refactor(xcode): rename host unit test target to PersonaKitHostTests`

## Current Ownership Model (Confirmed)

1. Host app shell: `PersonaKit/PersonaKit/`
2. Host CLI shell: `PersonaKit/PersonaKitCLI/`
3. Host unit/UI smoke tests: `PersonaKit/PersonaKitHostTests/`, `PersonaKit/PersonaKitUITests/`
4. Shared application logic and features: `Sources/**`
5. Shared behavioral tests: `Tests/**`

## Validation Status

Passed in this environment:

1. `swift build`
2. `swift test`
3. `xcodebuild -list -workspace PersonaKit.xcworkspace`
4. `xcodebuild -workspace PersonaKit.xcworkspace -scheme PersonaKit -configuration Debug build`
5. `xcodebuild -workspace PersonaKit.xcworkspace -scheme PersonaKitCLI -configuration Debug build`

Known caveat:

1. `xcodebuild ... test` in this headless environment has shown inconclusive post-run hang behavior, so final interactive verification should be performed in a local GUI/Xcode session.

## Remaining Follow-Up

1. Push local `main` commits to origin (`ahead 4` at end-of-day snapshot).
2. Run interactive app smoke in Xcode and confirm Studio root behavior in normal desktop session.
3. Run host test targets interactively once to close the headless-test caveat.
4. After those checks pass, archive or remove this plan doc per `Docs/Plan` temp-convention.
