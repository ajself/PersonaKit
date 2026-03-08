# TODO

Last Updated: 2026-03-07

## Purpose

Keep execution focused. This file lists only actionable, in-order tasks.

## Action Queue (In Order)

### 1) Taskboard V2 Initiative (Next)

Plan source:

- `Docs/Plan/taskboard-v2-initiative-plan.md`
- `Docs/Plan/admin-ticket-planning-feature-brief.md`
- `Docs/Plan/taskboard-parity-polish-pass-2.md`

Objective:

- Evolve Taskboard from parity baseline to a genuinely useful, AI-operable
  planning surface with rigorous product/UX evidence.

Actions:

1. Execute `TV2-M2A` (`P0`) from `Docs/Plan/taskboard-v2-feature-lock.md`:
   - labels on tickets
   - due date on tickets
   - checklist on tickets
   - board filtering
2. Resolve and lock the open decisions in
   `Docs/Plan/taskboard-ai-mutation-contract.md` during `M2A` kickoff.
3. Implement snapshot test suite + baselines per
   `Docs/Plan/taskboard-v2-snapshot-lane.md`.
4. Execute `TV2-M2B` (`P1`) after `M2A`:
   - keyboard speed-path baseline
   - search baseline

Exit criteria:

1. `G1` and `G2` are approved in plan artifacts.
2. `G3.5` feature-lock gate is approved in plan artifacts.
3. Research and visual QA lanes are operational and traceable.
4. `TV2-M2A` and `TV2-M2B` are complete with no blocker findings.

### 2) Gardening Tooling Operations (Ongoing)

Plan source:

- `Docs/Plan/gardening-tools-roadmap.md`
- `Docs/Plan/logs/gardening-health-snapshots.jsonl`
- `Docs/Plan/logs/gardening-recommendations.jsonl`
- `Docs/Plan/logs/gardening-recommendation-feedback.jsonl`
- `Docs/Plan/logs/gardening-pack-coverage.jsonl`
- `Docs/Plan/logs/gardening-policy-conflicts.jsonl`
- `Docs/Plan/logs/gardening-safety-preflight.jsonl`

Objective:

- Keep Rosie’s full gardening toolchain healthy and current across upkeep passes.

Actions:

1. Keep health snapshots and ranked `GREC-*` recommendations current for each gardening pass.
2. Keep coverage snapshots, policy-conflict logs, and safety preflight logs updated.
3. If any detector reports failures, stop and record a bounded remediation plan.
4. Keep log checks green after each update.

Exit criteria:

1. All phase 1-4 artifacts remain validated and in active use.
2. Detector outputs remain deterministic and actionable.
3. Any policy/safety failure is captured before non-trivial edits execute.

Execution note:

- Phase 1-4 tooling landed on 2026-03-07; this queue is now operational upkeep.

### 3) Git History Gardening Cadence (Ongoing)

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

### 4) Samwise Daily Closeout Ritual (Ongoing)

Plan source:

- `.personakit/Sessions/samwise-daily-closeout.session.json`
- `.personakit/Packs/directives/run-samwise-daily-closeout.directive.json`
- `Docs/Plan/logs/samwise-diary.jsonl`

Objective:

- Run a consistent closeout-checkpoint routine that records progress, learning, and restart goals.

Actions:

1. Run `samwise-daily-closeout` when AJ and Samwise reach a closeout checkpoint.
2. Append one schema-valid entry to `Docs/Plan/logs/samwise-diary.jsonl`.
3. Include concrete `whatLearned`, `improvements`, and `nextGoals`.
4. If pack/session behavior changed, mirror updates in gardening and partner logs.

Exit criteria:

1. One diary entry exists for each closeout checkpoint.
2. Entries are specific, actionable, and continuity-ready.
3. Related logs are synchronized when context changes.

## Plan Hygiene Rules

1. Keep only active plans in `Docs/Plan/`.
2. Move completed plans to `Docs/Plan/Archive/`.
3. Keep this TODO ordered and current after each milestone.
