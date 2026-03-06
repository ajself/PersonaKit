# Plan 0: PersonaKit Pack Expansion for Multi-Agent Studio Execution

Date: 2026-03-06

## Summary

This plan defines and creates the PersonaKit files required to safely run the Studio multi-agent execution plan.

## Implementation Status

Status: Implemented on 2026-03-06 in this worktree.

Implemented artifacts:

1. Personas:
   - `studio-reliability-engineer`
   - `studio-boundary-guardian`
   - `studio-coverage-architect`
   - `studio-workflow-operator`
   - `studio-integration-coordinator`
2. Directives:
   - `stabilize-preview-cancellation`
   - `harden-session-boundaries`
   - `expand-core-coverage`
   - `harden-validation-workflow`
   - `integrate-lanes-with-stop-points`
3. Sessions:
   - `studio-reliability`
   - `studio-boundary`
   - `studio-coverage`
   - `studio-workflow`
   - `studio-integration`

Implementation commits:

1. `2f1e0c7` — Added the five Studio personas.
2. `88c702f` — Added the five Studio directives and five Studio sessions.

Verification results:

1. `swift run personakit validate` passed (`errors=0`).
2. `swift run personakit list personas` includes all new persona IDs.
3. `swift run personakit list directives` includes all new directive IDs.
4. `swift run personakit export --session studio-reliability` is deterministic across repeated runs.
5. `swift run personakit graph --session studio-reliability` is deterministic across repeated runs.
6. `Scripts/validate-repo.sh` remains blocked by the known flaky test in `Tests/Features/Studio/WorkspaceSessionFeatureModelMapTests.swift` (`refreshPreviewRestartsAfterCancellationForSameSession`), which is outside pack-schema validity.

Execution order:

1. Complete this plan first.
2. Then execute `Docs/Plan/studio-multi-agent-acceleration-plan.md`.

Primary outcome:

- A valid, deterministic PersonaKit pack with lane-specific personas, directives, and sessions that prevent role drift during multi-agent execution.

## Mandatory Working Model

All work in this plan MUST be performed in a dedicated git worktree.

1. Use branch naming: `codex/pack-expansion-2026-03-06`
2. Use worktree path under `~/.codex/worktrees/...`
3. Run all validation from the same worktree path

## Scope and Deliverables

### Deliverables

Create the following files under project `.personakit`:

1. Personas (`.personakit/Packs/personas/`)
   - `studio-reliability-engineer.persona.json`
   - `studio-boundary-guardian.persona.json`
   - `studio-coverage-architect.persona.json`
   - `studio-workflow-operator.persona.json`
   - `studio-integration-coordinator.persona.json`
2. Directives (`.personakit/Packs/directives/`)
   - `stabilize-preview-cancellation.directive.json`
   - `harden-session-boundaries.directive.json`
   - `expand-core-coverage.directive.json`
   - `harden-validation-workflow.directive.json`
   - `integrate-lanes-with-stop-points.directive.json`
3. Sessions (`.personakit/Sessions/`)
   - `studio-reliability.session.json`
   - `studio-boundary.session.json`
   - `studio-coverage.session.json`
   - `studio-workflow.session.json`
   - `studio-integration.session.json`
4. Optional plan alignment update
   - Add a short note to `Docs/Plan/studio-multi-agent-acceleration-plan.md` that execution depends on completion of this pack-expansion plan.

### Non-goals

1. No changes to existing essentials, skills, or intent templates unless validation requires a minimal fix.
2. No product/architecture redesign.
3. No runtime behavior changes in app code.

## Decision-Complete Content Specification

### Common schema rules

All new files MUST follow existing project conventions and schema expectations:

1. `id` is lowercase kebab-case and matches filename stem.
2. `version` is `"1.0"`.
3. Persona files include:
   - `id`, `version`, `name`, `summary`
   - `responsibilities`, `values`, `nonGoals`
   - `defaultKitIds`, `allowedSkillIds`, `forbiddenSkillIds`
