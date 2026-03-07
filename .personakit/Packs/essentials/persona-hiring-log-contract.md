# Persona Hiring Log Contract

Use this essential when recording reverse-interview outcomes for persona candidates.

## Canonical Paths

1. Human report directory: `Docs/Plan/hiring-reviews/`
2. Machine log file: `Docs/Plan/logs/persona-hiring-reviews.jsonl`
3. Machine schema file: `Docs/Plan/logs/persona-hiring-reviews.schema.json`

## Required JSONL Fields

Each log entry should include:

1. `entryId` (`PHR-0001` style stable ID)
2. `date` (`YYYY-MM-DD`)
3. `sessionId` (`samwise-persona-hiring`)
4. `personaId` (candidate)
5. `roleContext`
6. `verdict`
7. `confidencePercent`
8. `thresholdPercent`
9. `strengths` (array)
10. `gaps` (array with severity)
11. `unknowns` (array)
12. `evidenceRefs` (array)
13. `recommendations` (grouped by artifact type)
14. `firstStep`
15. `reportPath`
16. `reviewer`

## Review Status Rule

1. Draft analysis may be marked as pending.
2. Any approved follow-up must be reflected with updated status in the next entry.
3. Do not overwrite prior entries; append new entries only.

## Guardrails

- Keep IDs deterministic and monotonic.
- Keep claims evidence-backed.
- Do not log sensitive data unrelated to hiring fit.

## Validation

Run:

- `Scripts/check-persona-hiring-logs.sh`
