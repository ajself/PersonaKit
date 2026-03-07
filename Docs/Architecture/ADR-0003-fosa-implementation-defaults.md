# ADR-0003: FOSA Implementation Defaults

- Status: Accepted
- Date: 2026-03-06
- Owners: PersonaKit maintainers

## Context

PersonaKit already established major architecture direction in `ADR-0001` and
concurrency and boundary guardrails in `ADR-0002`. We still need one concise,
stable defaults document that implementation lanes can apply consistently
without reinterpreting those decisions each time.

## Decision

Adopt the following implementation defaults for repository work:

1. Owner shape defaults to explicit feature-owned models, with a small app
   coordinator only when cross-feature orchestration is required.
2. Concurrency defaults:
   - UI owner types are `@MainActor`.
   - strict Swift concurrency checks remain enabled.
   - long-running tasks are owned and cancelled by the owning model.
3. Clients and IO defaults:
   - IO is routed through clients/managers at feature or shared boundaries.
   - SwiftUI Views do not perform IO directly.
   - dependency injection is required for testability.
4. Testing defaults:
   - tests are required for non-trivial behavior.
   - feature owners and shared domain modules are the primary unit under test.
   - behavior-preserving refactors keep regression coverage green.
5. Source organization target remains:

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

## Consequences

Positive:

- Faster implementation alignment across lanes.
- Fewer architecture debates for routine feature work.
- Better consistency between code, tests, and PersonaKit guidance.

Tradeoffs:

- Some implementation shortcuts are intentionally disallowed.
- Defaults require deliberate exceptions when product constraints differ.

## Non-Goals

- This ADR does not replace `ADR-0001` or `ADR-0002`.
- This ADR does not authorize autonomous scope expansion.
- This ADR does not introduce runtime command execution policies.

## Rollout Notes

- This ADR supersedes the previous free-form `ArchitectureDefaults.md` doc.
- Future architecture policy updates should either amend this ADR or add a new
  ADR when the change is materially different.
