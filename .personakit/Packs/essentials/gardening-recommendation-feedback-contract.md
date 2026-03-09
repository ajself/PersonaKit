# Gardening Recommendation Feedback Contract

Use this essential to record recommendation outcomes so gardening quality can
improve from accepted/deferred/rejected feedback.

## Purpose

1. Preserve deterministic evidence for recommendation quality.
2. Prevent repeated low-value recommendations.
3. Enable score-tuning and prioritization improvements.

## Canonical Files

1. `Docs/PersonaKit/Development/logs/gardening-recommendation-feedback.schema.json`
2. `Docs/PersonaKit/Development/logs/gardening-recommendation-feedback.jsonl`
3. `Docs/PersonaKit/Development/logs/gardening-recommendations.schema.json`
4. `Docs/PersonaKit/Development/logs/gardening-recommendations.jsonl`

## Required Fields

Each JSONL entry must include:

- `entryId` (`GRF-*`)
- `date` (`YYYY-MM-DD`)
- `sessionId`
- `recommendationId` (`GREC-*`)
- `tool`
- `summary`
- `priority`
- `decision`
- `outcome`
- `evidenceRefs` (string array)
- `nextAction`
- `reviewer`

## Guardrails

1. Keep recommendation IDs stable and reusable across follow-ups.
2. Record decision and outcome separately (`accepted` may still be `pending`).
3. Append feedback entries; do not mutate historical decisions.
