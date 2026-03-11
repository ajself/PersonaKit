# Development Logs

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-10

## Purpose

Centralized machine-readable logs for development operating loops, including
gardening, hiring, partner continuity, and worktree-squad delivery.

## Files

- `gardening-events.jsonl`: shared event stream for all gardening sessions.
- `gardening-events.schema.json`: base schema for shared event entries.
- `gardening-health-snapshots.jsonl`: deterministic health snapshot stream.
- `gardening-health-snapshots.schema.json`: schema for health snapshots.
- `gardening-recommendations.jsonl`: ranked `GREC-*` recommendation stream.
- `gardening-recommendations.schema.json`: schema for recommendation scoring output.
- `gardening-recommendation-feedback.jsonl`: recommendation decision/outcome stream.
- `gardening-recommendation-feedback.schema.json`: schema for recommendation feedback entries.
- `gardening-pack-coverage.jsonl`: pack graph coverage snapshot stream.
- `gardening-pack-coverage.schema.json`: schema for coverage snapshots.
- `gardening-policy-conflicts.jsonl`: policy conflict detector stream.
- `gardening-policy-conflicts.schema.json`: schema for policy conflict findings.
- `gardening-safety-preflight.jsonl`: self-gardening safety preflight stream.
- `gardening-safety-preflight.schema.json`: schema for safety preflight entries.
- `git-history-gardener.jsonl`: session-specific git-history log profile.
- `git-history-gardener.schema.json`: session-specific schema extension profile.
- `git-history-gardener-proposals.jsonl`: canonical append-only proposal stream for git-history gardening recommendations.
- `git-history-gardener-proposals.schema.json`: schema for git-history proposal entries.
- `persona-hiring-reviews.jsonl`: reverse-interview outcome stream for persona hiring assessments.
- `persona-hiring-reviews.schema.json`: schema for persona hiring review entries.
- `partner-context-events.jsonl`: canonical partner-continuity event stream.
- `partner-context-events.schema.json`: schema for partner continuity entries.
- `partner-handoffs.jsonl`: canonical partner handoff event stream.
- `partner-handoffs.schema.json`: schema for partner handoff entries.
- `samwise-diary.jsonl`: Samwise end-of-day reflection diary.
- `samwise-diary.schema.json`: schema for Samwise diary entries.
- `squad-planning-reviews.jsonl`: durable planning-review stream for Samwise squad formation and handoff passes.
- `squad-planning-reviews.schema.json`: schema for squad planning review entries.
- `session-stack-reviews.jsonl`: durable Samwise session-review stream for PersonaKit session audits.
- `session-stack-reviews.schema.json`: schema for session-review entries.
- `worktree-squad-loops.jsonl`: squad-loop execution stream for delivery/oversight passes.
- `worktree-squad-loops.schema.json`: schema for squad-loop entries.
- `worktree-squad-retrospectives.jsonl`: retrospective/recommendation stream for squad iterations.
- `worktree-squad-retrospectives.schema.json`: schema for squad retrospective entries, supporting legacy and Starfish-shaped records.
- `../partner-context-log.md`: generated partner-context projection over `partner-context-events.jsonl`.
- `../partner-handoff-register.md`: generated handoff projection over `partner-handoffs.jsonl`.
- `../pack-gardener-log.md`: generated maintenance projection over `gardening-events.jsonl`.
- `../git-history-gardener-log.md`: generated git-history projection over `git-history-gardener.jsonl`.
- `../git-history-gardener-proposals.md`: generated proposal projection over `git-history-gardener-proposals.jsonl`.

## Resource Catalog

Operational ledgers should be reasoned about as logical resources first, with
the current backend noted explicitly:

- `partner-context`
  - backend: `jsonl`
  - canonical path: `partner-context-events.jsonl`
  - projection path: `../partner-context-log.md`
- `partner-handoffs`
  - backend: `jsonl`
  - canonical path: `partner-handoffs.jsonl`
  - projection path: `../partner-handoff-register.md`
- `gardening-events`
  - backend: `jsonl`
  - canonical path: `gardening-events.jsonl`
  - projection path: `../pack-gardener-log.md`
- `git-history-gardener`
  - backend: `jsonl`
  - canonical path: `git-history-gardener.jsonl`
  - projection path: `../git-history-gardener-log.md`
- `git-history-proposals`
  - backend: `jsonl`
  - canonical path: `git-history-gardener-proposals.jsonl`
  - projection path: `../git-history-gardener-proposals.md`

This resource vocabulary is the database seam for future migration: resource
IDs, business keys, and schema meaning should stay stable even when storage
moves beyond flat files.

