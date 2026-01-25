# Scripts

This folder contains development-only tools. `appops` is backed by a SwiftPM
executable target and is not shipped with the app or user-facing CLI.

## appops

Collect local performance metrics for core app flows (reload, compose, diff,
import, export) and build-compare metrics for xcodebuild/SwiftPM runs.

### Requirements

- Xcode installed and `xcodebuild` available on PATH
- Swift toolchain available on PATH
- Repo has `PersonaKit.xcworkspace` and `PersonaKitApp` scheme

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
- `--build-base <sha>`: base git SHA for build compare (default: skip build compare)
- `--build-head <sha>`: head git SHA for build compare (default: skip build compare)
- `--build-workspace <name>`: Xcode workspace override (default: auto-detect)
- `--build-scheme <name>`: Xcode scheme (default: `PersonaKitApp`)
- `--build-configuration <name>`: build configuration (default: `Release`)
- `--build-config <path>`: JSON config for app build recipes (default: `Scripts/build-compare.json` if present)
- `--build-allow-test-failures`: record test failures without aborting the run
- `--build-no-tests`: skip `swift test` during build compare
- `--build-no-incremental`: skip incremental builds during build compare
- `--build-keep-worktrees`: keep worktrees after build compare
- `--build-worktree-root <path>`: worktree root override (default: `<appops-output>/build-compare/worktrees`)
- `--no-build-compare`: skip build compare even if SHAs are provided

Build compare runs only when both `--build-base` and `--build-head` are provided;
otherwise the build-compare section is marked as skipped in the report.

### Output layout

```
Artifacts/
  appops-<timestamp>/
    REPORT.md
    report.json
    import/
    export/
    build-compare/
      logs/
        base/
        head/
      failures/
      derived-data/
        base/
        head/
      worktrees/
        base/
        head/
```

`REPORT.md` is a human-readable summary. `report.json` is the machine-readable report. When
build or test steps fail, AppOps writes a failure summary with the error output under
`build-compare/failures/` and links to it from the report.

### App build recipes (legacy support)

AppOps can try multiple app build recipes to accommodate older SHAs. Recipes are read from
`Scripts/build-compare.json` if present (or via `--build-config`). Each recipe can optionally target
specific workspaces and override schemes or add extra xcodebuild arguments.

Example:

```json
{
  "schema_version": 1,
  "app_recipes": [
    { "name": "default", "workspace": null, "scheme": null, "xcodebuild_args": [] },
    {
      "name": "legacy-driver",
      "workspace": "PersonaKit.xcworkspace",
      "scheme": "PersonaKitApp",
      "xcodebuild_args": ["SWIFT_USE_INTEGRATED_DRIVER=NO"]
    }
  ]
}
```

The first recipe that succeeds is recorded in the report.

### Notes

- Builds are sensitive to the local environment and cache state.
- Worktrees are removed by default unless `--build-keep-worktrees` is provided.
