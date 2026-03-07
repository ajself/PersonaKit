# Venture Studio Workspace

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

`VentureStudio` is a sandbox workspace for venture discovery, narrative
experiments, and story-site iterations without polluting core PersonaKit packs
or docs.

## Structure

- `.personakit/`: workspace-scoped personas, kits, directives, and sessions.
- `Docs/`: workspace-scoped business, development, and marketing artifacts.

## Quick Start

Run from the repository root.

1. Validate workspace packs:
   - `swift run personakit validate --root Workspaces/VentureStudio/.personakit`
2. Export daily venture session:
   - `swift run personakit export --root Workspaces/VentureStudio/.personakit --session venture-studio-daily`

## Navigation

- [Workspace Docs](./Docs/)
- [Workspace Session Directory](./Docs/Development/session-directory.md)
- [Planning Management](./Docs/Plan/README.md)

Related docs:

- [Workspaces Index](../README.md)
- [Repository Docs Index](../../Docs/README.md)
