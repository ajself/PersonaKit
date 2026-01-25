# Strategy - Non-App Lint Cleanup (Core + CLI + Validate + Tests)

Date: 2026-01-25  
Status: not started

## Goal
Reduce SwiftLint "serious" violations outside the app target by:
- removing large tuples in Core
- lowering cyclomatic complexity and function length in CLI + SchemaValidate
- reducing test type body length in Core tests

Behavior must remain identical. No composition changes.

## Constraints (Non-Negotiable)
- Preserve deterministic output and app/CLI parity.
- Maintain UDF and main-actor isolation where relevant.
- No new product features or scope expansion.
- Keep changes small and reversible.

## Scope
In-scope:
- `Sources/PersonaPadCore/Metadata.swift` (large_tuple)
- `Sources/PersonaPadCLI/main.swift` (cyclomatic_complexity, function_body_length)
- `Sources/PersonaPadSchemaValidate/main.swift` (cyclomatic_complexity)
- `Tests/PersonaPadCoreTests/PersonaPadCoreTests.swift` (type_body_length)

Out-of-scope:
- App target lint cleanup (already complete).
- Schema or composition semantics changes.
- Formatting/lint rules changes.

## Strategy Overview
1) **Eliminate large tuples in Core** by introducing small structs.
2) **Decompose CLI entrypoint logic** into focused handlers to reduce complexity.
3) **Split schema validator flow** into smaller helpers without behavior changes.
4) **Split large test class** into smaller test types or files while keeping coverage.
5) **Re-run format + lint + tests + release check** after each phase.

## Detailed Steps

### 1) Core large_tuple cleanup
Target:
- `Sources/PersonaPadCore/Metadata.swift`

Approach:
- Replace 3+ member tuples with small structs conforming to `Equatable`/`Comparable` if needed.
- Keep ordering and semantics identical.

Completion gate:
- Ask to start Phase 1 before editing.
- Commit Phase 1 changes before starting Phase 2.

### 2) CLI main.swift complexity
Target:
- `Sources/PersonaPadCLI/main.swift`

Approach:
- Keep public CLI behavior and output identical.
- Break `main`/top-level command routing into helpers.
- Keep dependencies and IO behavior unchanged.

Completion gate:
- Ask to start Phase 2 before editing.
- Commit Phase 2 changes before starting Phase 3.

### 3) SchemaValidate complexity
Target:
- `Sources/PersonaPadSchemaValidate/main.swift`

Approach:
- Extract logical branches into small helpers.
- Preserve error messages, exit codes, and output ordering.

Completion gate:
- Ask to start Phase 3 before editing.
- Commit Phase 3 changes before starting Phase 4.

### 4) Core tests type length
Target:
- `Tests/PersonaPadCoreTests/PersonaPadCoreTests.swift`

Approach:
- Split into multiple test types/files (e.g., `PersonaPadCoreComposeTests`, `PersonaPadCoreImportTests`).
- Avoid changing test behavior or coverage.

Completion gate:
- Ask to start Phase 4 before editing.
- Commit Phase 4 changes before starting Phase 5.

### 5) Validation
Run:
- `swift-format format --configuration swift-format.json --in-place --recursive Sources Tests`
- `swiftlint --config swiftlint.yml`
- `swift test`
- `./Scripts/release-check.sh`

Completion gate:
- Ask to start Phase 5 before running commands.
- Commit Phase 5 changes before finishing.

## Session State (2026-01-25)
Completed:
- None.

Outstanding:
- Phase 1: Core `large_tuple` fix.
- Phase 2: CLI complexity reduction.
- Phase 3: SchemaValidate complexity reduction.
- Phase 4: Core tests type length split.
- Phase 5: Validation run.

## Acceptance Criteria
- No SwiftLint "serious" violations in Core/CLI/SchemaValidate/Tests.
- Tests and release check pass with identical behavior.

## Notes for New Agents
- Do not change CLI flags, exit codes, or output ordering.
- Keep error messages identical (including punctuation).
- Avoid introducing new public APIs or behavior.
