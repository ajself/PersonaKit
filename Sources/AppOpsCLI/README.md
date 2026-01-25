# AppOpsCLI

AppOpsCLI is a **local, manual tool** that captures performance metrics for key
PersonaKit workflows (reload, compose, diff, import, export) and build-compare
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
- `--help`: show usage

Build compare runs only when both `--build-base` and `--build-head` are provided;
otherwise the build-compare section is marked as skipped in the report.

## Output layout

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
      derived-data/
        base/
        head/
      worktrees/
        base/
        head/
```

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
- Build compare: runs xcodebuild + swift build/test for base/head SHAs inside git
  worktrees and captures timing, warning counts, and binary sizes.
- Timing: all durations use a monotonic clock around each step; report formatting
  is not timed.

## Interpreting results

- Compare runs on the same machine and similar cache state; these are local
  indicators, not normalized benchmarks.
- Near-zero timings reflect very small work or measurement granularity.
- Use persona counts and byte sizes to contextualize duration changes.
- Build compare metrics are sensitive to derived data and cache state.

## Notes

- This tool is for internal measurement only.
- It does not ship with the app or user‑facing CLI.
- Keep output under version control **only if you intend to**, as it is ignored by default.
