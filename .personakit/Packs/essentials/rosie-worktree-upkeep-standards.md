# Rosie Worktree Upkeep Standards

Use this essential when running ongoing Rosie gardening work in a dedicated
lane worktree.

## Objectives

1. Keep Rosie gardening changes isolated in an approved non-`main` lane.
2. Preserve explicit traceability from lane commits to `main` integration.
3. Keep lane and `main` synchronized through a repeatable upkeep loop.
4. Keep human review gates explicit around history-altering actions.

## Operating Scope

- Dedicated Rosie lane worktree approved by AJ
- Lane branch: `rosies-garden`
- Integration target branch: `main` (in the main worktree)

## Required Upkeep Loop

1. Confirm active lane scope and AJ approval are recorded in partner logs.
2. Sync lane from latest `main` before starting new gardening changes.
3. Run approved gardening updates with bounded scope and required logs.
4. Run coverage, policy-conflict, and safety-preflight checks before integration.
5. Commit accepted updates on `rosies-garden`.
6. Rebase or replay lane commits onto `main` in the main worktree.
7. Sync updated `main` back onto `rosies-garden` for the next pass baseline.
8. Record validation status and residual risks after each integration cycle.

## Required Records

For each upkeep cycle, update:

1. `Docs/Plan/partner-context-log.md`
2. `Docs/Plan/partner-handoff-register.md`
3. `Docs/Plan/pack-gardener-log.md`
4. `Docs/Plan/logs/gardening-events.jsonl`
5. `Docs/Plan/logs/gardening-pack-coverage.jsonl`
6. `Docs/Plan/logs/gardening-policy-conflicts.jsonl`
7. `Docs/Plan/logs/gardening-safety-preflight.jsonl`

## Guardrails

- Keep commits bounded to approved gardening scope.
- Pause for AJ review before any history-altering integration on `main`.
- If sync conflicts occur, stop and produce a bounded conflict-resolution plan.
- Re-run validation after approved updates.
- Never delete a lane branch or worktree until ancestor verification confirms
  lane commits are contained in `main`.
