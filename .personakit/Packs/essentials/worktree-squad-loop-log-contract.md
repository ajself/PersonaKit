# Worktree Squad Loop Log Contract

Use this essential when recording `worktree-squad-delivery` and
`samwise-worktree-squad-oversight` loop outcomes.

## Canonical Paths

1. Loop stream:
   - `Docs/PersonaKit/Development/logs/worktree-squad-loops.jsonl`
2. Loop schema:
   - `Docs/PersonaKit/Development/logs/worktree-squad-loops.schema.json`
3. Human retrospectives:
   - `Docs/PersonaKit/Development/retrospectives/worktree-squad/`
4. Retrospective stream:
   - `Docs/PersonaKit/Development/logs/worktree-squad-retrospectives.jsonl`
5. Retrospective schema:
   - `Docs/PersonaKit/Development/logs/worktree-squad-retrospectives.schema.json`

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

## Required Retrospective Fields

Each retrospective/recommendation entry should include:

1. `entryId` (`WSR-0001` style)
2. `date` (`YYYY-MM-DD`)
3. `sessionId`
4. `entryType` (`retrospective` or `recommendation`)
5. `objective`
6. One of these retrospective shapes:
   - `Starfish`
     - `keepDoing` (array)
     - `lessOf` (array)
     - `moreOf` (array)
     - `stopDoing` (array)
     - `startDoing` (array)
   - `Legacy`
     - `whatWentWell` (array)
     - `whatDidNot` (array)
     - `openQuestions` (array)
     - `improvements` (array)
7. `actionItems` (array)
8. `reportPath`
9. `reviewer`

## Guardrails

1. Keep IDs deterministic and monotonic.
2. Do not overwrite prior entries; append only.
3. If `entryType` is `recommendation`, include explicit owner names in
   `actionItems`.
4. New retrospective entries should use the `Starfish` shape by default.
5. Legacy entries remain valid for historical continuity and should not be
   rewritten just to satisfy the newer format.
6. Retrospective reports should map directly to JSONL fields.

## Validation

Run:

- `Scripts/check-worktree-squad-logs.sh`