4. Directive files include:
   - `id`, `version`, `title`, `goal`
   - `steps` (with explicit review stop where safety matters)
   - `acceptanceCriteria`, `verification`
   - `requiresIntentTemplateIds` set to `"swift-refactor-safe"`
   - `requiresSkillIds` set to `"codex-cli"`
5. Session files include:
   - `id`, `personaId`, `directiveId`
   - optional `kitOverrides` only when strictly needed

### Persona definitions

All new personas MUST use:

1. `allowedSkillIds`: `["codex-cli"]`
2. `forbiddenSkillIds`: `["autonomous-agent-loop"]`
3. `defaultKitIds`: `["swift-style", "swiftui-style", "repo-constraints"]`

Lane-specific intent:

1. `studio-reliability-engineer`
   - Focus: cancellation consistency, race prevention, deterministic async tests
2. `studio-boundary-guardian`
   - Focus: view/store boundaries, no feature-model leakage into views
3. `studio-coverage-architect`
   - Focus: deterministic tests for relationship-map and scope/path edge cases
4. `studio-workflow-operator`
   - Focus: Makefile/validation-doc workflow safety for multi-agent operation
5. `studio-integration-coordinator`
   - Focus: merge sequencing, invariant verification, stop-point enforcement

### Directive mapping

1. `stabilize-preview-cancellation` -> reliability lane
2. `harden-session-boundaries` -> boundary lane
3. `expand-core-coverage` -> coverage lane
4. `harden-validation-workflow` -> workflow lane
5. `integrate-lanes-with-stop-points` -> coordinator integration lane

Directive requirements:

1. Include at least one `steps` entry with `requiresReview: true` for explicit human stop.
2. Include verification commands that are already supported in this repo:
   - `swift test`
   - `Scripts/validate-repo.sh`
3. Include acceptance criteria that forbid scope expansion and unrelated refactors.

### Session mapping

Create one session per lane:

1. `studio-reliability`:
   - `personaId`: `studio-reliability-engineer`
   - `directiveId`: `stabilize-preview-cancellation`
2. `studio-boundary`:
   - `personaId`: `studio-boundary-guardian`
   - `directiveId`: `harden-session-boundaries`
3. `studio-coverage`:
   - `personaId`: `studio-coverage-architect`
   - `directiveId`: `expand-core-coverage`
4. `studio-workflow`:
   - `personaId`: `studio-workflow-operator`
   - `directiveId`: `harden-validation-workflow`
5. `studio-integration`:
   - `personaId`: `studio-integration-coordinator`
   - `directiveId`: `integrate-lanes-with-stop-points`

## Execution Steps

1. Create `.personakit/Sessions/` if missing.
2. Author 5 new persona files.
3. Author 5 new directive files.
4. Author 5 new session files.
5. Run validation and determinism checks.
6. Stop for human review before any Studio lane execution starts.

## Validation and Acceptance Gates

Required checks:

1. `swift run personakit validate`
2. `swift run personakit list personas`
3. `swift run personakit list directives`
4. `swift run personakit export --session studio-reliability`
5. `swift run personakit graph --session studio-reliability`
6. `Scripts/validate-repo.sh`

Determinism checks:

1. Repeat `export` and `graph` for at least one new session and verify stable output.
2. Ensure no timestamps/UUIDs/environment-specific fields are introduced in pack JSON.

Acceptance criteria:

1. All newly created files validate with no schema errors.
2. All session IDs resolve and export successfully.
3. Lane mapping is complete (5 personas + 5 directives + 5 sessions).
4. Human review sign-off recorded before starting Studio implementation lanes.

## Rollback and Stop Conditions

Stop immediately and request review if any occur:

1. `personakit validate` fails and the fix would require changing unrelated packs.
2. Existing sessions/personas become invalid due to new references.
3. Directive semantics conflict with repository constraints or non-goals.

Rollback behavior:

1. Revert only newly added pack/session files from this plan.
2. Keep existing baseline pack files unchanged.

## Assumptions

1. Existing kits (`swift-style`, `swiftui-style`, `repo-constraints`) remain authoritative for new personas.
2. Existing intent template (`swift-refactor-safe`) is reused by all new directives.
3. No additional skills are required for this first expansion.
