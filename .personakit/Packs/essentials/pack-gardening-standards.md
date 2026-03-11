# Pack Gardening Standards

Use this essential to keep Packs and Sessions accurate as project phases evolve.

## Objectives

1. Keep active packs aligned to current project workflows.
2. Keep sessions accurate, discoverable, and phase-appropriate.
3. Record drift, decisions, and follow-up items in stable logs.
4. Improve incrementally without broad, speculative rewrites.

## Required Logs

For each project using this pack, maintain:

1. `Docs/PersonaKit/Development/pack-gardener-log.md`
2. `Docs/PersonaKit/Development/logs/gardening-events.jsonl`
3. `Docs/PersonaKit/Development/logs/gardening-events.schema.json`
4. `Docs/Archive/PersonaKit/Plans/Archive/pack-session-improvement-backlog.md`
5. `Docs/PersonaKit/Development/logs/gardening-health-snapshots.jsonl`
6. `Docs/PersonaKit/Development/logs/gardening-health-snapshots.schema.json`
7. `Docs/PersonaKit/Development/logs/gardening-recommendation-feedback.jsonl`
8. `Docs/PersonaKit/Development/logs/gardening-recommendation-feedback.schema.json`
9. `Docs/PersonaKit/Development/logs/gardening-recommendations.jsonl`
10. `Docs/PersonaKit/Development/logs/gardening-recommendations.schema.json`
11. `Docs/PersonaKit/Development/logs/gardening-pack-coverage.jsonl`
12. `Docs/PersonaKit/Development/logs/gardening-pack-coverage.schema.json`
13. `Docs/PersonaKit/Development/logs/gardening-policy-conflicts.jsonl`
14. `Docs/PersonaKit/Development/logs/gardening-policy-conflicts.schema.json`
15. `Docs/PersonaKit/Development/logs/gardening-safety-preflight.jsonl`
16. `Docs/PersonaKit/Development/logs/gardening-safety-preflight.schema.json`

`pack-gardener-log.md` is a generated projection over `gardening-events.jsonl`.
Update the canonical JSONL first, then refresh the markdown projection.

## Maintenance Cadence

Run a maintenance pass:

1. At phase kickoff.
2. At major milestone transitions.
3. At phase closeout.

Run `gardening-v2-checklist` during every maintenance pass.
At milestone/phase closeout, use the repo closeout checklist if available and
log the result in maintenance records.

## Required Log Fields

Each log entry should include:

- date
- phase/milestone label
- observed drift or mismatch
- decision taken
- affected IDs (persona/kit/directive/session)
- verification status

Each JSONL entry should follow `gardening-log-contract` required fields.
Each maintenance pass should also record one health snapshot and any accepted
or deferred recommendation outcomes.
Recommendation updates should include ranked `GREC-*` entries with deterministic
score breakdown and explanation fields.
Each maintenance pass should record coverage snapshot, policy-conflict detector
status, and self-gardening safety preflight status.
Refresh generated log projections after canonical JSONL updates.

## Guardrails

- No broad renaming without migration notes.
- No deleting sessions without replacement or deprecation note.
- No scope expansion beyond pack/session maintenance intent.
- Revalidate after edits.
- Keep analysis-only and execution phases explicitly separated.
- Self-gardening is allowed, but follows the same analysis-only, review, and
  approved-execution flow as any other gardening pass.
