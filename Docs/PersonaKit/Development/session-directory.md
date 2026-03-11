# Session Directory

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-11

## Purpose

Provide a compact, phase-grouped index of available sessions in the repository
root `.personakit`.

Role note: `samwise` is the AJ Trusted Partner persona. Use `Trusted Partner`
in human-facing docs and `AJ Trusted Partner` when a canonical agent-facing
role label is useful.

Lifecycle convention:

- `Docs/PersonaKit/Development/session-lifecycle-states.md`

Lifecycle legend:

- `active`: approved current workflow, including validated specialist lanes
- `candidate`: useful but still provisional or on-deck
- `deprecated`: retained for reference only

## Architecture Review Workflows

- `architectural-editor-review` - owner: `architectural-editor` - state: `candidate`
- `architectural-editor-prompt-review` - owner: `architectural-editor` - state: `candidate`

## Studio Quality Workflows

- `studio-boundary` - owner: `studio-boundary-guardian` - state: `candidate`
- `studio-coverage` - owner: `studio-coverage-architect` - state: `candidate`
- `studio-integration` - owner: `studio-integration-coordinator` - state: `candidate`
- `studio-interaction-quality` - owner: `studio-interaction-quality-lead` - state: `active`
- `studio-reliability` - owner: `studio-reliability-engineer` - state: `candidate`
- `studio-workflow` - owner: `studio-workflow-operator` - state: `candidate`
- `taskboard-board-card-build` - owner: `studio-swiftui-product-engineer` - state: `active`
- `taskboard-parity-design-review` - owner: `taskboard-parity-designer` - state: `active`

## Pack Maintenance Workflows

- `pack-gardener-maintenance` - owner: `pack-gardener` - state: `active`
- `git-history-gardener` - owner: `pack-gardener` - state: `active`
- `rosie-worktree-upkeep` - owner: `pack-gardener` - state: `active`
- `rosie-retrospective-garden` - owner: `pack-gardener` - state: `candidate`

## Partner Sync Workflows

- `samwise-partner-sync` - owner: `samwise` - state: `active`
- `samwise-orbit-rerun-startup` - owner: `samwise` - state: `active`
- `samwise-orbit-rerun-execution` - owner: `samwise` - state: `active`
- `samwise-session-stack-review` - owner: `samwise` - state: `active`
- `samwise-squad-planning` - owner: `samwise` - state: `active`
- `samwise-squad-planning-remediation` - owner: `samwise` - state: `active`
- `samwise-coffee-checkpoint` - owner: `samwise` - state: `active`
- `samwise-persona-hiring` - owner: `samwise` - state: `active`
- `samwise-persona-hiring-calibration` - owner: `samwise` - state: `active`
- `samwise-daily-closeout` - owner: `samwise` - state: `active`
- `samwise-worktree-squad-oversight` - owner: `samwise` - state: `active`

## Worktree Squad Workflows

- `worktree-squad-delivery` - owner: `worktree-squad-lead` - state: `active`
- `worktree-squad-retrospective` - owner: `worktree-squad-lead` - state: `candidate`
- `worktree-squad-calibration` - owner: `worktree-squad-lead` - state: `candidate`

## Venture Product Workflows

- `venture-product-discovery` - owner: `venture-product-steward` - state: `active`
- `venture-product-planning` - owner: `venture-product-steward` - state: `active`
- `venture-product-tracking` - owner: `venture-product-steward` - state: `active`

## State Summary

- `active`: 21 sessions
- `candidate`: 10 sessions
- `deprecated`: 0 sessions

<!-- WORKSTREAM_MEMBERSHIP:START -->
## Workstream Membership

| Session ID | Workstream ID | Phase | Entry Session | Required Closeout Session | Directory Ref |
| --- | --- | --- | --- | --- | --- |
| `rosie-retrospective-garden` | `worktree-squad-lifecycle` | `gardening` | `samwise-squad-planning` | `worktree-squad-retrospective` | [worktree-squad-lifecycle](./workstream-directory.md#worktree-squad-lifecycle) |
| `samwise-squad-planning` | `worktree-squad-lifecycle` | `planning` | `samwise-squad-planning` | `worktree-squad-retrospective` | [worktree-squad-lifecycle](./workstream-directory.md#worktree-squad-lifecycle) |
| `samwise-worktree-squad-oversight` | `worktree-squad-lifecycle` | `oversight` | `samwise-squad-planning` | `worktree-squad-retrospective` | [worktree-squad-lifecycle](./workstream-directory.md#worktree-squad-lifecycle) |
| `worktree-squad-delivery` | `worktree-squad-lifecycle` | `delivery` | `samwise-squad-planning` | `worktree-squad-retrospective` | [worktree-squad-lifecycle](./workstream-directory.md#worktree-squad-lifecycle) |
| `worktree-squad-retrospective` | `worktree-squad-lifecycle` | `retrospective` | `samwise-squad-planning` | `worktree-squad-retrospective` | [worktree-squad-lifecycle](./workstream-directory.md#worktree-squad-lifecycle) |
<!-- WORKSTREAM_MEMBERSHIP:END -->
