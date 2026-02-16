# ADR-0001: Unified FOSA Source Organization

- Status: Accepted
- Date: 2026-02-15
- Owners: PersonaKit maintainers

## Context

PersonaKit currently mixes app and core source roots (`Apps/...`, `Sources/...`)
and has placeholder directories that are not part of active build targets.
That drift makes ownership boundaries less obvious and increases maintenance
cost during feature and architecture work.

The repo-local PersonaKit guidance requires feature-oriented organization,
explicit ownership, and IO boundaries. We need an implementation contract that
aligns code structure, target boundaries, and documentation with that guidance.

## Decision

Adopt a unified FOSA direction for implementation work:

1. Target source layout converges on:

```text
Sources/
  App/
  Features/
  Shared/
Tests/
  Features/
  Shared/
```

2. Default owner shape is feature-owned models with explicit mutation methods.
3. IO remains behind clients/managers and is injected for tests.
4. Internal modules may be reorganized to role-based boundaries while keeping
   user-facing entrypoints stable through compatibility wrappers where needed.
5. The refactor is delivered in milestone PRs with explicit review stop points.

## Consequences

Positive:

- Clearer ownership and feature boundaries.
- Better testability and maintainability.
- Consistent architecture expectations across Studio and core code.

Tradeoffs:

- Path churn and import churn during migration.
- Temporary wrapper code may be required between milestones.
- Documentation and pack metadata must be kept in sync with migration status.

## Non-Goals

- This ADR does not redefine product scope.
- This ADR does not introduce runtime agent execution.
- This ADR does not require a single massive one-shot refactor.

## Rollout Notes

- Architecture defaults are defined in `App/ArchitectureDefaults.md`.
- Detailed execution and git workflow were tracked in the FOSA refactor plan,
  and the migration completed on 2026-02-16.
