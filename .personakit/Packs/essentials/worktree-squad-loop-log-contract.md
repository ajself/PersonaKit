# Worktree Squad Loop Log Contract

Use this runtime contract when recording active `worktree-squad-delivery` and `samwise-worktree-squad-oversight` loop outcomes.
For expanded examples, see `worktree-squad-loop-log-contract-reference`.

## Canonical Paths

1. Loop stream: `Docs/PersonaKit/Development/logs/worktree-squad-loops.jsonl`
2. Loop schema: `Docs/PersonaKit/Development/logs/worktree-squad-loops.schema.json`

## Required Fields

Each entry should include:

1. Stable entry id and date.
2. `sessionId`, objective, and worktree branch.
3. Authorization mode and gate id.
4. Status plus verification commands and verification status.
5. Review summary, residual risks, and next actions.

## Guardrails

1. Append only; do not overwrite prior entries.
2. Keep loop entries focused on gate evidence and next actions.
3. Retrospective closeout belongs in `worktree-squad-retrospective-log-contract`.
4. Treat projected workstream fields as derived visibility only.

## Validation

Run `Scripts/check-worktree-squad-logs.sh`.
