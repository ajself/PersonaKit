# Development Guide

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-08

## Purpose

Provide the durable development operating model for this repository: workflow
agreements, session routing, ongoing logs, and validation commands.

## Team operating agreement

- [Collaboration Charter](./Collaboration-Charter.md)
- [Worktree Squad Cheat Sheet](./worktree-squad-cheat-sheet.md)
- [Session Directory](./session-directory.md)
- [Session Lifecycle States](./session-lifecycle-states.md)
- [Closeout Checklist](./closeout-checklist.md)

## Operational Records

- [Partner Context Log](./partner-context-log.md)
- [Partner Handoff Register](./partner-handoff-register.md)
- [Pack Gardener Log](./pack-gardener-log.md)
- [Git History Gardener Log](./git-history-gardener-log.md)
- [Git History Gardener Proposals](./git-history-gardener-proposals.md)
- [Development Logs](./logs/README.md)
- [Persona Hiring Reviews](./hiring-reviews/README.md)
- [Retrospectives](./retrospectives/README.md)

## Validation Harness

PersonaKit is the authoritative context compiler. This repo uses a small,
deterministic validation harness against the canonical kit in
`Fixtures/kit-root` so contributors can confirm behavior and stability.

The FOSA migration is complete; this guide reflects the post-migration
implementation layout and validation workflow.

## Implementation architecture

The implementation is intentionally small, with clear responsibilities split by
target and file group:

- `PersonaKit` (CLI executable adapter):
  - `Sources/App/CLI/main.swift`
- `PersonaKitStudio` (Studio executable adapter):
  - `Sources/App/Studio/PersonaKitStudioApp.swift`
- `ContextCLI` (CLI command definitions, scope/session option parsing, error
  reporting):
  - `Sources/Features/CLI/`
- `ContextMCP` (MCP server resources, prompts, tools, runner):
  - `Sources/Features/MCP/`
- `ContextCore` (core compiler/pipeline primitives, validator/registry/resolver,
  exporter/graph, locators, and schema resources):
  - `Sources/Shared/ContextCore/`
- `ContextWorkspaceCore` (workspace snapshot/build/validation models and
  workspace-specific policies used by Studio):
  - `Sources/Shared/ContextWorkspaceCore/`
- `StudioFoundation` and `StudioFeatures` (Studio app foundation and UI):
  - `Sources/Features/Studio/Foundation/`
  - `Sources/Features/Studio/UI/`
- Schema resources:
  - `Sources/Shared/ContextCore/Schemas/*.json`, loaded via package resources
    and used by `SchemaValidator.swift`, exposed to workspace modules through
    `SchemaValidationBridge.swift`.

Data flow is:
1. CLI or MCP receives the request.
2. Scopes are resolved (`project`, `global`, or explicit `--root`).
3. Validator checks pack files and schema conformance.
4. Registry loads entities by id from `Packs/`.
5. Resolver assembles the resolved session from Persona + Directive + Kits.
6. Export/Graph rendering emits deterministic output.

## Worktree-first execution model

Run development validation from a dedicated git worktree.

1. Keep one active lane or task per worktree.
2. Run all commands from that worktree root.
3. For parallel runs, use a unique agent/lane temp root per worktree:
   - `PERSONAKIT_VALIDATE_TMP_ROOT=/tmp/personakit-$USER-<agent>`

## Local-only branch closeout

When a lane is complete and this repo is being used without remote PR
coordination, use one command to close out safely:

- `make closeout-local`

Run [Closeout Checklist](./closeout-checklist.md) before closeout so pack/session
maintenance and logging are not skipped.

Behavior:

1. Requires a clean feature worktree.
2. Rebases the feature branch onto local `main` (no fetch).
3. Fast-forward merges into local `main`.
4. Verifies the feature branch is an ancestor of `main`.
5. Removes the feature worktree and deletes the feature branch.

Optional variables:

- `CLOSEOUT_BRANCH=<branch>` to target a specific branch.
- `CLOSEOUT_WORKTREE=<path>` to target a specific worktree path.
- `CLOSEOUT_MAIN=<branch>` to use a main branch other than `main`.
- `CLOSEOUT_NO_CLEANUP=1` to keep branch/worktree after merge.

## Standard workflow (manual)

Run these steps from the repo root:

1. `make format-check`
2. `swift test`
3. `swift run personakit validate --root Fixtures/kit-root`
4. `swift run personakit export --root Fixtures/kit-root --persona senior-swiftui-engineer --directive apply-style > /tmp/personakit-validate/export-1.md`
5. `swift run personakit export --root Fixtures/kit-root --persona senior-swiftui-engineer --directive apply-style > /tmp/personakit-validate/export-2.md`
6. `cmp -s /tmp/personakit-validate/export-1.md /tmp/personakit-validate/export-2.md`
7. `swift run personakit graph --root Fixtures/kit-root --persona senior-swiftui-engineer --directive apply-style > /tmp/personakit-validate/graph-1.txt`
8. `swift run personakit graph --root Fixtures/kit-root --persona senior-swiftui-engineer --directive apply-style > /tmp/personakit-validate/graph-2.txt`
9. `cmp -s /tmp/personakit-validate/graph-1.txt /tmp/personakit-validate/graph-2.txt`

If either `cmp` fails, the output is not deterministic and should be
investigated before proceeding.

## Scripted workflow

`Scripts/validate-repo.sh` runs the same steps and handles output comparison.
It uses `"$PERSONAKIT_VALIDATE_TMP_ROOT/personakit-validate"` for outputs when
that variable is set. Otherwise it falls back to `"$TMPDIR/personakit-validate"`
and then `/tmp/personakit-validate`. Set a unique temp root per lane or agent
to avoid collisions in parallel execution. Output remains deterministic (no
timestamps).

Run it from the repo root:

1. Direct script form:
   - `PERSONAKIT_VALIDATE_TMP_ROOT=/tmp/personakit-$USER-lane-d Scripts/validate-repo.sh`
2. Makefile wrapper:
   - `make validate-repo VALIDATE_AGENT=lane-d`

## Before and after changes

1. Before you start: run `make validate-repo VALIDATE_AGENT=<agent>` to confirm
   baseline behavior in your worktree.
2. After your changes: run it again with the same `VALIDATE_AGENT` to ensure no
   determinism issues were introduced.
