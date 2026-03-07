# Documentation Style Guide

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Keep docs easy to scan, easy to trust, and easy to maintain.

## Core Conventions

1. One clear purpose per document.
2. Use plain language first; define jargon when needed.
3. Keep policy and behavior statements testable and specific.
4. Update docs in the same change that updates behavior whenever possible.
5. Prefer stable links across docs to avoid orphaned context.

## Required Header Block

Use this three-line metadata block near the top of operational docs:

- Required for all new operational docs.
- Required when substantially editing an existing operational doc.
- Legacy docs may adopt this gradually when they are touched.

- `Status: Draft | Active | Archived`
- `Owner: <person or team>`
- `Last Reviewed: YYYY-MM-DD`

## File Naming Rules

- Prefer `kebab-case.md` for new standard docs.
- Use `ADR-####-short-title.md` for architecture decisions.
- Existing mixed-case docs may remain until a dedicated rename cleanup.
- Avoid vague names like `notes.md`, `misc.md`, or `temp.md`.

## Folder Intent

- `Docs/Architecture/`: durable technical decisions and invariants.
- `Docs/Development/`: development process, branch closeouts, and working agreements.
- `Docs/MCP/`: MCP-specific usage and debugging guidance.
- `Docs/Plan/`: short-lived plans; remove or close when work is complete.
- `Workspaces/<name>/`: initiative subprojects with isolated docs and `.personakit` roots.

## Structure Expectations

For most docs, include:

1. Why this exists.
2. What to do.
3. How to verify.
4. Related docs.

For plan docs, also include explicit status and next checkpoint.

## Navigation Rules

1. Each new docs subfolder should have a `README.md` index.
2. Each new major doc should include a `Related docs` section.
3. Add cross-links when a document depends on rules from another doc.

## Change Control

1. If behavior changed, update docs in the same commit when feasible.
2. If uncertain, mark uncertainty explicitly with `TBD` and owner/date.
3. Archive obsolete docs instead of silently rewriting history.

## Writing Style

- Prefer short paragraphs and active voice.
- Prefer direct verbs: `run`, `verify`, `stop`, `review`.
- Avoid motivational filler in operational docs.

Related docs:

- [Documentation Index](./README.md)
- [Workspaces Index](../Workspaces/README.md)
