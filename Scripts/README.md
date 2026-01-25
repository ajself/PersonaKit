# Scripts

This folder contains development-only tools. `build-compare` is backed by a SwiftPM executable target and is not shipped with the app or user-facing CLI.

## build-compare

Compare build performance and outputs between two git SHAs for the app and CLI.

### Requirements

- Xcode installed and `xcodebuild` available on PATH
- Swift toolchain available on PATH
- Repo has `PersonaKit.xcworkspace` and `PersonaKitApp` scheme

### Usage

```bash
Scripts/build-compare <base_sha> <head_sha> [options]
```

This script is a thin wrapper around the SwiftPM executable:

```bash
swift run BuildCompareCLI -- <base_sha> <head_sha> [options]
```

Options:
- `--out <path>`: output directory (default: `/tmp/personakit-build-compare/<timestamp>`)
- `--worktree-root <path>`: worktree root (default: `<out>/worktrees`)
- `--scheme <name>`: Xcode scheme (default: `PersonaKitApp`)
- `--configuration <name>`: build configuration (default: `Release`)
- `--config <path>`: JSON config for app build recipes (default: `Scripts/build-compare.json` if present)
- `--allow-test-failures`: record failing tests in the report instead of aborting
- `--no-tests`: skip `swift test`
- `--no-incremental`: skip incremental builds
- `--keep-worktrees`: keep worktrees after run

### What it measures

App (xcodebuild):
- Clean build time
- Incremental build time
- Build timing summary (per phase)
- Warnings count
- App binary size (bundle size if `.app` exists, otherwise executable size)

CLI (swift build):
- Clean build time
- Incremental build time
- Warnings count
- Binary sizes (`personakit`, `personakit-validate`)

Tests (swift test):
- Total test time
- Warnings count
- Success/failure

### Output layout

```
<out>/
  REPORT.md
  report.json
  logs/
    base/
    head/
  derived-data/
    base/
    head/
  worktrees/
    base/
    head/
```

`REPORT.md` is a human-readable summary. `report.json` is the machine-readable report.

### App build recipes (legacy support)

The tool can try multiple app build recipes to accommodate older SHAs. Recipes are read from
`Scripts/build-compare.json` if present (or via `--config`). Each recipe can optionally target
specific workspaces and override schemes or add extra xcodebuild arguments.

Example:

```json
{
  "schema_version": 1,
  "app_recipes": [
    { "name": "default", "workspace": null, "scheme": null, "xcodebuild_args": [] },
    {
      "name": "legacy-driver",
      "workspace": "PersonaPad.xcworkspace",
      "scheme": "PersonaPadApp",
      "xcodebuild_args": ["SWIFT_USE_INTEGRATED_DRIVER=NO"]
    }
  ]
}
```

The first recipe that succeeds is recorded in the report.

### JSON schema (stable keys)

The JSON report is intended to be stable across runs for automated comparison. Top-level keys:

- `schema_version` (Int, current: 2)
- `run` (metadata)
- `base` (metrics for base SHA)
- `head` (metrics for head SHA)

Key naming is snake_case. Times are in seconds. Sizes are bytes.

`app.build_recipe` records the recipe used for the app build.

### Notes

- Builds are sensitive to the local environment and cache state.
- Worktrees are removed by default unless `--keep-worktrees` is provided.

## appops

Collect local performance metrics for core app flows (reload, compose, diff, import, export).
This script is backed by a SwiftPM executable target and is not shipped with the app or user-facing CLI.

### Usage

```bash
Scripts/appops [options]
```

This script is a thin wrapper around the SwiftPM executable:

```bash
swift run AppOpsCLI -- [options]
```

Options:
- `--out-dir <path>`: output directory (default: `Artifacts/`)
- `--import-source <path>`: pack file or folder to import (default: `Examples/personakit.pack.json`)
- `--diff-left <path>`: left pack file for diff (default: built-in pack)
- `--diff-right <path>`: right pack file for diff (default: `Examples/personakit.pack.json`)
- `--no-user-packs`: skip loading user packs from `~/Library/Application Support/PersonaKit/Packs`

### Output layout

```
Artifacts/
  appops-<timestamp>/
    REPORT.md
    report.json
    import/
    export/
```

`REPORT.md` is a human-readable summary. `report.json` is the machine-readable report.
