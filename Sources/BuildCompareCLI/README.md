# BuildCompareCLI

BuildCompareCLI compares build and test metrics between two git revisions using local
worktrees. It produces a JSON report and a markdown summary that capture build times,
warnings, and binary sizes.

## Quick start

Run from the repo root:

```
Scripts/build-compare <base_sha> <head_sha> [options]
```

The wrapper script runs `swift run BuildCompareCLI --` under the hood and forwards
arguments to the CLI.

## Output

- `REPORT.md` and `report.json` in the output root.
- Logs in `logs/base` and `logs/head`.
- Derived data and worktrees under the output root.

Default output root: `/tmp/personakit-build-compare/<timestamp>`.

## Options

- `--out <path>`: Output directory.
- `--worktree-root <path>`: Worktree root directory.
- `--workspace <name>`: Xcode workspace name.
- `--scheme <name>`: Xcode scheme name.
- `--configuration <name>`: Build configuration (for example, `Release`).
- `--config <path>`: JSON config file for app build recipes.
- `--allow-test-failures`: Record test failures without aborting the run.
- `--no-tests`: Skip `swift test`.
- `--no-incremental`: Skip incremental builds.
- `--keep-worktrees`: Keep worktrees after the run.

## Notes

- Uses `git worktree`, `xcodebuild`, and `swift` from your PATH.
- Results depend on machine state and caches; compare runs on the same machine for
  consistent baselines.
