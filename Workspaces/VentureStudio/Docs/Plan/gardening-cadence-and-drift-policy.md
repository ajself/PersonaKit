# Gardening Cadence and Drift Policy

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Define when and how planning/content governance maintenance passes are run.

## Cadence Rules

1. Run one gardening pass every active workday when initiative docs changed
   since the previous gardening pass.
2. Run one additional gardening pass before milestone closeout.
3. If no docs changed, record `no changes` and skip remediation.

## Drift Triggers

A gardening pass is mandatory when any trigger is present:

- stale metadata (`Status`, `Owner`, `Last Reviewed` missing or incorrect)
- broken links
- rubric-template mismatch
- unresolved findings missing owner/disposition

## Gardening Pass Workflow

1. detect drift
2. classify severity
3. assign owner
4. set disposition
5. verify remediation
6. log pass summary

## Severity and SLA Defaults

- Blocker drift: remediate same day before new pass progression.
- Major drift: remediate within current milestone.
- Minor drift: queue with explicit disposition.

## Logging Requirements

Each gardening pass log entry must include:

- date
- scope scanned
- triggers found
- actions taken
- unresolved items
- verification outcome

For deterministic tracking and tool reuse, accepted decisions should also be
mirrored to:

- `Docs/PersonaKit/Development/logs/gardening-events.jsonl`

using the shared contract in:

- `.personakit/Packs/essentials/gardening-log-contract.md`

## Gate Interaction

- Unresolved blocker drift blocks movement to `final` pass.
- Repeated major drift across two passes triggers protocol review.
