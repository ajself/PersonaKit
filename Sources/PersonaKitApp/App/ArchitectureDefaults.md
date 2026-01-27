# Architecture Defaults — FOSA

## Owner shape
**Default:** Explicit model (e.g. `FeatureModel`)

## Concurrency
- UI owner types are `@MainActor`
- Strict Swift concurrency checks are enabled

## Clients & IO
- All IO routed through Clients
- No IO in SwiftUI views

## Testing
- Tests required for non-trivial behavior
- Owner types are the primary unit under test
