# Development Validation Harness

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
- `ContextCore` (validator, registry, resolver, exporter, graph, locators, and
  shared helpers):
  - `Sources/Shared/ContextCore/`
- `StudioFoundation` and `StudioFeatures` (Studio app foundation and UI):
  - `Sources/Features/Studio/Foundation/`
  - `Sources/Features/Studio/UI/`
- `PersonaKitCore` (transitional compatibility library):
  - `Sources/PersonaKit/ContextCoreReexports.swift`
- Schema resources:
  - `Sources/Shared/ContextCore/Schemas/*.json`, loaded via package resources
    and used by `SchemaValidator.swift` during validation.

Data flow is:
1. CLI or MCP receives the request.
2. Scopes are resolved (`project`, `global`, or explicit `--root`).
3. Validator checks pack files and schema conformance.
4. Registry loads entities by id from `Packs/`.
5. Resolver assembles the resolved session from Persona + Directive + Kits.
6. Export/Graph rendering emits deterministic output.

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
It uses a fixed temp path (`/tmp/personakit-validate`) and does not emit any
timestamps.

Run it from the repo root:

`Scripts/validate-repo.sh`

## Before and after changes

1. Before you start: run `Scripts/validate-repo.sh` to confirm the baseline.
2. After your changes: run it again to ensure no regressions and no
   determinism issues were introduced.
