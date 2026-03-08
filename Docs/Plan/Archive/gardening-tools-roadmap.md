# Rosie Gardening Tools Roadmap

Status: Archived  
Owner: AJ  
Last Reviewed: 2026-03-08

## Status Snapshot (2026-03-07)

1. Phase 1: Complete.
2. Phase 2: Complete.
3. Phase 3: Complete.
4. Phase 4: Complete.

Historical note:

- Archived after all planned phases landed; ongoing upkeep now lives in
  `Docs/Development/` and `Docs/Development/logs/`.

## Purpose

Define a phased, deterministic upgrade path for Rosie gardening so pack/persona
health improves through better observability, recommendation quality, and
policy-safety automation.

## Baseline

Current state (2026-03-07):

1. Core gardening contracts are valid (`personakit validate`, gardening log checks pass).
2. Decision logging is strong, but health snapshots and recommendation outcomes are not first-class streams.
3. Recommendation quality is mostly manual judgment without explicit scoring telemetry.

## Tool Plan

### Phase 1: Observability Spine (Execute First)

Objective:

- Establish deterministic telemetry for health snapshots and recommendation outcomes.

Deliverables:

1. `Docs/Development/logs/gardening-health-snapshots.schema.json`
2. `Docs/Development/logs/gardening-health-snapshots.jsonl`
3. `Docs/Development/logs/gardening-recommendation-feedback.schema.json`
4. `Docs/Development/logs/gardening-recommendation-feedback.jsonl`
5. Validation wiring in `Scripts/check-gardening-logs.sh`
6. Contract updates in gardening essentials/standards docs

Acceptance criteria:

1. Both new streams are schema-validated by default checks.
2. At least one bootstrap entry exists for each stream.
3. Existing gardening checks remain green.

### Phase 2: Recommendation Scoring Engine

Objective:

- Rank maintenance actions with deterministic, explainable scoring.

Deliverables:

1. `gardening-recommendation-engine` scoring rubric (risk, drift impact, urgency, effort).
2. Stable recommendation IDs for traceability (`GREC-*`).
3. Explanation contract: every recommendation must include why-now and expected impact.

Acceptance criteria:

1. Recommendation output is deterministic for identical input.
2. Output includes ranked list with score breakdown.
3. Deferred/rejected outcomes are capturable in feedback stream.

Execution note:

- Completed on 2026-03-07 with `GREC-*` schema, seeded ranked outputs, and
  validator enforcement in default gardening checks.

### Phase 3: Coverage and Policy Integrity Auditors

Objective:

- Detect structural drift early across personas/kits/directives/intents/essentials.

Deliverables:

1. `pack-coverage-auditor` report contract.
2. `policy-conflict-detector` rule set (conflicting guardrails, stale references, missing links).
3. Bounded remediation checklist for high-severity findings.

Acceptance criteria:

1. Auditor output is deterministic and diff-friendly.
2. High-severity conflicts are surfaced before execution changes.
3. Findings map to concrete target IDs for small follow-ups.

Execution note:

- Completed on 2026-03-07 with coverage snapshots, policy-conflict detector
  logging, and validator-backed reference integrity checks.

### Phase 4: Self-Gardening Safety Automation

Objective:

- Ensure Rosie self-edits never bypass review gates.

Deliverables:

1. `self-gardening-safety-check` preflight rules for stop points/review requirements.
2. Explicit fail-fast outputs when scope or lane constraints are violated.
3. Integration into upkeep loop verification steps.

Acceptance criteria:

1. Non-trivial self-gardening cannot proceed without required review stop.
2. Lane/main scope violations are blocked with actionable error text.
3. Safety check results are recorded in maintenance logs.

Execution note:

- Completed on 2026-03-07 with safety preflight contracts/logs and
  fail-fast validator checks for review gates and lane/main scope.

## Priority Order

1. Phase 1 (Observability Spine)
2. Phase 2 (Recommendation Scoring)
3. Phase 3 (Coverage + Policy Auditors)
4. Phase 4 (Self-Gardening Safety Automation)

## Operational Notes

1. Keep all outputs deterministic (stable IDs, append-only JSONL, no timestamps).
2. Keep changes bounded and reviewable; no broad refactors.
3. Mirror accepted planning/execution decisions into `gardening-events.jsonl`.
