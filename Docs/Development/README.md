# Development Validation Harness

PersonaKit is the authoritative context compiler. This repo uses a small,
deterministic validation harness against the canonical kit in
`Fixtures/kit-root` so contributors can confirm behavior and stability.

## Implementation architecture

The implementation is intentionally small, with clear responsibilities split by
file group under `Sources/PersonaKit/`:

- CLI surface:
  - `main.swift`
  - `CLI.swift` (command definitions, scope/session option parsing, error
    reporting)
- Core context pipeline:
  - `Validator.swift`
  - `Registry.swift`
  - `Resolver.swift`
  - `Exporter.swift`
  - `GraphPrinter.swift`
- MCP server surface:
  - `MCPServerRunner.swift`
  - `MCPResources.swift`
  - `MCPPrompts.swift`
  - `MCPTools.swift`
- Schema resources:
  - `Schemas/*.json`, loaded via package resources and used by
    `SchemaValidator.swift` during validation.

Data flow is:
1. CLI or MCP receives the request.
2. Scopes are resolved (`project`, `global`, or explicit `--root`).
3. Validator checks pack files and schema conformance.
4. Registry loads entities by id from `Packs/`.
5. Resolver assembles the resolved session from Persona + Directive + Kits.
6. Export/Graph rendering emits deterministic output.

## Standard workflow (manual)

Run these steps from the repo root:

1. `swift test`
2. `swift run personakit validate --root Fixtures/kit-root`
3. `swift run personakit export --root Fixtures/kit-root --persona senior-swiftui-engineer --directive apply-style > /tmp/personakit-validate/export-1.md`
4. `swift run personakit export --root Fixtures/kit-root --persona senior-swiftui-engineer --directive apply-style > /tmp/personakit-validate/export-2.md`
5. `cmp -s /tmp/personakit-validate/export-1.md /tmp/personakit-validate/export-2.md`
6. `swift run personakit graph --root Fixtures/kit-root --persona senior-swiftui-engineer --directive apply-style > /tmp/personakit-validate/graph-1.txt`
7. `swift run personakit graph --root Fixtures/kit-root --persona senior-swiftui-engineer --directive apply-style > /tmp/personakit-validate/graph-2.txt`
8. `cmp -s /tmp/personakit-validate/graph-1.txt /tmp/personakit-validate/graph-2.txt`

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