## Contract Rule

### Gardening Logs

When a gardening session writes to a session-specific JSONL file, it should also
mirror accepted decisions into `gardening-events.jsonl`.
Health snapshots and recommendation feedback should be updated for each
maintenance pass.
Recommendation ranking updates should also be appended to
`gardening-recommendations.jsonl`.
Coverage, policy-conflict, and safety-preflight updates should also be appended
for each non-trivial gardening pass.

### Persona Hiring Logs

Each reverse-interview pass should produce:

1. One human-readable report in `Docs/PersonaKit/Development/hiring-reviews/`
2. One schema-valid entry in `persona-hiring-reviews.jsonl`

### Samwise Continuity Logs

Each closeout checkpoint should append one schema-valid entry to
`samwise-diary.jsonl` with continuity-ready learning and next-goal fields.
`./Scripts/samwise-closeout.sh` is the wrapped append-and-verify path for
checkpoint closeouts that also need a matching partner-context event.

### Partner Continuity Logs

Partner continuity and handoffs should use canonical JSONL resources:

1. `partner-context-events.jsonl`
2. `partner-handoffs.jsonl`

The markdown partner log and handoff register are generated projections and
must not be treated as the authoritative store.

### Squad Planning Logs

Each `samwise-squad-planning` pass should produce:

1. One human-readable report in `Docs/PersonaKit/Development/planning-reviews/`
2. One schema-valid entry in `squad-planning-reviews.jsonl`
3. A named next session that routes missing-role follow-up through hiring or
   remediation before execution when role coverage is incomplete
4. A derived `workstream` routing summary when the active directive carries
   workstream metadata

### Session Stack Review Logs

Each `samwise-session-stack-review` pass should produce:

1. One human-readable report in `Docs/PersonaKit/Development/session-reviews/`
2. One schema-valid entry in `session-stack-reviews.jsonl`
3. An explicit MCP status plus safe/caution/unsafe/blocked verdict

### Worktree Squad Logs

Each delivery loop and retrospective should append schema-valid entries to the
corresponding `worktree-squad-*.jsonl` stream, including gate evidence and
report-path references when applicable.

Use `worktree-squad-loop-log-contract` for active loop entries and
`worktree-squad-retrospective-log-contract` for closeout retrospectives and
recommendation entries.

New retrospective entries should use the Starfish shape by default.
New retrospective entries should also record:

1. `retrospectiveMethod`
2. `declaredRoles`
3. `actualParticipants`
4. `participantEvidencePaths`
5. `subagentCount`
6. `featureConfidence`
7. `productConfidence`
8. `processConfidence`

This keeps the log honest about who actually participated and what kind of
confidence was earned.

Legacy retrospective entries remain valid for historical continuity.

When the active session's directive carries workstream metadata, new planning,
loop, and retrospective entries should also record a derived `workstream`
object with:

1. `id`
2. `phase`
3. `currentSessionId`
4. `entrySessionId`
5. `nextSessionIds`
6. `requiredCloseoutSessionId`

This routing object is visibility for humans and validators. It does not
replace directive-owned workstream metadata as the source of truth.

## Historical Interpretation

Append-only logs may reference retired artifact IDs or file paths after the
active graph changes.

When that happens:

1. Keep the existing log rows unchanged.
2. Resolve retired IDs through
   `Docs/PersonaKit/Development/historical-artifact-tombstones.md`.
3. Add a new continuity entry if the retirement itself needs durable
   explanation.

This keeps recorded history stable while preserving a clear translation path to
the current state.

## Validation

Run:

- `swift run personakit log-docs --root .personakit --check`
- `Scripts/check-operational-records.sh`
- `Scripts/check-gardening-logs.sh`
- `Scripts/check-persona-hiring-logs.sh`
- `Scripts/check-squad-planning-logs.sh`
- `Scripts/check-session-stack-review-logs.sh`
- `Scripts/check-worktree-squad-logs.sh`

Expected output:

- no drift from `log-docs --check`
- `OPERATIONAL_RECORDS_CHECK:PASS`
- `GARDENING_LOGS_CHECK:PASS`
- `PERSONA_HIRING_LOGS_CHECK:PASS`
- `SQUAD_PLANNING_LOGS_CHECK:PASS`
- `SESSION_STACK_REVIEW_LOGS_CHECK:PASS`
- `WORKTREE_SQUAD_LOGS_CHECK:PASS`

## Bootstrap

Use `swift run personakit migrate-log-records --root .personakit --write` only for
one-time import from legacy hand-authored markdown ledgers. It is not part of
steady-state validation once the canonical JSONL streams are established.
