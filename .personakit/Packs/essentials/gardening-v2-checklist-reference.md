# Gardening V2 Checklist

Use this checklist for every pack/session gardening pass.

## Scope and Mode

1. Confirm pass scope and phase label.
2. Confirm execution mode:
   - analysis-only (proposals only)
   - approved execution (apply approved changes only)
3. Confirm stop points and required human approvals.
4. If the target includes gardener-owned pack/session artifacts, label the pass as self-gardening and keep the same approval gates.

## Drift Scan

1. Check persona/kit/directive/session alignment with current workflows.
2. Check for stale or conflicting policy text across essentials, directives, and intents.
3. Check required logs for completeness and schema-compatible fields.
4. Check TODO/backlog state for active versus completed items.

## Proposal Quality

1. Keep proposals narrow and reversible.
2. Include rationale, affected IDs, and validation plan.
3. Separate analysis proposals from execution decisions.
4. Do not execute proposals without explicit approval.
5. For self-gardening proposals, explicitly list gardener-owned artifacts being modified.

## Policy Sync

1. If a rule changes, update all relevant layers:
   - persona responsibilities/non-goals
   - essentials and constraints
   - directives and intent risk notes
   - maintenance logs and JSONL event stream
2. Confirm no layer still reflects the old rule.

## Validation and Evidence

1. Run `swift run personakit validate --root .personakit`.
2. Run `Scripts/check-gardening-logs.sh`.
3. Record pass/fail evidence in markdown and JSONL logs.

## Closeout

1. Record what changed, why, and what remains open.
2. Capture next action and owner in backlog/TODO as needed.
3. If commit-ready changes exist, state commit authorization mode:
   - per-commit AJ approval by default
   - worktree-scoped auto-commit only when explicitly approved by AJ for a dedicated non-`main` worktree

## Definition of Done

A gardening pass is complete only when:

1. Drift findings are documented.
2. Proposal/execution decisions are explicit.
3. Cross-file policy sync is complete.
4. Validation checks pass.
5. Logs are updated with traceable artifacts and verification status.
6. Self-gardening passes are explicitly labeled and approval-gated in logs.
