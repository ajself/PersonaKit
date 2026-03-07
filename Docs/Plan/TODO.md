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

- Analysis pass #3 completed on 2026-03-07 with no new pending proposals.

### 2) Session Lifecycle States (`PSG-002`)

Plan source:

- `Docs/Plan/pack-session-improvement-backlog.md`
- `Docs/Development/session-directory.md`
- `.personakit/Sessions/*`

Objective:

- Define and apply lifecycle states for sessions: `active`, `candidate`, `deprecated`.

Actions:

1. Define lifecycle-state convention and usage rules.
2. Apply states to current session inventory.
3. Reflect states in session directory and related docs.
4. Validate PersonaKit packs and session references.

Exit criteria:

1. All sessions have one lifecycle state.
2. Session directory and conventions agree with assigned states.
3. `personakit validate` passes.

### 3) Recurring Closeout Checklist (`PSG-003`)

Plan source:

- `Docs/Plan/pack-session-improvement-backlog.md`
- `Docs/Plan/pack-gardener-log.md`
- `Docs/Plan/TODO.md`

Objective:

- Add a recurring closeout checklist entry so pack/session maintenance is not skipped at phase transitions.

Actions:

1. Define checklist trigger (for example, end of milestone or closeout pass).
2. Add checklist step in the appropriate maintenance docs.
3. Ensure TODO queue references the recurring check.
4. Log adoption in pack gardener records.

Exit criteria:

1. Closeout checklist location is documented and reusable.
2. Future closeout passes include pack/session maintenance by default.
3. Docs are updated and internally consistent.

### 4) Samwise Daily Closeout Ritual (Ongoing)

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
