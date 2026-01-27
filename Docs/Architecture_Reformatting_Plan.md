# Architecture Reformatting Plan — FOSA Alignment

This plan tracks a phased, low-risk reformatting of PersonaKit’s app architecture to
align with Feature-Oriented SwiftUI Architecture (FOSA). It prioritizes determinism,
scope control, and predictable execution.

## Sources of truth (read before starting)
- PersonaKit v1 Scope & Contract: `Docs/PersonaKit_v1_Scope_and_Contract.md`
- PersonaKit 2.0 Prompt Pack: `Docs/PersonaKit_2_0_Prompt_Pack_Index.md`
- PersonaKit agent rules: `AGENTS.md`
- FOSA rules and defaults: `FOSA` repo docs (`AGENTS.md`, `STYLE_GUIDE.md`, `App/ArchitectureDefaults.md`)

## Guardrails (non-negotiable)
- No behavior changes to composition semantics or schema rules.
- No new product features or scope expansion.
- Determinism preserved: same input -> same output.
- IO never performed in SwiftUI views.
- Single-owner state; mutations traceable through named methods/actions.
- App and CLI stay in parity for identical inputs.

## Non-goals
- No redesign of UI/UX.
- No new runtime dependencies.
- No changes to storage format or schema versioning.
- No new “smart” behavior or inference.

## Deliverables
- A repo-wide target architecture map (feature-first, per FOSA).
- A concrete file move map (old path -> new path).
- `Sources/App/ArchitectureDefaults.md` (repo defaults, minimal and stable).
- Incremental, low-risk refactors with parity tests.
- Updated docs reflecting the new structure.

---

## Phase 0 — Preflight and decisions

**Objective:** Lock down defaults and constraints before moving any files.

Checklist:
- Read FOSA `AGENTS.md` and `STYLE_GUIDE.md`.
- Read PersonaKit contract and 2.0 prompt pack.
- Decide default state-owner pattern (Observable Model or Store + Action).
- Create `Sources/App/ArchitectureDefaults.md` with:
  - State-owner pattern
  - Concurrency rules
  - IO boundary rules
  - Testing expectations
- Define explicit “no behavior change” criteria and test gates.

Exit criteria:
- Defaults file committed.
- Plan for structure and sequencing agreed.

---

## Phase 1 — Inventory and mapping

**Objective:** Create a clear, scoped map of what exists and where it should go.

Checklist:
- Inventory current App/Core/CLI surface areas.
- Identify current state owners and view entry points.
- Identify IO usage and current boundaries (file, schema, OS APIs).
- Identify shared UI components and domain types.
- Identify tests tied to state owners and outputs.
- Draft target structure for each target:
  - App UI features
  - Shared UI utilities/modifiers
  - Clients and IO boundaries
  - Core domain and composition logic
- Produce a file move map (per feature, per module).

Exit criteria:
- Approved move map with explicit sequencing.
- Risk list with mitigation for each move set.

---

## Phase 2 — Foundations (structure and safe moves)

**Objective:** Create the target skeleton and move safe, low-risk components.

Checklist:
- Add feature-first folders under App target.
- Add Shared folders for UI, Clients, Domain, Utilities.
- Move UI-only components into `Shared/UI` or feature `Components`.
- Move IO boundary code into `Shared/Clients` (no behavior changes).
- Ensure any shared domain types live in Core (not UI targets).

Exit criteria:
- Build passes with no logic changes.
- Tests still pass.

---

## Phase 3 — Feature-by-feature migration

**Objective:** Re-home each feature in small, reviewable steps.

For each feature:
1. Define entry view (`<Feature>View`) and state owner.
2. Ensure state owner is single-owner and `@MainActor` if UI-backed.
3. Move IO to Clients; update state owner to call clients.
4. Update imports and paths; keep API stable.
5. Add/adjust tests for state owner behavior.
6. Confirm no view performs IO.

Exit criteria (per feature):
- Compiles and tests pass.
- No behavior changes and no new dependencies.

---

## Phase 4 — App/CLI parity hardening

**Objective:** Ensure shared logic remains in Core and outputs match.

Checklist:
- Audit for duplicated logic between App and CLI.
- Move shared logic into `PersonaKitCore` where appropriate.
- Add parity tests for identical inputs.
- Confirm deterministic output and stable ordering.

Exit criteria:
- CLI and App parity tests green.
- No divergence in composition behavior.

---

## Phase 5 — Cleanup, docs, and release readiness

**Objective:** Remove legacy structure and confirm documentation accuracy.

Checklist:
- Remove empty/legacy folders.
- Update docs and internal references to new paths.
- Verify style guide and lint alignment.
- Capture final architecture summary in README or docs.

Exit criteria:
- Clean tree, docs updated, no regressions.

---

## Risk management

Primary risks and mitigations:
- **Scope creep:** enforce “no behavior changes” and per-feature move limits.
- **Hidden IO in views:** run targeted searches before/after each move.
- **Parity regressions:** add/extend parity tests early.
- **Concurrency issues:** ensure state owners are `@MainActor`.

---

## Sequencing rules (to prevent explosion)
- One feature per change set unless the feature is trivial.
- Move code before renaming symbols.
- Avoid refactoring logic while relocating files.
- Do not introduce new abstractions during moves.

---

## Open decisions (fill in before Phase 2)
- Default state-owner pattern:
- Target top-level feature list:
- Shared UI location:
- Client boundaries:
- Parity test approach:

---

## Tracking log

Record each phase’s status, owner, and date here.

```
Phase 0:
Phase 1:
Phase 2:
Phase 3:
Phase 4:
Phase 5:
```
