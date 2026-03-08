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
- `worktree-squad-loops.jsonl`: squad-loop execution stream for delivery/oversight passes.
- `worktree-squad-loops.schema.json`: schema for squad-loop entries.
- `worktree-squad-retrospectives.jsonl`: retrospective/recommendation stream for squad iterations.
- `worktree-squad-retrospectives.schema.json`: schema for squad retrospective entries.
- `../git-history-gardener-proposals.md`: approval-gated proposed history changes.

## Contract Rule

When a gardening session writes to a session-specific JSONL file, it should also
mirror accepted decisions into `gardening-events.jsonl`.
Health snapshots and recommendation feedback should be updated for each
maintenance pass.
Recommendation ranking updates should also be appended to
`gardening-recommendations.jsonl`.
Coverage, policy-conflict, and safety-preflight updates should also be appended
for each non-trivial gardening pass.

## Validation

Run:

- `Scripts/check-gardening-logs.sh`
- `Scripts/check-persona-hiring-logs.sh`
- `Scripts/check-worktree-squad-logs.sh`

Expected output:

- `GARDENING_LOGS_CHECK:PASS`
- `PERSONA_HIRING_LOGS_CHECK:PASS`
- `WORKTREE_SQUAD_LOGS_CHECK:PASS`
