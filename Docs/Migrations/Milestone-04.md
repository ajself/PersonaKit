# Milestone 4 - Parity Tests and Release Gates

Date: 2026-01-24
Status: complete

## Goals
- Lock in parity tests for composition and validation paths.
- Keep release-check green and usable as a deterministic gate.
- Remove remaining direct file system access in app utilities.
- Ensure SwiftLint scans Sources/ and Tests/.

## Changes
- Pack diff input building now routes through FileClient via Dependencies.
- SidebarSearchEscapePolicy is now a static-only enum.
- PersonaSwitcherView formatting aligned with style guide.
- SwiftLint includes Sources/ and Tests/.

Files touched:
- Sources/PersonaPadApp/PackDiffInputBuilder.swift
- Sources/PersonaPadApp/PersonaSwitcherView.swift
- Sources/PersonaPadApp/SidebarSearchEscapePolicy.swift
- swiftlint.yml

## Tests
- swift test
- ./Scripts/release-check.sh

## Parity Coverage
- Core tests assert CLI prompt output matches PromptComposer.
- Core tests assert CLI resolved JSON matches core encoding.
- Validator diagnostics include fix hints and user-facing messages.

## Context for a new agent
- Milestones 1-3 are already in git history (app/core/cli refactors).
  - App UDF + @Observable refactor: c591bb6
  - Core IO via FileClient: 3e32530
  - CLI filesystem access via dependencies: db09cbf
- Remaining known deviation from strict dependency usage:
  - Resolved on 2026-01-25: preview JSON formatting debounce lives in `AppStore`
    via `@Dependency(\.continuousClock)` with a cancellable task
    (`Sources/PersonaPadApp/AppStore+JSONPreview.swift`).

## Acceptance criteria
- swift test and ./Scripts/release-check.sh pass.
- No behavior change in composition semantics.
- App/CLI parity tests cover core flows.
