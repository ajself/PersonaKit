# Session Directory

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Provide a compact, phase-grouped index of available sessions in the repository
root `.personakit`.

Lifecycle convention:

- `Docs/Development/session-lifecycle-states.md`

Lifecycle legend:

- `active`: default workflow for current delivery loops
- `candidate`: specialized or on-deck workflow
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

## Pack Maintenance Workflows

- `pack-gardener-maintenance` - owner: `pack-gardener` - state: `active`
- `git-history-gardener` - owner: `pack-gardener` - state: `active`
- `rosie-worktree-upkeep` - owner: `pack-gardener` - state: `active`

## Partner Sync Workflows

- `samwise-partner-sync` - owner: `samwise` - state: `active`
- `samwise-coffee-checkpoint` - owner: `samwise` - state: `active`
- `samwise-persona-hiring` - owner: `samwise` - state: `candidate`
- `samwise-persona-hiring-calibration` - owner: `samwise` - state: `candidate`
- `samwise-daily-closeout` - owner: `samwise` - state: `active`

## Venture Product Workflows

- `venture-product-discovery` - owner: `venture-product-steward` - state: `active`
- `venture-product-planning` - owner: `venture-product-steward` - state: `active`
- `venture-product-tracking` - owner: `venture-product-steward` - state: `active`

## State Summary

- `active`: 10 sessions
- `candidate`: 8 sessions
- `deprecated`: 0 sessions

## Workspace Session Directories

- [Venture Studio Session Directory](../../Workspaces/VentureStudio/Docs/Development/session-directory.md)
