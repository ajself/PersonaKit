# PersonaKit FOSA Refactor Plan

## Purpose

This document is an implementation architecture plan for refactoring PersonaKit
into a cleaner, FOSA-aligned codebase. It is not a product-feature specification.

`Docs/Development/Studio-MVP.md` remains the product-development spec and is not
redefined here.

## Current Status

- PR0 — Architecture Contract and Codification: completed
- PR1 — Target Graph and Source Scaffold: completed
- PR2 — Shared/Core Migration: in progress

## Scope

In scope:

- Studio GUI architecture and source organization
- PersonaKit core architecture and source organization
- Target/module graph cleanup
- Test organization alignment
- Documentation and pack updates that encode architecture intent

Out of scope:

- New product features beyond opportunistic low-risk improvements discovered
  during refactor
- Changing the role of `Studio-MVP.md` from product spec to coding task spec

## Architecture Direction

### FOSA Alignment

Adopt a unified feature-oriented layout:

```text
Sources/
  App/
  Features/
  Shared/
Tests/
  Features/
  Shared/
```

### Ownership Model

- Use feature-owned models as the default owner type.
- Use a small app coordinator/composition owner where cross-feature orchestration
  is required.
- Keep mutable ownership single-source and explicit.

### IO Boundaries and DI

- No IO in SwiftUI views.
- IO goes through clients/managers injected into owner types.
- Keep owner methods explicit and testable.

## Target and Module Strategy

### Internal Strategy

Use role-based internal modules with medium granularity (focused, not overly
fragmented), for example:

- `ContextCore` for domain/resolution/validation/export graph concerns
- `ContextCLI` for CLI orchestration
- `ContextMCP` for MCP interfaces
- Studio-focused modules for app shell, models, and UI features

### Compatibility Wrappers

Use compatibility wrappers so user-facing identities remain stable:

- CLI command remains `personakit`
- GUI app product/display remains `PersonaKit`

Internal names and boundaries may change aggressively, but external usage stays
familiar.

## Milestone Sequence (PR0–PR8)

Each milestone has a stop point for review before continuing.

### PR0 — Architecture Contract and Codification

- Add `App/ArchitectureDefaults.md` with explicit repo defaults.
- Add an ADR describing the unified FOSA direction and constraints.
- Update repo-local packs/docs to encode architecture direction.
- Stop point: architecture review.

### PR1 — Target Graph and Source Scaffold

- Redesign `Package.swift` target graph for new architecture.
- Create new scaffold under `Sources/App`, `Sources/Features`,
  `Sources/Shared`.
- Keep build green with temporary forwarding as needed.
- Stop point: build/test smoke review.

### PR2 — Shared/Core Migration

- Move core domain/support/schema code into the new shared structure.
- Preserve behavior parity for validator/resolver/export/graph/session loading.
- Stop point: determinism and regression review.

### PR3 — CLI and MCP Migration

- Move CLI and MCP into feature-aligned modules.
- Wire compatibility wrappers to preserve external command behavior.
- Update scripts/docs affected by internal moves.
- Stop point: CLI/MCP workflow review.

### PR4 — Studio Source Migration

- Move Studio app code into unified source structure.
- Wire GUI compatibility wrapper so external app identity remains stable.
- Remove obsolete path dependencies after parity confirmation.
- Stop point: app launch/manual flow review.

### PR5 — Studio Owner Decomposition

- Decompose monolithic store responsibilities into feature-owned models plus a
  small app coordinator.
- Align view boundaries by feature.
- Stop point: ownership and boundary review.

### PR6 — Opportunistic Quality Improvements

- Apply safe cleanups discovered during migration.
- Keep changes deterministic and explicitly tested.
- Stop point: behavior-diff review.

### PR7 — Test Reorganization and Coverage Hardening

- Reorganize tests under `Tests/Features` and `Tests/Shared`.
- Align test imports and boundaries to new module graph.
- Add/retain regression coverage for critical flows.
- Stop point: test and coverage review.

### PR8 — Cleanup and Final Hardening

- Remove stale forwarding code and empty placeholder directories.
- Finalize docs and architecture references.
- Run final validation checklist and cutover review.
- Stop point: release readiness review.

## Git Strategy (Required)

Use **worktree + branch-per-PR**.

Rules:

1. Keep `main` clean.
2. Create integration branch: `codex/fosa-refactor`.
3. Create a dedicated worktree for that branch.
4. Create branch-per-milestone PR from the integration branch (for example
   `codex/fosa-pr0-architecture-contract`, `codex/fosa-pr1-target-scaffold`).
5. Merge milestone PRs into `codex/fosa-refactor`.
6. Merge `codex/fosa-refactor` into `main` when the sequence is stable.

## Validation and Acceptance

### Build and Test

- `swift build`
- `swift test`
- product-specific build checks for CLI and app wrappers

### CLI Workflows

- validate
- export (persona/directive and session)
- graph (persona/directive and session)
- mcp startup and resource/prompt/tool checks

### Studio Workflows

- open workspace
- initialize missing `.personakit` structure
- session create/edit/delete/validate/preview/export
- library minimal form and raw JSON editing
- essentials markdown editing
- diagnostics navigation and reveal-in-finder actions

### Determinism

- deterministic export and graph checks remain required
- no nondeterministic output introduced by refactor

## Risks and Mitigations

### Rename and Module Churn

Risk:

- Internal module moves and renames can cause widespread import breakages.

Mitigation:

- Milestoned PR sequence with stop points and continuous build/test checks.

### Boundary Breakages

Risk:

- Feature ownership splits can accidentally change behavior.

Mitigation:

- Structure-first moves before behavior-level adjustments.
- Regression tests for critical flows before and after migration.

### Docs Drift

Risk:

- Architecture docs and packs can diverge from implementation.

Mitigation:

- Update repo-local docs and packs in PR0.
- Require documentation checks in milestone reviews.

## Decision Log

Decisions captured from planning:

1. Refactor scope includes Studio GUI and core codebase architecture.
2. Delivery uses milestone PR sequence with review stop points.
3. Architecture direction is FOSA with unified `App/Features/Shared`.
4. Role-based internal module strategy is preferred.
5. External identities remain stable via compatibility wrappers:
   - CLI: `personakit`
   - GUI app: `PersonaKit`
6. Test reorganization is included in this refactor stream.
7. Empty placeholder directories are removed during cleanup.
8. Pack/docs updates are included so direction is codified.
9. Git strategy is fixed to worktree + branch-per-PR.

## Test Cases and Scenarios for This Docs-Only Step

1. Doc placement:
   - Verify `Docs/Development/FOSA-Refactor-Plan.md` exists.
2. No unintended edits:
   - Verify `Docs/Development/Studio-MVP.md` is unchanged.
3. Content completeness:
   - Verify this doc includes PR0–PR8 and the explicit git strategy section.
4. Link integrity:
   - If a future cross-reference is added in docs, verify the link resolves.

## Assumptions and Defaults

1. This step is docs-only.
2. `Studio-MVP.md` remains product-spec-only and untouched.
3. Canonical plan filename:
   - `Docs/Development/FOSA-Refactor-Plan.md`
4. Git strategy is fixed:
   - **Worktree + branch-per-PR**
