# Git History Gardening Standards

Use this essential when reviewing and pruning commit history quality.

## Objectives

1. Keep commit history coherent, reviewable, and intention-revealing.
2. Preserve traceability from decision to action.
3. Prevent destructive history edits without explicit human approval.
4. Build a deterministic evidence trail for future process refinement.

## Required Logs

For each git-history gardening pass, maintain both:

1. `Docs/Plan/git-history-gardener-log.md`
2. `Docs/Plan/logs/git-history-gardener.jsonl`
3. `Docs/Plan/logs/gardening-events.jsonl` (shared gardening stream)

The git-history JSONL entry extends the shared `gardening-log-contract`.

## JSONL Contract (Required Fields)

Each session-specific JSON line must include shared base fields:

- `entryId` (stable incremental id, for example `GHG-0001`)
- `date` (`YYYY-MM-DD`)
- `sessionId` (for example `git-history-gardener`)
- `phaseLabel`
- `scope`
- `category` (`git-history`)
- `subject`
- `proposedAction`
- `decision`
- `rationale`
- `affectedArtifacts` (string array)
- `validationStatus` (`pass`, `fail`, `not-run`)
- `reviewer`

and git-history profile fields:

- `commitRange`
- `candidateCommit`

## Determinism Rules

- Do not use timestamps with time-of-day in JSONL entries.
- Do not use UUIDs.
- Keep `entryId` monotonic.
- Keep field names stable across runs.

## Guardrails

- Never rewrite history without explicit user approval.
- Prefer non-destructive remediation when possible.
- Record decision first; execute second.
- Revalidate after approved changes.
