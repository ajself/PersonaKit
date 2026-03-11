# Workstream Directory

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-11

## Purpose

Provide a compact index of workstream-aware session families without changing
session-file semantics.

Directive-owned workstream metadata remains authoritative. This directory is a
human-facing projection for orientation and planning.

## Active Workstreams

### `worktree-squad-lifecycle`

- Entry session: `samwise-squad-planning`
- Required closeout session: `worktree-squad-retrospective`

Session map:

- `planning` -> `samwise-squad-planning`
- `oversight` -> `samwise-worktree-squad-oversight`
- `delivery` -> `worktree-squad-delivery`
- `retrospective` -> `worktree-squad-retrospective`
- `gardening` -> `rosie-retrospective-garden`

Edge map:

- `samwise-squad-planning` -> `samwise-worktree-squad-oversight` (`required-next`)
- `samwise-worktree-squad-oversight` -> `worktree-squad-delivery` (`required-next`)
- `worktree-squad-delivery` -> `worktree-squad-retrospective` (`required-closeout`)
- `worktree-squad-retrospective` -> `rosie-retrospective-garden` (`optional-follow-up`)

Participating sessions:

- `samwise-squad-planning`
- `samwise-worktree-squad-oversight`
- `worktree-squad-delivery`
- `worktree-squad-retrospective`
- `rosie-retrospective-garden`
