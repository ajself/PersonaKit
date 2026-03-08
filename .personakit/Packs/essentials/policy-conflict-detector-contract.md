# Policy Conflict Detector Contract

Use this essential to detect contradictory guardrails across upkeep directives,
intents, and persona boundaries.

## Purpose

1. Catch policy contradictions before edits execute.
2. Ensure review-stop and branch-scope requirements remain explicit.
3. Keep conflict findings deterministic and actionable.

## Canonical Files

1. `Docs/Plan/logs/gardening-policy-conflicts.schema.json`
2. `Docs/Plan/logs/gardening-policy-conflicts.jsonl`

## Required Invariants

1. Key gardening directives include at least one review stop step
   (`requiresReview: true`).
2. Key gardening intents require human review when risk is medium/high.
3. Rosie upkeep wording preserves lane/main scope constraints.

## Guardrails

1. Conflict findings are recorded before mutation.
2. `conflictCount > 0` blocks approved execution until reviewed.
