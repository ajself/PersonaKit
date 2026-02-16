# PersonaKit FOSA Refactor Plan

## Purpose

This document is an implementation architecture plan for refactoring PersonaKit
into a cleaner, FOSA-aligned codebase. It is not a product-feature specification.

`Docs/Development/Studio-MVP.md` remains the product-development spec and is not
redefined here.

## Current Status

- PR0 — Architecture Contract and Codification: completed
- PR1 — Target Graph and Source Scaffold: completed
- PR2 — Shared/Core Migration: completed
- PR3 — CLI and MCP Migration: completed
- PR4 — Studio Source Migration: completed
- PR5 — Studio Owner Decomposition: completed
- PR6 — Opportunistic Quality Improvements: completed
- PR7 — Test Reorganization and Coverage Hardening: in progress
- PR8 — Cleanup and Final Hardening: not started

## PR5 Progress Snapshot (2026-02-16)

Completed in the active refactor stream:

- Workspace ownership split into focused feature models:
  - `WorkspaceLoadFeatureModel`
  - `WorkspaceSystemFeatureModel`
  - `WorkspaceLibraryFeatureModel`
  - `WorkspaceSessionEditorFeatureModel`
  - `WorkspaceSessionFeatureModel`
  - `WorkspaceValidationFeatureModel`
- `WorkspaceStore` split into feature-oriented extensions:
  - `WorkspaceStore+WorkspaceFlow.swift`
  - `WorkspaceStore+SessionActions.swift`
  - `WorkspaceStore+LibraryActions.swift`
- Studio UI decomposition into focused panels and tab views:
  - root/panels split
  - sessions panel tab split
  - library panel split
  - diagnostics panel split
  - session editor split
  - raw JSON editor split
- Session preview responsibilities split into focused model extensions.
- Library feature action decomposition split into focused files:
  - copy library action
  - copy essential action
  - open library editor action
  - open essential editor action
  - save library editor action
  - save essential editor action
  - editor validation action

## PR5 Stop-Point Review Result (2026-02-16)

Review outcome: pass, with PR5 accepted as complete.

Validated:

- `WorkspaceStore` remains coordinator-oriented and delegates feature behavior to
  feature models.
- No direct IO calls were identified in `WorkspaceStore` or Studio feature-model
  files.
- Regression suite remains green:
  - `swift build` passed
  - `swift test` passed

Follow-up check carried into PR6:

- Complete Studio manual UI smoke checks listed in this plan and record outcome.

## PR6 Studio Workflow Smoke Check (2026-02-16)

Status:

- Automated workflow smoke coverage: passed.
- Manual UI smoke pass in the Studio app: pending.

Coverage mapping from the Studio workflow checklist:

- open workspace:
  - `WorkspaceStoreTests.openWorkspacePickerLoadsSelectedWorkspaceFromInjectedPicker`
  - `WorkspaceSystemFeatureModelTests.pickWorkspaceURLReturnsStandardizedSelection`
- initialize missing `.personakit` structure:
  - `WorkspaceStoreTests.initializeWorkspaceStructureCreatesFoldersAndReloadsWorkspace`
  - `WorkspaceSystemFeatureModelTests.initializeWorkspaceStructureCreatesExpectedDirectoryLayout`
- session create/edit/delete/validate/preview/export:
  - `WorkspaceStoreTests.saveSessionForwardsValidatedIDsToSessionManager`
  - `WorkspaceStoreTests.deleteSessionForwardsToSessionManager`
  - `WorkspaceStoreTests.validateWorkspaceAppendsSessionDiagnosticsIssues`
  - `WorkspaceStoreTests.refreshSessionPreviewLoadsPreviewForSelectedSession`
  - `WorkspaceStoreTests.exportSessionPreviewUsesInjectedDestinationPicker`
- library minimal form and raw JSON editing:
  - `WorkspaceLibraryEntityFormAdapterTests.applyFormStateUpdatesMappedFieldsAndPreservesOtherData`
  - `WorkspaceLibraryEntityManagerTests.saveRawJSONWritesToProjectScopeEntityPath`
  - `WorkspaceStoreTests.openLibraryEditorRejectsItemOutsideCurrentSnapshot`
  - `WorkspaceStoreTests.saveLibraryEditorRawJSONRejectsWorkspaceMismatch`
