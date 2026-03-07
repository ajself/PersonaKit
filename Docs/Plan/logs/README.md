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

## Contract Rule

When a gardening session writes to a session-specific JSONL file, it should also
mirror accepted decisions into `gardening-events.jsonl`.

## Validation

Run:

- `Scripts/check-gardening-logs.sh`

Expected output:

- `GARDENING_LOGS_CHECK:PASS`
