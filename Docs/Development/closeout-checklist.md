# Closeout Checklist

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Provide one recurring closeout checklist so pack/session maintenance is never
skipped at milestone or phase transitions.

## Trigger

Run this checklist:

1. At milestone closeout.
2. At phase closeout.
3. Before `make closeout-local` when landing lane work.

## Required Steps

1. Confirm scope and target:
   - closeout label (`milestone`, `phase`, or `lane`)
   - branch/worktree scope
2. Run a pack/session maintenance pass with `pack-gardener-maintenance`.
3. Execute `gardening-v2-checklist` during that maintenance pass.
4. Update closeout records:
   - `Docs/Plan/pack-gardener-log.md`
   - `Docs/Plan/pack-session-improvement-backlog.md`
   - `Docs/Plan/TODO.md`
5. Append one event to `Docs/Plan/logs/gardening-events.jsonl`.
6. Run verification:
   - `swift run personakit validate --root .personakit`
   - `Scripts/check-gardening-logs.sh`
7. If it is end-of-day, run `samwise-daily-closeout` and append one diary
   entry in `Docs/Plan/logs/samwise-diary.jsonl`.

## Completion Criteria

1. Maintenance, backlog, and TODO reflect current open work only.
2. Validation and log checks pass.
3. Closeout evidence is recorded in markdown + JSONL logs.
