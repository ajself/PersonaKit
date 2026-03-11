# Session Lifecycle States

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-11

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
run as a supported workflow in current repo operations.

`active` may include validated specialist lanes when they are the approved path
for a specific trigger or remediation condition; it does not mean the session
must be part of every day-to-day loop.

### `candidate`

Use when a session is useful but still provisional, exploratory, or not yet
explicitly promoted for operator-facing use.

Do not use `candidate` merely because a lane is specialized. If a specialized
lane is validated and is the intended approved workflow when its trigger
conditions apply, promote it to `active`.

### `deprecated`

Use when a session is kept for historical reference only and should not be used
for new work unless reactivated.

## Assignment Rules

1. Every listed session must have exactly one lifecycle state in
   `Docs/PersonaKit/Development/session-directory.md`.
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
