# Pack Gardening Standards

Use this essential to keep Packs and Sessions accurate as project phases evolve.

## Objectives

1. Keep active packs aligned to current project workflows.
2. Keep sessions accurate, discoverable, and phase-appropriate.
3. Record drift, decisions, and follow-up items in stable logs.
4. Improve incrementally without broad, speculative rewrites.

## Required Logs

For each project using this pack, maintain:

1. `Docs/Plan/pack-gardener-log.md`
2. `Docs/Plan/pack-session-improvement-backlog.md`
3. `Docs/Plan/logs/gardening-events.jsonl`
4. `Docs/Plan/logs/gardening-events.schema.json`

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

## Guardrails

- No broad renaming without migration notes.
- No deleting sessions without replacement or deprecation note.
- No scope expansion beyond pack/session maintenance intent.
- Revalidate after edits.
- Keep analysis-only and execution phases explicitly separated.
- Self-gardening is allowed, but follows the same analysis-only, review, and approved-execution flow as any other gardening pass.
