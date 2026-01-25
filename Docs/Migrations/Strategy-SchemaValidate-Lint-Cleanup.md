# Strategy - SchemaValidate Lint Cleanup (Validate + Core Tests + Validation)

Date: 2026-01-25  
Status: in progress

## Goal
Reduce SwiftLint "serious" violations in SchemaValidate and remaining non-app targets by:
- lowering cyclomatic complexity in SchemaValidate
- reducing test type body length in Core tests

Behavior must remain identical. No composition changes.

## Constraints (Non-Negotiable)
- Preserve deterministic output and app/CLI parity.
- Maintain UDF and main-actor isolation where relevant.
- No new product features or scope expansion.
- Keep changes small and reversible.

## Scope
In-scope:
- `Sources/PersonaPadSchemaValidate/main.swift` (cyclomatic_complexity)
- `Tests/PersonaPadCoreTests/PersonaPadCoreTests.swift` (type_body_length)
- Validation commands (format/lint/tests/release)

Out-of-scope:
- App target lint cleanup.
- Schema or composition semantics changes.
- Formatting/lint rules changes.

## Strategy Overview
1) **Split SchemaValidate flow** into small helpers without behavior changes.
2) **Split Core tests type** into smaller test types/files while keeping coverage.
3) **Re-run format + lint + tests + release check** after the refactors.

## Detailed Steps

### 1) SchemaValidate complexity
Target:
- `Sources/PersonaPadSchemaValidate/main.swift`

Approach:
- Extract logical branches into small helpers.
- Preserve error messages, exit codes, and output ordering.

Completion gate:
- Ask to start Phase 1 before editing.
- Commit Phase 1 changes before starting Phase 2.

### 2) Core tests type length
Target:
- `Tests/PersonaPadCoreTests/PersonaPadCoreTests.swift`

Approach:
- Split into multiple test types/files (e.g., `PersonaPadCoreComposeTests`, `PersonaPadCoreImportTests`).
- Avoid changing test behavior or coverage.

Completion gate:
- Ask to start Phase 2 before editing.
- Commit Phase 2 changes before starting Phase 3.

### 3) Validation
Run:
- `swift-format format --configuration swift-format.json --in-place --recursive Sources Tests`
- `swiftlint --config swiftlint.yml`
- `swift test`
- `./Scripts/release-check.sh`

Completion gate:
- Ask to start Phase 3 before running commands.
- Commit Phase 3 changes before finishing.

## Session State (2026-01-25)
Completed:
- Core `large_tuple` fix (`Sources/PersonaPadCore/Metadata.swift`)
- CLI complexity reduction (`Sources/PersonaPadCLI/main.swift`)

Outstanding:
- Phase 1: SchemaValidate complexity reduction.
- Phase 2: Core tests type length split.
- Phase 3: Validation run.

## Acceptance Criteria
- No SwiftLint "serious" violations in SchemaValidate/Tests.
- Tests and release check pass with identical behavior.

## Notes for New Agents
- Do not change CLI flags, exit codes, or output ordering.
- Keep error messages identical (including punctuation).
- Avoid introducing new public APIs or behavior.
