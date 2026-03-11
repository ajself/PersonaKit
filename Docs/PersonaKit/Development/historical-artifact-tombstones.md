# Historical Artifact Tombstones

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-10

## Purpose

Keep historical PersonaKit records interpretable after pack, session, or file
retirements without rewriting recorded history.

Use this index when append-only logs, reviews, or planning artifacts reference a
retired artifact ID or a file path that no longer exists in the active graph.

## Rules

1. Do not rewrite historical JSONL records just to replace retired IDs with
   current ones.
2. Do not silently rewrite historical review conclusions after the underlying
   graph changes.
3. Add a tombstone entry plus new continuity notes when a retired artifact needs
   a current-state translation.
4. Keep current operational docs on current artifact IDs; reserve retired IDs
   for historical interpretation only.

## Translation Workflow

When a historical record references a retired artifact:

1. Resolve the retired ID through this tombstone index.
2. Follow the successor mapping for the current workflow family.
3. Preserve the original historical wording in place.
4. Add new continuity records only when the retirement itself needs durable
   explanation.

## Entries

### `samwise-orchestration-core`

- Entity type: `kit`
- Lifecycle: `retired`
- Retired on: `2026-03-10`
- Historical role: broad Samwise orchestration umbrella spanning planning,
  hiring, worktree oversight, and retrospective context

Reason retired:

1. The kit re-broadened multiple Samwise workflows through one shared override.
2. Hiring ceased to be an explicit capability boundary when loaded through this
   umbrella.
3. Live delivery and retrospective context inherited unrelated planning ballast
   by side effect.

Current-state translation:

1. Historical planning references translate to `samwise-planning-core`.
2. Historical hiring-aware planning or role-gap remediation references
   translate to `persona-hiring-core` plus `samwise-planning-core`.
3. Historical live-delivery oversight references translate to
   `samwise-worktree-oversight-core`.
4. Historical Orbit execution references translate to `orbit-rerun-core`
   plus `samwise-worktree-oversight-core`.
5. Historical retrospective references translate to
   `samwise-retrospective-core` only when retrospective context is explicitly in
   scope.

Successor IDs:

- `persona-hiring-core`
- `samwise-planning-core`
- `samwise-worktree-oversight-core`
- `samwise-retrospective-core`

Continuity references:

- `GL-0038` (`samwise-orchestration-boundary-split`)
- commit `3bcbca0` (`refactor(personakit): narrow hiring orchestration boundaries`)

Interpretation note:

Historical docs and logs may still mention `samwise-orchestration-core` by ID or
file path. Treat those references as describing the retired umbrella boundary,
then translate them through the workflow-specific successors above.

### `samwise-orbit-build-rerun`

- Entity type: `session`
- Lifecycle: `retired`
- Retired on: `2026-03-11`
- Historical role: Orbit startup, staging, contract freeze, and execution handoff

Current-state translation:

1. Use `samwise-orbit-rerun-startup` for the active startup surface.
2. Keep `samwise-orbit-rerun-execution` as the live multiagent execution surface.

Successor IDs:

- `samwise-orbit-rerun-startup`

Interpretation note:

This rename clarifies startup versus execution naming only. Workflow behavior
stayed the same.

### `run-orbit-build-rerun`

- Entity type: `directive`
- Lifecycle: `retired`
- Retired on: `2026-03-11`
- Historical role: Orbit startup directive for staging, contract freeze, and handoff

Successor IDs:

- `run-orbit-rerun-startup`

Interpretation note:

The directive role stayed the same; the active ID now names the startup phase
explicitly.

### `orbit-build-rerun-review`

- Entity type: `intent`
- Lifecycle: `retired`
- Retired on: `2026-03-11`
- Historical role: Orbit startup handoff contract

Successor IDs:

- `orbit-rerun-startup-contract`

Interpretation note:

The active successor keeps the same startup-only role while clarifying that this
surface defines the handoff contract.

### `orbit-build-rerun-core`

- Entity type: `kit`
- Lifecycle: `retired`
- Retired on: `2026-03-11`
- Historical role: Orbit-specific core kit for rerun startup and execution

Successor IDs:

- `orbit-rerun-core`

Interpretation note:

The role stayed the same; the active ID now matches the startup/execution
pairing instead of carrying older build-heavy wording.

### `orbit-build-rerun-playbook`

- Entity type: `essential`
- Lifecycle: `retired`
- Retired on: `2026-03-11`
- Historical role: reusable Orbit rerun playbook for startup and execution

Successor IDs:

- `orbit-rerun-playbook`

Interpretation note:

The role stayed the same; the active essential now uses the shorter rerun
family name.

### `run-orbit-rerun-squad-execution`

- Entity type: `directive`
- Lifecycle: `retired`
- Retired on: `2026-03-11`
- Historical role: live Orbit multiagent execution directive

Successor IDs:

- `run-orbit-rerun-execution`

Interpretation note:

The active successor keeps the same execution role while removing extra wording
from the machine ID.

### `orbit-rerun-squad-execution`

- Entity type: `intent`
- Lifecycle: `retired`
- Retired on: `2026-03-11`
- Historical role: live Orbit multiagent execution contract

Successor IDs:

- `orbit-rerun-execution-contract`

Interpretation note:

The active successor keeps the same execution role while making the contract
phase clearer.

### `orbit-rerun-squad-execution-map`

- Entity type: `essential`
- Lifecycle: `retired`
- Retired on: `2026-03-11`
- Historical role: live Orbit execution routing map

Successor IDs:

- `orbit-rerun-execution-map`

Interpretation note:

The active successor keeps the same routing role while aligning the ID with the
renamed execution contract and directive.
