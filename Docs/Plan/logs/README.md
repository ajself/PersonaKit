# Gardening Logs

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Centralized machine-readable logs for gardening workflows.

## Files

- `gardening-events.jsonl`: shared event stream for all gardening sessions.
- `gardening-events.schema.json`: base schema for shared event entries.
- `git-history-gardener.jsonl`: session-specific git-history log profile.
- `git-history-gardener.schema.json`: session-specific schema extension profile.
- `persona-hiring-reviews.jsonl`: reverse-interview outcome stream for persona hiring assessments.
- `persona-hiring-reviews.schema.json`: schema for persona hiring review entries.
- `samwise-diary.jsonl`: Samwise end-of-day reflection diary.
- `samwise-diary.schema.json`: schema for Samwise diary entries.
- `../git-history-gardener-proposals.md`: approval-gated proposed history changes.

## Contract Rule

When a gardening session writes to a session-specific JSONL file, it should also
mirror accepted decisions into `gardening-events.jsonl`.

## Validation

Run:

- `Scripts/check-gardening-logs.sh`

Expected output:

- `GARDENING_LOGS_CHECK:PASS`
