# Architecture Defaults — FOSA

## Owner shape
**Default:** Explicit model (e.g. `FeatureModel`)
- Feature views bind `@Environment(FeatureModel.self)` where possible.
- `AppModel` coordinates IO and cross-feature orchestration only.
- Pass shared indexes/diagnostics as explicit view inputs (avoid reaching into `AppModel` from feature views).
- Avoid `State`/`Action` routing; model methods are the mutation surface.

## Concurrency
- UI owner types are `@MainActor`
- Strict Swift concurrency checks are enabled

## Clients & IO
- All IO routed through Clients
- No IO in SwiftUI views
- Feature models may call back into `AppModel` for orchestration (e.g. preview recompute).
- Use `swift-dependencies` for IO/services inside models (file, clock, uuid, app), not to inject view state.

## Testing
- Tests required for non-trivial behavior
- Owner types are the primary unit under test
- App/Core parity tests must guard prompt + JSON rendering
