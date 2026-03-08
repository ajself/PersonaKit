# Gardening Health Snapshot Contract

Use this essential to capture deterministic health snapshots for gardening
coverage and trend visibility.

## Purpose

1. Provide a compact health baseline per upkeep pass.
2. Track drift pressure and recommendation throughput over time.
3. Support recommendation scoring with stable evidence.

## Canonical Files

1. `Docs/Development/logs/gardening-health-snapshots.schema.json`
2. `Docs/Development/logs/gardening-health-snapshots.jsonl`

## Required Fields

Each JSONL entry must include:

- `entryId` (`GHS-*`)
- `date` (`YYYY-MM-DD`)
- `sessionId`
- `phaseLabel`
- `windowLabel` (`all-time`, `rolling-7`, `rolling-30`)
- `totalEvents`
- `recentEvents`
- `openBacklogItems`
- `recommendationAcceptedCount`
- `recommendationDeferredCount`
- `recommendationRejectedCount`
- `topRiskAreas` (string array)
- `recommendedFocusAreas` (string array)
- `reviewer`

## Guardrails

1. Do not use timestamps; use date-only entries.
2. Keep IDs monotonic and append-only.
3. Record one snapshot per approved maintenance pass at minimum.
