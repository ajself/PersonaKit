# Pack Gardening Standards

Use this runtime standard to keep packs and sessions aligned to current project workflows.
For full maintenance detail, see `pack-gardening-standards-reference`.

## Core Rules

1. Keep active packs aligned to current workflows and phase boundaries.
2. Keep sessions accurate, discoverable, and reviewable.
3. Record decisions and drift in canonical gardening logs.
4. Improve incrementally; avoid broad speculative rewrites.

## Root Boundary Rules

1. `.personakit` keeps plain ids for repo-owned entities.
2. `~/.personakit` should use namespaced ids for AJ baseline entities when a repo-local plain id already exists.
3. Allow same-id entities across roots only when they are intentionally universal and byte-identical.

## Prompt-Budget Guardrails

1. Style and review session exports should target `<= 20 KB`.
2. Orchestration and workflow session exports should target `<= 30 KB`.
3. Any session over `35 KB` needs explicit justification.
4. Any essential over roughly `4 KB` included by a core kit should be split into:
   - a short runtime form
   - and a reference, template, or checklist companion
5. Any directive over roughly `4 KB` should be reviewed for schema or template prose that belongs elsewhere.

## Execution Guardrails

1. No broad renaming without migration notes.
2. No deleting sessions without replacement or deprecation note.
3. Revalidate after edits.
4. Keep analysis-only and execution phases explicit.
