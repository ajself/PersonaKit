# Architecture Defaults — FOSA

This file defines the architecture defaults for implementation work in this
repository.

## Owner shape

Default: explicit feature-owned models, with a small app coordinator only when
cross-feature orchestration is required.

## Concurrency

- UI owner types are `@MainActor`.
- Strict Swift concurrency checks remain enabled.
- Long-running tasks are owned and cancelled by the owning model.

## Clients and IO

- All IO is routed through clients/managers at feature or shared boundaries.
- SwiftUI views do not perform IO directly.
- Dependency injection is required for testability.

## Testing

- Tests are required for non-trivial behavior.
- Feature owners and shared domain modules are the primary unit under test.
- Behavior-preserving refactors keep regression coverage green.

## Source organization

Target architecture is unified under:

```text
Sources/
  App/
  Features/
  Shared/
Tests/
  Features/
  Shared/
```

During migration, temporary compatibility wrappers are allowed to preserve
external user-facing entrypoints (`personakit`, `PersonaKit`) until cutover
milestones complete.
