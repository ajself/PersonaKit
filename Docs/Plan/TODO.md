# TODO

Last Updated: 2026-03-07

## Purpose

Keep execution focused. This file lists only actionable, in-order tasks.

## Action Queue (In Order)

### 1) Git History Gardening Cadence (Execute Next, Ongoing)

Plan source:

- `Docs/Plan/git-history-gardener-proposals.md`
- `Docs/Plan/git-history-gardener-log.md`

Objective:

- Keep history cleanup proposal-first and approval-gated.

Actions:

1. Run analysis-only passes for future ranges as needed.
2. Keep proposals explicit (`pending`/`approved`/`rejected`).
3. Execute only approved proposals.
4. Validate logs with `Scripts/check-gardening-logs.sh` after each pass.

Exit criteria:

1. Every history edit is proposal-backed and approval-tracked.
2. Log contract remains valid.

Execution note:

- Analysis pass #4 completed on 2026-03-07 with no new pending proposals.

### 2) Samwise Daily Closeout Ritual (Ongoing)

Plan source:

- `.personakit/Sessions/samwise-daily-closeout.session.json`
- `.personakit/Packs/directives/run-samwise-daily-closeout.directive.json`
- `Docs/Plan/logs/samwise-diary.jsonl`

Objective:

- Run a consistent end-of-day routine that records progress, learning, and next-day restart goals.

Actions:

1. Run `samwise-daily-closeout` when AJ or Samwise ends an active workday.
2. Append one schema-valid entry to `Docs/Plan/logs/samwise-diary.jsonl`.
3. Include concrete `whatLearned`, `improvements`, and `nextGoals`.
4. If pack/session behavior changed, mirror updates in gardening and partner logs.

Exit criteria:

1. One diary entry exists for each active workday closeout.
2. Entries are specific, actionable, and continuity-ready.
3. Related logs are synchronized when context changes.

## Plan Hygiene Rules

1. Keep only active plans in `Docs/Plan/`.
2. Move completed plans to `Docs/Plan/Archive/`.
3. Keep this TODO ordered and current after each milestone.
