# Development Guide

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-10

## Purpose

Provide the durable development operating model for this repository: workflow
agreements, session routing, ongoing logs, and validation commands.

Samwise is the `samwise` persona and serves as AJ's Trusted Partner. Use
`Trusted Partner` in human-facing documentation and `AJ Trusted Partner` when a
stable agent-facing role label is helpful.

## Team operating agreement

- [Collaboration Charter](./Collaboration-Charter.md)
- [Worktree Squad Cheat Sheet](./worktree-squad-cheat-sheet.md)
- [Worktree Lane Approvals](./worktree-lane-approvals.md)
- [Session Directory](./session-directory.md)
- [Workstream Directory](./workstream-directory.md)
- [Session Lifecycle States](./session-lifecycle-states.md)
- [Closeout Checklist](./closeout-checklist.md)

## Operational Records

- [Partner Context Log](./partner-context-log.md) (generated from canonical JSONL)
- [Partner Handoff Register](./partner-handoff-register.md) (generated from canonical JSONL)
- [Pack Gardener Log](./pack-gardener-log.md) (generated from canonical JSONL)
- [Historical Artifact Tombstones](./historical-artifact-tombstones.md)
- [Git History Gardener Log](./git-history-gardener-log.md) (generated from canonical JSONL)
- [Git History Gardener Proposals](./git-history-gardener-proposals.md) (generated from canonical JSONL)
- [Development Logs](./logs/README.md)
- [Persona Hiring Reviews](./hiring-reviews/README.md)
- [Retrospectives](./retrospectives/README.md)

Canonical operational ledgers live under [Development Logs](./logs/README.md).
The markdown pages above are operator-readable projections, not the source of
truth.

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

## Lane-first execution model

Treat the approved lane contract as the durable identity of the work, then
materialize a dedicated worktree only when live execution begins.

1. The manifest-approved branch name is the lane identity.
2. A worktree is the local execution surface for that lane, not the lane
   itself.
3. Startup and contract-freeze work may happen read-only from the repo root.
4. Before live execution begins, verify the lane contract from the repo root:
   - `Scripts/check-worktree-lane.sh --mode contract --branch <branch>`
5. When kickoff is approved, materialize the execution worktree from the lane
   contract:
   - `Scripts/materialize-worktree-lane.sh --branch <branch> --path /absolute/path/to/worktree`
6. Keep one active lane or task per worktree.
7. Run execution commands from that worktree root once the lane is materialized.
8. For parallel runs, use a unique agent/lane temp root per worktree:
   - `PERSONAKIT_VALIDATE_TMP_ROOT=/tmp/personakit-$USER-<agent>`
9. Before relying on standing worktree authority inside the materialized lane,
   confirm the lane preflight:
   - `Scripts/check-worktree-lane.sh`
10. Validate the lane manifest itself after approval-record edits:
   - `Scripts/check-worktree-lane-approvals.sh`
11. At milestone closeout, use the retrospective contract rather than an
    informal wrap-up:
   - default to the hybrid retrospective flow when persona fidelity, process
     quality, or product-bearing review is part of the checkpoint

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
3. `swift run personakit workstream-docs --root .personakit --check`
4. `swift run personakit log-docs --root .personakit --check`
5. `Scripts/check-operational-records.sh`
6. `swift run personakit validate --root Fixtures/kit-root`
7. `swift run personakit export --root Fixtures/kit-root --persona senior-swiftui-engineer --directive apply-style > /tmp/personakit-validate/export-1.md`
8. `swift run personakit export --root Fixtures/kit-root --persona senior-swiftui-engineer --directive apply-style > /tmp/personakit-validate/export-2.md`
9. `cmp -s /tmp/personakit-validate/export-1.md /tmp/personakit-validate/export-2.md`
10. `swift run personakit graph --root Fixtures/kit-root --persona senior-swiftui-engineer --directive apply-style > /tmp/personakit-validate/graph-1.txt`
11. `swift run personakit graph --root Fixtures/kit-root --persona senior-swiftui-engineer --directive apply-style > /tmp/personakit-validate/graph-2.txt`
12. `cmp -s /tmp/personakit-validate/graph-1.txt /tmp/personakit-validate/graph-2.txt`

If either `cmp` fails, the output is not deterministic and should be
investigated before proceeding.

## Scripted workflow

`Scripts/validate-repo.sh` runs the same steps and handles output comparison.
It also enforces that the committed workstream operator docs are in sync with
directive-owned workstream metadata. It uses
`"$PERSONAKIT_VALIDATE_TMP_ROOT/personakit-validate"` for outputs when that
variable is set. Otherwise it falls back to
`"$TMPDIR/personakit-validate"` and then `/tmp/personakit-validate`. Set a
unique temp root per lane or agent to avoid collisions in parallel execution.
Output remains deterministic (no timestamps).

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
