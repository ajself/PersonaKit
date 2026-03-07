# Repository Architecture Defaults

PersonaKit implementation work follows Feature-Oriented SwiftUI Architecture
(FOSA) defaults with explicit ownership and deterministic boundaries.

## Defaults

- Organize by feature first, then shared layers.
- Use explicit feature owners for mutable state.
- Keep IO behind clients/managers and inject dependencies for tests.
- Keep behavior deterministic across runs.

## Target Layout

```text
Sources/
  App/
  Features/
  Shared/
Tests/
  Features/
  Shared/
```

## Working Rules

- Avoid unrelated architecture rewrites outside approved milestones.
- Keep external user-facing entrypoints stable during migration unless a
  milestone explicitly defines cutover.
- Use milestone stop points and human review before advancing.
