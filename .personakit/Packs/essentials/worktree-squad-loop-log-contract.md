# Worktree Squad Loop Log Contract

Use this essential when recording active `worktree-squad-delivery` and
`samwise-worktree-squad-oversight` loop outcomes.

## Canonical Paths

1. Loop stream:
   - `Docs/PersonaKit/Development/logs/worktree-squad-loops.jsonl`
2. Loop schema:
   - `Docs/PersonaKit/Development/logs/worktree-squad-loops.schema.json`
3. Related closeout contract:
   - `worktree-squad-retrospective-log-contract`

## Required Loop Fields

Each loop entry should include:

1. `entryId` (`WSQ-0001` style)
2. `date` (`YYYY-MM-DD`)
3. `sessionId` (`worktree-squad-delivery` or `samwise-worktree-squad-oversight`)
4. `objective`
5. `worktreeBranch`
6. `authorizationMode`
7. `gateId`
8. `status` (`in-progress`, `completed`, `blocked`)
9. `verificationCommands` (array)
10. `verificationStatus` (`pass`, `partial`, `fail`, `blocked`)
11. `reviewSummary`
12. `residualRisks` (array)
13. `nextActions` (array)

## Guardrails

1. Keep IDs deterministic and monotonic.
2. Do not overwrite prior entries; append only.
3. Keep execution-time entries focused on gate evidence, verification outcomes,
   and next actions; retrospective closeout belongs in
   `worktree-squad-retrospective-log-contract`.

## Validation

Run:

- `Scripts/check-worktree-squad-logs.sh`
