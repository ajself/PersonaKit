# Documentation Style Guide

Status: Active  
Owner: Maintainers
Last Reviewed: 2026-03-29

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

- `Status: Active | In Progress | Ready For Review | Blocked | Planned | Accepted | Closed for Closeout | Parked | Archived`
- `Owner: <person or team>`
- `Last Reviewed: YYYY-MM-DD`

## Status Usage

Use status labels consistently:

- `Active`: current operator-facing index, queue, or live operational guide
- `In Progress`: current execution milestone or packet
- `Ready For Review`: waiting on human review or confirmation
- `Blocked`: cannot proceed until a named prerequisite is resolved
- `Planned`: future work, not active execution
- `Accepted`: approved baseline or accepted artifact, but not the live queue by
  itself
- `Closed for Closeout`: functionally complete, pending formal closeout
- `Parked`: intentionally not the active queue, but still has an unresolved
  checkpoint or return condition
- `Archived`: historical only

Status labels describe lifecycle, not cross-repo priority.

`Accepted` and `Archived` do not imply current priority.

Cross-domain priority must be stated in `README.md`,
`Docs/V1_DIRECTION.md`, or the local area `README.md`.

## File Naming Rules

- Prefer `kebab-case.md` for new standard docs.
- Use `ADR-####-short-title.md` for architecture decisions.
- Existing mixed-case docs may remain until a dedicated rename cleanup.
- Avoid vague names like `notes.md`, `misc.md`, or `temp.md`.

## Folder Intent

- `Docs/V1_DIRECTION.md`: active V1 launcher scope and product contract.
- `Docs/`: minimal product and repo guidance for the current V1 surface.

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
