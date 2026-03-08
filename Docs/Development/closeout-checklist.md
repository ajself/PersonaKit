# Closeout Checklist

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-08

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
   - `Docs/Development/pack-gardener-log.md`
   - `Docs/Development/partner-context-log.md` when partner behavior or guardrails change
   - `Docs/Plan/TODO.md`
5. Append one event to `Docs/Development/logs/gardening-events.jsonl`.
6. Run verification:
   - `swift run personakit validate --root .personakit`
   - `Scripts/check-gardening-logs.sh`
7. If this closeout is a pause/reflection checkpoint, run
   `samwise-daily-closeout` and append one diary entry in
   `Docs/Development/logs/samwise-diary.jsonl`.

## Completion Criteria

1. Maintenance records and TODO reflect current open work only.
2. Durable operations docs remain in `Docs/Development/`.
3. Validation and log checks pass.
4. Closeout evidence is recorded in markdown + JSONL logs.
