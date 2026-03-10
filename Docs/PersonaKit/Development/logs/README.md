# Development Logs

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-08

## Purpose

Centralized machine-readable logs for development operating loops, including
gardening, hiring, partner continuity, and worktree-squad delivery.

## Files

- `gardening-events.jsonl`: shared event stream for all gardening sessions.
- `gardening-events.schema.json`: base schema for shared event entries.
- `gardening-health-snapshots.jsonl`: deterministic health snapshot stream.
- `gardening-health-snapshots.schema.json`: schema for health snapshots.
- `gardening-recommendations.jsonl`: ranked `GREC-*` recommendation stream.
- `gardening-recommendations.schema.json`: schema for recommendation scoring output.
- `gardening-recommendation-feedback.jsonl`: recommendation decision/outcome stream.
- `gardening-recommendation-feedback.schema.json`: schema for recommendation feedback entries.
- `gardening-pack-coverage.jsonl`: pack graph coverage snapshot stream.
- `gardening-pack-coverage.schema.json`: schema for coverage snapshots.
- `gardening-policy-conflicts.jsonl`: policy conflict detector stream.
- `gardening-policy-conflicts.schema.json`: schema for policy conflict findings.
- `gardening-safety-preflight.jsonl`: self-gardening safety preflight stream.
- `gardening-safety-preflight.schema.json`: schema for safety preflight entries.
- `git-history-gardener.jsonl`: session-specific git-history log profile.
- `git-history-gardener.schema.json`: session-specific schema extension profile.
- `persona-hiring-reviews.jsonl`: reverse-interview outcome stream for persona hiring assessments.
- `persona-hiring-reviews.schema.json`: schema for persona hiring review entries.
- `samwise-diary.jsonl`: Samwise end-of-day reflection diary.
- `samwise-diary.schema.json`: schema for Samwise diary entries.
- `squad-planning-reviews.jsonl`: durable planning-review stream for Samwise squad formation and handoff passes.
- `squad-planning-reviews.schema.json`: schema for squad planning review entries.
- `session-stack-reviews.jsonl`: durable Samwise session-review stream for PersonaKit session audits.
- `session-stack-reviews.schema.json`: schema for session-review entries.
- `worktree-squad-loops.jsonl`: squad-loop execution stream for delivery/oversight passes.
- `worktree-squad-loops.schema.json`: schema for squad-loop entries.
- `worktree-squad-retrospectives.jsonl`: retrospective/recommendation stream for squad iterations.
- `worktree-squad-retrospectives.schema.json`: schema for squad retrospective entries, supporting legacy and Starfish-shaped records.
- `../git-history-gardener-proposals.md`: approval-gated proposed history changes.

## Contract Rule

### Gardening Logs

When a gardening session writes to a session-specific JSONL file, it should also
mirror accepted decisions into `gardening-events.jsonl`.
Health snapshots and recommendation feedback should be updated for each
maintenance pass.
Recommendation ranking updates should also be appended to
`gardening-recommendations.jsonl`.
Coverage, policy-conflict, and safety-preflight updates should also be appended
for each non-trivial gardening pass.

### Persona Hiring Logs

Each reverse-interview pass should produce:

1. One human-readable report in `Docs/PersonaKit/Development/hiring-reviews/`
2. One schema-valid entry in `persona-hiring-reviews.jsonl`

### Samwise Continuity Logs

Each closeout checkpoint should append one schema-valid entry to
`samwise-diary.jsonl` with continuity-ready learning and next-goal fields.

### Squad Planning Logs

Each `samwise-squad-planning` pass should produce:

1. One human-readable report in `Docs/PersonaKit/Development/planning-reviews/`
2. One schema-valid entry in `squad-planning-reviews.jsonl`
3. A named next session that routes missing-role follow-up through hiring or
   remediation before execution when role coverage is incomplete

### Session Stack Review Logs

Each `samwise-session-stack-review` pass should produce:

1. One human-readable report in `Docs/PersonaKit/Development/session-reviews/`
2. One schema-valid entry in `session-stack-reviews.jsonl`
3. An explicit MCP status plus safe/caution/unsafe/blocked verdict

### Worktree Squad Logs

Each delivery loop and retrospective should append schema-valid entries to the
corresponding `worktree-squad-*.jsonl` stream, including gate evidence and
report-path references when applicable.

New retrospective entries should use the Starfish shape by default.
New retrospective entries should also record:

1. `retrospectiveMethod`
2. `declaredRoles`
3. `actualParticipants`
4. `participantEvidencePaths`
5. `subagentCount`
6. `featureConfidence`
7. `productConfidence`
8. `processConfidence`

This keeps the log honest about who actually participated and what kind of
confidence was earned.

Legacy retrospective entries remain valid for historical continuity.

## Validation

Run:

- `Scripts/check-gardening-logs.sh`
- `Scripts/check-persona-hiring-logs.sh`
- `Scripts/check-squad-planning-logs.sh`
- `Scripts/check-session-stack-review-logs.sh`
- `Scripts/check-worktree-squad-logs.sh`

Expected output:

- `GARDENING_LOGS_CHECK:PASS`
- `PERSONA_HIRING_LOGS_CHECK:PASS`
- `SQUAD_PLANNING_LOGS_CHECK:PASS`
- `SESSION_STACK_REVIEW_LOGS_CHECK:PASS`
- `WORKTREE_SQUAD_LOGS_CHECK:PASS`
