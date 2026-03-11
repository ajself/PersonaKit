# Workstream Directory

> Generated file. Do not edit manually.
> Source of truth: directive-owned workstream metadata in `.personakit/Packs/directives/`.

This directory is a committed projection over directive workstream metadata.
Regenerate it with `swift run personakit workstream-docs --root .personakit --write`.

## Active Workstreams

### worktree-squad-lifecycle

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
