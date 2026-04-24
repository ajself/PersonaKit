# Repository Architecture Defaults

Use this essential when the active contract needs the repo's default implementation shape.

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
