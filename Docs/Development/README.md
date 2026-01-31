# Development Validation Harness

PersonaKit is the authoritative context compiler. This repo uses a small,
deterministic validation harness against the canonical kit in
`Fixtures/kit-root` so contributors can confirm behavior and stability.

## Standard workflow (manual)

Run these steps from the repo root:

1. `swift test`
2. `swift run personakit validate --root Fixtures/kit-root`
3. `swift run personakit export --root Fixtures/kit-root --persona senior-swiftui-engineer --task apply-style > /tmp/personakit-validate/export-1.md`
4. `swift run personakit export --root Fixtures/kit-root --persona senior-swiftui-engineer --task apply-style > /tmp/personakit-validate/export-2.md`
5. `cmp -s /tmp/personakit-validate/export-1.md /tmp/personakit-validate/export-2.md`
6. `swift run personakit graph --root Fixtures/kit-root --persona senior-swiftui-engineer --task apply-style > /tmp/personakit-validate/graph-1.txt`
7. `swift run personakit graph --root Fixtures/kit-root --persona senior-swiftui-engineer --task apply-style > /tmp/personakit-validate/graph-2.txt`
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
