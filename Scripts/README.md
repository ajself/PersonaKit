# Scripts

This folder contains development-only tools. These scripts are not part of the app or CLI targets.

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

Options:
- `--out <path>`: output directory (default: `/tmp/personakit-build-compare/<timestamp>`)
- `--worktree-root <path>`: worktree root (default: `<out>/worktrees`)
- `--scheme <name>`: Xcode scheme (default: `PersonaKitApp`)
- `--configuration <name>`: build configuration (default: `Release`)
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

### JSON schema (stable keys)

The JSON report is intended to be stable across runs for automated comparison. Top-level keys:

- `schema_version` (Int)
- `run` (metadata)
- `base` (metrics for base SHA)
- `head` (metrics for head SHA)

Key naming is snake_case. Times are in seconds. Sizes are bytes.

### Notes

- Builds are sensitive to the local environment and cache state.
- Worktrees are removed by default unless `--keep-worktrees` is provided.
