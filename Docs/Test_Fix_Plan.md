# Test Fix Plan

Goal: fix test failures in small, reviewable phases while keeping PersonaKit deterministic and boring.

## Scope
- Tests across core, app, and CLI targets.

## Non-goals
- New product features.
- Changes to prompt composition semantics.
- Networked test infrastructure or cloud services.

## Phases

### Phase 0 — Baseline + Triage
- Run `swift test` on the current HEAD and record results.
- Capture failing targets and log locations.
- Produce a short list of failures with file paths and error messages.

Success criteria:
- A single, minimal failure list with reproducible commands and log paths.

### Phase 1 — Fix Compile-Blocking Errors
- Address compile-time failures that prevent tests from running.
- Keep each fix to a single file or target where possible.
- Add or update tests only when required to validate the fix.

Success criteria:
- All test targets compile on HEAD.

### Phase 2 — Fix Deterministic Test Failures
- Group failing tests by subsystem (Core, AppStore/App, CLI).
- Fix one subsystem per commit, focusing on deterministic behavior regressions.
- Avoid changing public behavior unless the test is incorrect.

Success criteria:
- All deterministic test failures resolved on HEAD.

### Phase 3 — Historical Commit Strategy
- For known-broken historical SHAs, decide one of:
  - backport a minimal fix (if warranted), or
  - document and allow failures for that SHA range, or
  - skip tests for that SHA range and document why.
- Keep the strategy explicit and file-based.

Success criteria:
- Historical SHA strategy is documented and unambiguous.

### Phase 4 — Cleanup + Guardrails
- Add a small regression test to prevent the same failure class.
- Update any test fixtures or documentation touched by the fixes.
- Re-run full tests to confirm green.

Success criteria:
- `swift test` passes on HEAD.
