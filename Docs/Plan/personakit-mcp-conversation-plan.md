# PersonaKit MCP Conversation Plan

Last Updated: 2026-03-07
Status: Active (M1 complete, M2 initial implementation complete)

## Grounding Session

This plan is grounded in local PersonaKit session:

- Session: `architectural-editor-review`
- File: `.personakit/Sessions/architectural-editor-review.session.json`
- Persona: `architectural-editor`
- Directive: `review-architecture-invariants`

Reason for grounding choice:

1. The directive enforces invariant-first planning before broad implementation.
2. The persona is optimized for explicit boundaries and deterministic behavior.
3. This matches the goal: make PersonaKit API concepts easier to discuss and easier for MCP to operate.

## Goal

Make personas, directives, kits, sessions, and API capabilities easy to discover, explain, compare, and recommend through MCP-first workflows.

## Scope

In scope:

1. Domain vocabulary and relationship map for PersonaKit entities.
2. MCP catalog surfaces for entity discovery and navigation.
3. Discussion primitives for explanation/comparison/recommendation workflows.
4. Deterministic behavior and test coverage for catalog and recommendation paths.
5. Docs and error UX updates for operational clarity.

Out of scope:

1. Mutating pack content through MCP (MCP remains read-only for pack data).
2. Unrelated CLI redesign outside MCP discoverability.
3. Feature work unrelated to PersonaKit domain/API explainability.

## Milestones

### M1: Domain Map + Catalog Surfaces

Objective:

- Establish one canonical entity map and expose structured MCP discovery surfaces.

Deliverables:

1. `Docs/Architecture/personakit-domain-map.md` (canonical model and relationships).
2. MCP catalog resources for high-signal listing by entity type.
3. Stable schema for list payloads and local-first scope metadata.

Acceptance criteria:

1. A user can list and inspect entities by type from MCP without ambiguity.
2. Relationships are documented and align with runtime behavior.
3. Catalog output is deterministic across repeated runs on the same root.

Progress:

1. Complete on 2026-03-07 (initial slice).
2. Delivered canonical domain map and MCP catalog resources (`personakit://catalog/*`).
3. Added deterministic tests for catalog listing and payload shape.

### M2: Conversation Primitives + Recommendation Policy

Objective:

- Make discussion and selection workflows direct and predictable.

Deliverables:

1. MCP primitives for explain/compare/recommend/trace workflows.
2. Deterministic ranking policy for recommendations.
3. Scope precedence and fallback behavior documented with examples.

Acceptance criteria:

1. Users can ask “what should I use for X?” and get stable recommendations.
2. Recommendation outputs cite the exact persona/directive/kit/session used.

Progress:

1. Initial implementation complete on 2026-03-07.
2. Added MCP tools:
   - `personakit_explain_entity`
   - `personakit_compare_entities`
   - `personakit_recommend_session`
   - `personakit_trace_session`
3. Added deterministic recommendation policy and tool tests.
4. Further iteration may refine ranking heuristics and richer compare output.

### M3: End-to-End Tests + Error UX + Starter Flows

Objective:

- Make common interactions robust and easy for day-to-day use.

Deliverables:

1. Golden/integration tests for common MCP conversation scenarios.
2. Error contracts with actionable recovery hints.
3. `Docs/MCP/Starter-Flows.md` recipes for practical usage.

Acceptance criteria:

1. Common asks pass deterministic tests.
2. Errors are explicit and recoverable.
3. Onboarding docs are sufficient for first-use success.

## Execution Plan (Current)

1. Author and commit this plan doc (complete).
2. Start M1 with domain map draft and MCP catalog surface inventory (complete).
3. Implement M1 in small, reviewable increments with tests (complete).
4. Implement M2 discussion primitives and deterministic recommendation policy (initial complete).
5. Continue into M3 (E2E + error UX + starter flows).

## Risks and Mitigations

1. Risk: catalog outputs become noisy or redundant.
   - Mitigation: define minimal canonical schemas and one index-first entrypoint.
2. Risk: divergence between docs and runtime behavior.
   - Mitigation: add tests that enforce doc-described precedence and relationships.
3. Risk: recommendation behavior appears non-deterministic.
   - Mitigation: encode explicit ranking policy and fixture-driven tests.
