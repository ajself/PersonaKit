# Worktree Squad Retrospective Log Contract

Use this runtime contract when recording closeout retrospectives and recommendation entries for worktree-squad iterations.
For expanded schema examples, see `worktree-squad-retrospective-log-contract-reference`.

## Canonical Paths

1. Human retrospectives: `Docs/PersonaKit/Development/retrospectives/worktree-squad/`
2. JSONL stream: `Docs/PersonaKit/Development/logs/worktree-squad-retrospectives.jsonl`
3. Schema: `Docs/PersonaKit/Development/logs/worktree-squad-retrospectives.schema.json`

## Required Fields

Each entry should include:

1. Stable entry id and date.
2. `sessionId`, `entryType`, and objective.
3. Starfish or legacy retrospective buckets.
4. Action items, report path, and reviewer.

New `worktree-squad-retrospective` entries should also include:

1. `retrospectiveMethod`
2. `declaredRoles`
3. `actualParticipants`
4. `participantEvidencePaths`
5. `subagentCount`
6. `featureConfidence`, `productConfidence`, and `processConfidence`

## Guardrails

1. Append only; do not overwrite prior entries.
2. Planned roles do not count as actual participants.
3. If the method claims `fan-out` or `hybrid`, participant evidence must show more than one active participant.
4. Treat workstream routing as derived visibility, not source-of-truth routing.

## Validation

Run `Scripts/check-worktree-squad-logs.sh`.
