# AppOpsCLI

AppOpsCLI is a **local, manual tool** that captures performance metrics for key
PersonaKit workflows (reload, compose, diff, import, export) and build-run
metrics for xcodebuild and SwiftPM runs. It runs entirely offline and writes
deterministic reports to disk.

## Run it

```bash
Scripts/appops
```

Or directly:

```bash
swift run AppOpsCLI -- [options]
```

## Options

- `--out-dir <path>`: output directory (default: `Artifacts/`)
- `--import-source <path>`: pack file or folder to import (default: `Examples/personakit.pack.json`)
- `--diff-left <path>`: left pack file for diff (default: built-in pack)
- `--diff-right <path>`: right pack file for diff (default: `Examples/personakit.pack.json`)
- `--no-user-packs`: skip loading user packs from `~/Library/Application Support/PersonaKit/Packs`
- `--build-sha <sha>`: git SHA to run build metrics against (default: current working tree)
- `--build-workspace <name>`: Xcode workspace override (default: auto-detect)
- `--build-scheme <name>`: Xcode scheme (default: `PersonaKitApp`)
- `--build-configuration <name>`: build configuration (default: `Release`)
- `--build-config <path>`: JSON config for app build recipes (default: `Scripts/build-run.json` if present)
- `--build-allow-test-failures`: record test failures without aborting the run
- `--build-no-tests`: skip `swift test` during build run
- `--build-no-incremental`: skip incremental builds during build run
- `--build-keep-worktrees`: keep worktree after build run
- `--build-worktree-root <path>`: worktree path override (default: `<appops-output>/build-run/worktree`)
- `--no-build-run`: skip build run
- `--log-level <level>`: log level (`trace|debug|info|notice|warning|error|critical`, default: `info`)
- `--help`: show usage

Build run targets the current working tree unless `--build-sha` is provided.

## Output layout

```
Artifacts/
  appops-<timestamp>/
    REPORT.md
    report.json
    import/
    export/
    build-run/
      logs/
        run/
      derived-data/
        run/
      worktree/
```

The worktree directory is created only when `--build-sha` is provided.

`REPORT.md` is the human‑readable summary; `report.json` is the machine‑readable
schema emitted by AppOpsCore. The report includes a Methodology and Interpretation
section that explains how each metric is derived and how to read the numbers.

## Report methodology (per metric)

- Reload pipeline: built-in packs are loaded from PersonaKitResources, user packs
  are loaded from the user packs root when enabled, then packs are merged and
  resolved. Total reload time is the sum of built-in load, user-pack load (if
  enabled), merge, and resolve.
- Compose: for each resolved persona, AppOps renders a prompt and pretty JSON
  using sample section values and counts UTF-8 bytes. This is a synthetic
  workload for sizing, not actual user content.
- Diff: left/right pack files are loaded and compared by persona content hash to
  produce added/removed/modified counts.
- Import: planning scans the selected file or folder; copy writes to a temp
  directory and then moves into the final destination.
- Export: the first available pack set is encoded to sorted-key JSON and written
  to disk; bytes represent the written file size.
- Diagnostics: counts reflect diagnostics emitted during load, merge, and resolve.
- Build run: runs xcodebuild + swift build/test for a single revision or working
  tree and captures timing, warning counts, and binary sizes.
- Timing: all durations use a monotonic clock around each step; report formatting
  is not timed.

## Interpreting results

- Runs on the same machine and similar cache state; these are local
  indicators, not normalized benchmarks.
- Near-zero timings reflect very small work or measurement granularity.
- Use persona counts and byte sizes to contextualize duration changes.
- Build run metrics are sensitive to derived data and cache state.

## Notes

- This tool is for internal measurement only.
- It does not ship with the app or user‑facing CLI.
- Keep output under version control **only if you intend to**, as it is ignored by default.
