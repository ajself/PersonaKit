# Milestone 1 - App UDF refactor + dependency scaffolding

Date: 2026-01-24
Status: complete

## Goals
- Move PersonaPadApp to a strict UDF shape (`State`/`Action`/`send`).
- Adopt Swift 6.2 SwiftUI style guide patterns (`@Observable`, `@MainActor`).
- Introduce swift-dependencies clients for app + core IO/logging.
- Keep behavior identical (no composition changes).

## Changes
- Added dependency clients (swift-dependencies):
  - `AppClient` for UI-only side effects (open panel, alerts, open URL, clipboard).
  - `FileClient` for filesystem access.
  - `LoggerClient` for structured logging.
- Refactored `AppStore` into `@Observable` with nested `State` + `Action` + `send`.
- App views now read via `store.state` and dispatch via `store.send(...)`.
- Commands route through `send` rather than calling store methods directly.
- Added binding helpers on `AppStore` to keep view layer thin.

Files touched:
- Package.swift
- Package.resolved
- Sources/PersonaPadApp/AppStore.swift
- Sources/PersonaPadApp/ComposerView.swift
- Sources/PersonaPadApp/ContentView.swift
- Sources/PersonaPadApp/InspectorView.swift
- Sources/PersonaPadApp/PersonaPadAppMain.swift
- Sources/PersonaPadApp/PersonaPadCommands.swift
- Sources/PersonaPadApp/PersonaSwitcherView.swift
- Sources/PersonaPadApp/PreviewView.swift
- Sources/PersonaPadApp/SidebarView.swift
- Sources/PersonaPadApp/Dependencies/AppClient.swift
- Sources/PersonaPadCore/Dependencies/FileClient.swift
- Sources/PersonaPadCore/Dependencies/LoggerClient.swift

## Tests
- swift test
- ./Scripts/release-check.sh

## Context for a new agent
- AppStore is now the only mutation point; views should never mutate state directly.
- Side effects in the app must go through `AppClient` or other dependencies.
- `@ObservationIgnored` is used for dependency properties inside `@Observable` stores.
- The dependency scaffolding was introduced ahead of core/CLI refactors.

## Follow-ups
- Preview JSON formatting still uses `DispatchQueue.main.asyncAfter`.
  If stricter dependency control is required, move that debounce into a store
  using `@Dependency(\.continuousClock)` with a cancellable task.

## Acceptance criteria
- App compiles with Swift 6.2 language mode.
- UI behavior matches pre-refactor behavior.
- `swift test` and `./Scripts/release-check.sh` pass.

## Relevant commits
- c5b4ac7 feat: add dependency clients scaffold
- c591bb6 refactor(app): migrate to UDF store and @Observable
