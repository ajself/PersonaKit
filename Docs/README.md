# Documentation Index

Status: Active
Owner: AJ
Last Reviewed: 2026-03-29

Use this file as the navigation map for project documentation.

## Start Here Now

- [Current State](./Current-State.md): the only active-work authority for the
  repo-wide queue, including the one current work item, staged next item, and
  non-active work.

## Current Direction

- [Orbit](./Orbit/README.md): current forward product direction, active Orbit
  planning docs, architecture, RFCs, and meeting history.
- [MCP](./MCP/README.md): current MCP behavior, launch guidance, and
  troubleshooting.

## PersonaKit Engine And Repo Operations

- [PersonaKit](./PersonaKit/README.md): current engine/runtime documentation and
  repo operating model.
- [Style Guide](./STYLEGUIDE.md): conventions for structure, naming, and updates.
- [Architecture](./PersonaKit/Architecture/): ADRs, boundaries, and domain maps.
- [Development](./PersonaKit/Development/): workflow rules, durable operating
  records, validation harness, and branch narratives.
- [Worktree Squad Cheat Sheet](./PersonaKit/Development/worktree-squad-cheat-sheet.md): visual map of Samwise, squad-leader, and Rosie delivery loops.
- [Session Directory](./PersonaKit/Development/session-directory.md): phase-grouped list of available sessions.
- [Session Lifecycle States](./PersonaKit/Development/session-lifecycle-states.md): lifecycle-state definitions and assignment rules.
- [Closeout Checklist](./PersonaKit/Development/closeout-checklist.md): recurring closeout steps for maintenance, logs, and validation.
- [Workspaces](../Workspaces/): initiative subprojects with their own docs and `.personakit` roots.

## Historical Material

- [Archive](./Archive/README.md): domain-scoped historical docs preserved
  outside the current execution path.
- [PersonaKit Archive](./Archive/PersonaKit/README.md): historical PersonaKit
  planning and research material.
- [MCP Archive](./Archive/MCP/README.md): historical MCP planning material.

## How To Read The Current State

- If you want the **current repo-wide priority picture**, start with
  `Docs/Current-State.md`.
- `Docs/Current-State.md` is the only authority for what is current right now;
  accepted baselines and planning docs do not override it.
- If you want the **current product direction**, start with `Docs/Orbit/`.
- If you want the **current PersonaKit engine/runtime implementation rules**,
  start with `Docs/PersonaKit/`.
- If you want the **current MCP usage and troubleshooting docs**, start with
  `Docs/MCP/`.
- If you are reading older plan or research artifacts, start in `Docs/Archive/`
  and choose the archive lane by domain.

When adding a new document:

1. Place it in the correct folder.
2. Link it from that folder's `README.md` (or create one).
3. Follow [STYLEGUIDE.md](./STYLEGUIDE.md).
