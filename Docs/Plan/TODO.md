# TODO

Last Updated: 2026-03-07

## Tomorrow Quick Start

1. Check working tree and branch sync:
   - `git status --short --branch`
   - `git log --oneline -n 8`
2. Push local `main` commits if still ahead of origin.
3. Run interactive Xcode smoke checks for `PersonaKit` and `PersonaKitCLI` schemes.
4. Decide whether completed plan docs in `Docs/Plan/` should be archived or deleted.

## Next Work Plan

### Milestone 1: Finish Xcode Host Integration Closeout

Objective: close remaining confidence gaps for the host workspace changes.

Tasks:

1. Confirm app launch behavior in interactive session (Studio root, no template UI fallback).
2. Confirm host test targets run cleanly in interactive Xcode context.
3. Record results in a short closeout note (or update the xcode integration plan with pass/fail and date).

Exit criteria:

1. Interactive app and tests are confirmed working.
2. No unresolved caveats remain in `Docs/Plan/xcode-host-package-integration-plan.md`.

### Milestone 2: Housekeeping for Temporary Plan Docs

Objective: keep `Docs/Plan` lightweight and current.

Tasks:

1. Remove or archive plan docs that are fully complete and no longer useful day-to-day.
2. Keep only one active plan plus `TODO.md` when possible.

Exit criteria:

1. `Docs/Plan` reflects only active, actionable work.

### Milestone 3: Test Architecture Follow-Up (existing carry-over)

Objective: evaluate reducing filesystem coupling in unit tests without losing path-behavior confidence.

Tasks:

1. Inventory tests using temp-directory/file-system side effects.
2. Identify candidates for in-memory or test-double file-system injection.
3. Propose a small pilot conversion (1-2 test files) and compare reliability/readability.

Exit criteria:

1. Decision captured: keep current approach, partial migration, or full migration strategy.
2. If migrating, create a focused plan doc for the implementation phase.

## Parking Lot

1. Keep an eye on headless `xcodebuild ... test` hang behavior; only prioritize if it blocks CI/local workflow.
