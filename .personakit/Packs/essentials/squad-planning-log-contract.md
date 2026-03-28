# Squad Planning Log Contract

Use this runtime contract when recording durable outputs from squad-planning passes.
For field examples and extended notes, see `squad-planning-log-contract-reference`.

## Canonical Paths

1. Human report directory: `Docs/PersonaKit/Development/planning-reviews/`
2. Machine log: `Docs/PersonaKit/Development/logs/squad-planning-reviews.jsonl`
3. Machine schema: `Docs/PersonaKit/Development/logs/squad-planning-reviews.schema.json`

## Required Fields

Each entry should include:

1. Stable entry id and date.
2. `sessionId`, objective, workspace scope, and scope boundary.
3. Report path.
4. Role assignments and missing artifacts.
5. First checkpoint and definition of done.
6. Validation owner, validation commands, and validation status.
7. Handoff status and next session id.

When delegated roles or workstream routing apply, also record:

1. Delegated handoffs with grounding mode, write scope, validation commands, and failure disposition.
2. Derived `workstream` routing fields when the directive carries workstream metadata.

## Guardrails

1. Append only; do not overwrite prior entries.
2. Keep role coverage explicit, including missing roles.
3. Keep the report and JSONL entry aligned on next session, first checkpoint, and delegated handoffs.
4. Treat projected workstream fields as derived visibility, not source-of-truth routing.

## Validation

Run `Scripts/check-squad-planning-logs.sh`.
