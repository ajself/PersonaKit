# Gardening Log Contract

Use this essential as the shared, deterministic logging contract for all
gardening workflows.

## Purpose

1. Provide reusable JSONL structures across gardening sessions.
2. Keep decisions and recommendation outcomes machine-processable.
3. Preserve human review accountability with stable evidence trails.

## Canonical Log Files

For every gardening workflow, maintain:

1. `Docs/Plan/logs/gardening-events.jsonl`
2. `Docs/Plan/logs/gardening-events.schema.json`
3. `Docs/Plan/logs/gardening-health-snapshots.jsonl`
4. `Docs/Plan/logs/gardening-health-snapshots.schema.json`
5. `Docs/Plan/logs/gardening-recommendation-feedback.jsonl`
6. `Docs/Plan/logs/gardening-recommendation-feedback.schema.json`
7. `Docs/Plan/logs/gardening-recommendations.jsonl`
8. `Docs/Plan/logs/gardening-recommendations.schema.json`
9. `Docs/Plan/logs/gardening-pack-coverage.jsonl`
10. `Docs/Plan/logs/gardening-pack-coverage.schema.json`
11. `Docs/Plan/logs/gardening-policy-conflicts.jsonl`
12. `Docs/Plan/logs/gardening-policy-conflicts.schema.json`
13. `Docs/Plan/logs/gardening-safety-preflight.jsonl`
14. `Docs/Plan/logs/gardening-safety-preflight.schema.json`

Session-specific logs may exist (for example git-history), but each accepted
decision should also be mirrored into `gardening-events.jsonl`.

## Required Base Fields

Each JSON line must include:

- `entryId` (stable incremental id, for example `GL-0001`)
- `date` (`YYYY-MM-DD`)
- `sessionId`
- `phaseLabel`
- `scope`
- `category`
- `subject`
- `proposedAction`
- `decision`
- `rationale`
- `affectedArtifacts` (string array)
- `validationStatus` (`pass`, `fail`, `not-run`)
- `reviewer`

## Determinism Rules

- Use date only, never time-of-day.
- Do not use UUIDs.
- Use stable prefix-based IDs (`GL-*` for shared stream; profile-specific prefixes are allowed in session-specific streams, for example `GREC-*`).
- Keep `entryId` monotonic.
- Keep field names stable.
- Keep entry ordering append-only.

## Guardrails

- Log decision before mutation.
- No destructive action without explicit approval.
- Record validation outcome after approved actions.
