# Repository Architecture Defaults

Use this essential when the active contract needs the repo's default implementation shape.

## Defaults

- Organize by feature first, then shared layers.
- Use one explicit feature owner for mutable state.
- Keep IO behind clients/managers and inject dependencies for tests.
- Preserve deterministic behavior and explicit mutation paths.

## Deviation Rule

- If a feature needs a different architecture shape, document the reason and tradeoff in the change.

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
