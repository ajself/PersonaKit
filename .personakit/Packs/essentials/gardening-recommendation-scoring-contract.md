# Gardening Recommendation Scoring Contract

Use this essential to produce deterministic, explainable recommendation
rankings for gardening upkeep actions.

## Purpose

1. Prioritize upkeep actions with a stable score model.
2. Keep recommendation rankings explainable and reviewable.
3. Provide durable `GREC-*` identifiers for feedback loops.

## Canonical Files

1. `Docs/PersonaKit/Development/logs/gardening-recommendations.schema.json`
2. `Docs/PersonaKit/Development/logs/gardening-recommendations.jsonl`

## Score Model

Use the fixed model `R3-I3-U2-E1`:

- `riskScore` weight: 3
- `driftImpactScore` weight: 3
- `urgencyScore` weight: 2
- `effortScore` weight: inverse weight 1 via `(5 - effortScore)`

Formula:

`totalScore = risk*3 + impact*3 + urgency*2 + (5 - effort)`

## Priority Thresholds

- `high` when `totalScore >= 32`
- `medium` when `totalScore >= 22` and `< 32`
- `low` when `< 22`

## Required Explanation Fields

Each recommendation entry must include:

- `rankingSetId`
- `whyNow`
- `expectedImpact`
- `evidenceRefs`
- `nextAction`

## Guardrails

1. Keep `GREC-*` IDs unique and append-only in the recommendation stream.
2. Keep ranking deterministic for identical inputs within each `rankingSetId`.
3. Use feedback logs to track follow-up outcomes for existing recommendations.
4. Do not hide scoring rationale; record score components and total.
