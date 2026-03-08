# Session Lifecycle States

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Define deterministic lifecycle states for `.personakit/Sessions/*.session.json`
entries so active workflows are easy to identify and stale workflows do not look
production-ready.

## State Set

Use exactly one state per session:

1. `active`
2. `candidate`
3. `deprecated`

## Definitions

### `active`

Use when a session is part of current, approved workflows and is expected to be
run in normal delivery loops.

### `candidate`

Use when a session is useful but not part of the default day-to-day loop (for
example specialized review, calibration, or exploratory flows).

### `deprecated`

Use when a session is kept for historical reference only and should not be used
for new work unless reactivated.

## Assignment Rules

1. Every listed session must have exactly one lifecycle state in
   `Docs/Development/session-directory.md`.
2. New sessions default to `candidate` until explicitly promoted.
3. Promotion to `active` requires explicit AJ approval.
4. Any session replaced by a newer path should move to `deprecated` instead of
   being silently removed.
5. Deprecated sessions may be deleted only after references are cleaned up and
   AJ approves removal.

## Review Cadence

1. Review lifecycle states during pack/session gardening passes.
2. Re-check lifecycle states at milestone closeout.
3. Update `Last Reviewed` when lifecycle assignments change.
