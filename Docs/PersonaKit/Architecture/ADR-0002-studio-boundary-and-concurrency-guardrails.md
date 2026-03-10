# ADR-0002: Studio Boundary and Concurrency Guardrails

- Status: Accepted
- Date: 2026-03-06
- Owners: PersonaKit maintainers

## Context

Recent Studio hardening work introduced durable guardrails that should not live
only in plan docs or chat history:

1. UI-to-store boundary hardening in Sessions panel flows.
2. Cancellation and freshness protections for async preview/map loading.
3. Repository-wide policy enforcement around `@unchecked Sendable`.

These decisions are architectural constraints, not temporary implementation
details, and must be preserved for future contributors and implementation agents.

## Decision

Adopt the following repository-level rules as stable architecture policy:

1. Studio Views MUST depend on `WorkspaceStore` surface APIs only.
   Views MUST NOT call `workspaceStore.sessionFeatureModel` internals directly.
2. Session preview/map async workflows MUST use freshness and cancellation
   guards:
   - cancel superseded work,
   - gate state application by active request identity/workspace,
   - avoid stale result publication after cancellation/workspace changes.
3. Async test synchronization MUST prefer actor/continuation-based patterns.
   Semaphore-based coordination is not a default strategy when practical async
   alternatives exist.
4. `@unchecked Sendable` is prohibited by default in all code and tests.
   It MAY be used only with explicit repository-owner approval for the exact
   source location, recorded in:
   `Docs/PersonaKit/Architecture/unchecked-sendable-approvals.txt`.
5. Repository validation is the enforcement mechanism for this policy:
   - `Scripts/validate-repo.sh` checks module boundaries and `@unchecked Sendable`
     approval registry compliance.

## Consequences

Positive:

- Stronger mutation-boundary discipline between SwiftUI Views and owner/store
  layers.
- Lower risk of stale async state publication and cancellation regressions.
- Deterministic policy enforcement for concurrency exceptions.

Tradeoffs:

- Some implementation convenience is intentionally disallowed.
- New store API surface may be required before adding UI behavior.
- Exception paths require explicit human approval and registry maintenance.

## Non-Goals

- This ADR does not redesign Studio product behavior.
- This ADR does not remove feature-model internals from store implementation.
- This ADR does not permit autonomous broad-scope refactors.

## Rollout Notes

- Guardrails are reflected in PersonaKit personas/directives for Studio lanes.
- Validation script checks are treated as blocking gates for integration.
- Future boundary/cancellation changes should extend tests before behavior
  changes ship.