- essentials markdown editing:
  - `WorkspaceEssentialManagerTests.saveMarkdownWritesToProjectScopeEssentialPath`
  - `WorkspaceStoreTests.openEssentialEditorLoadsMarkdownForProjectItem`
  - `WorkspaceStoreTests.saveEssentialEditorMarkdownRejectsWorkspaceMismatch`
- diagnostics navigation and reveal-in-finder actions:
  - `WorkspaceStoreTests.validateWorkspaceAppendsSessionDiagnosticsIssues`
  - `WorkspaceSystemFeatureModelTests.revealValidationIssueInFinderUsesSnapshotPathResolution`
  - `WorkspaceSystemFeatureModelTests.revealInFinderForwardsStandardizedURLToRevealer`

Commands run for this smoke pass:

- `swift test --filter WorkspaceStoreTests`
- `swift test --filter WorkspaceSystemFeatureModelTests`
- `swift test --filter WorkspaceLibraryEntityFormAdapterTests`
- `swift test --filter WorkspaceLibraryEntityManagerTests`
- `swift test --filter WorkspaceEssentialManagerTests`
- `swift test --filter WorkspaceSessionManagerTests`
- `swift test --filter StudioLaunchConfigurationTests`

## PR6 Progress Snapshot (2026-02-16)

Completed deterministic cleanup slices on `codex/fosa-pr6-opportunistic-quality`:

- workspace URL identity and forwarding normalization:
  - `refactor(studio): normalize library request workspace URLs`
  - `refactor(studio): standardize workspace checks in load model`
  - `refactor(studio): standardize workspace URLs in store action flows`
  - `refactor(studio): standardize preview workspace identity`
  - `refactor(studio): standardize validation workspace identity`
  - `refactor(studio): standardize workspace forwarding in load and validation`
- stale-result and cancellation hardening:
  - `refactor(studio): clear active validation workspace on cancel`
  - `refactor(studio): clear active preview workspace on cancel`
  - `test(studio): cover stale global essential copy guard`
- store/system boundary consistency:
  - `refactor(studio): normalize store workspace URL assignment`
  - `refactor(studio): clear library action state on workspace switch`
  - `refactor(studio): standardize workspace init URL in system model`

Validation status:

- targeted Studio slices remain green after each incremental change
- latest full regression run: `swift test` passed (156 tests)

## Next Up (PR7 Active)

PR7 is now the active milestone.

1. Reorganize Studio and shared tests into `Tests/Features` and `Tests/Shared` in
   small deterministic slices.
2. Keep test import boundaries aligned with the current module graph while files
   move.
3. Retain existing regression coverage and add focused tests only where moves
   expose boundary risk.
4. Run `swift test` after each PR7 slice and record a final full-suite pass at
   the PR7 stop point.

## PR7 Progress Snapshot (2026-02-16)

Completed slice 1 on `codex/fosa-pr7-test-reorg`:

- test target root updated from `Tests/PersonaKitTests` to `Tests` with
  `Tests/Fixtures` excluded from source discovery
- support test cluster moved to shared layout:
  - `Tests/Shared/Support/GlobalPersonaKitLocatorTests.swift`
  - `Tests/Shared/Support/PersonaKitDirectoryTests.swift`
  - `Tests/Shared/Support/PersonaKitInitTests.swift`
  - `Tests/Shared/Support/ProjectPersonaKitLocatorTests.swift`
  - `Tests/Shared/Support/TestHelpers.swift`

Completed slice 2 on `codex/fosa-pr7-test-reorg`:

- CLI test cluster moved to feature layout:
  - `Tests/Features/CLI/CLIMCPCommandTests.swift`
  - `Tests/Features/CLI/CLIScopeFlagTests.swift`
  - `Tests/Features/CLI/CLIScopeResolutionTests.swift`
  - `Tests/Features/CLI/CLISessionTests.swift`
  - `Tests/Features/CLI/ListCommandTests.swift`

Completed slice 3 on `codex/fosa-pr7-test-reorg`:

- MCP test cluster moved to feature layout:
  - `Tests/Features/MCP/MCPPromptTests.swift`
  - `Tests/Features/MCP/MCPResourceMappingTests.swift`
  - `Tests/Features/MCP/MCPToolTests.swift`

Validation status:

- `swift test` passed (156 tests)

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
