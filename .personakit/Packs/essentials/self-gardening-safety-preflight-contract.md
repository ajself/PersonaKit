# Self-Gardening Safety Preflight Contract

Use this essential to enforce review gates and lane-scope checks before
non-trivial self-gardening updates.

## Purpose

1. Prevent self-gardening bypass of review stop points.
2. Confirm branch scope and integration scope are explicit.
3. Record preflight outcomes for traceability.

## Canonical Files

1. `Docs/Plan/logs/gardening-safety-preflight.schema.json`
2. `Docs/Plan/logs/gardening-safety-preflight.jsonl`

## Required Preflight Checks

1. Active gardening directives include an explicit review stop.
2. Upkeep intent risk metadata requires human review.
3. Lane and integration branch expectations are explicit for Rosie upkeep.

## Guardrails

1. Any failed preflight check blocks approved execution.
2. Blocked actions must be listed in preflight logs.
