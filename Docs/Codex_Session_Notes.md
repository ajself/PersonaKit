# Codex Session Notes — Next Session Plan

## Goals
- Support legacy SHAs by automatically trying multiple app build recipes.
- Preserve deterministic, reusable metrics outputs (JSON + Markdown).
- Keep failures visible without blocking the run when configured.

## Recommendations
- Add `Scripts/build-compare.json` with targeted recipes for legacy workspaces/schemes.
- Treat the report as the source of truth for test pass/fail via `tests.success`.
- Default to `--allow-test-failures` for historical SHAs where tests are known to fail.
- Document any new xcodebuild flags needed for a specific SHA in the config file.

## Known Findings from Current Run
- Base SHA `cb61f8fa5c1fe1736f32417810bb5b8e9e5b8f72` has failing tests.
  - Failure log: `/tmp/personakit-build-compare/2026-01-25T05-59-23Z/logs/base/tests.log`
- Latest run report:
  - `/tmp/personakit-build-compare/2026-01-25T05-59-23Z/REPORT.md`
  - `/tmp/personakit-build-compare/2026-01-25T05-59-23Z/report.json`

## Next Steps
1) Create and commit `Scripts/build-compare.json` with recipes that cover PersonaPad-era builds.
2) Re-run the comparison with `--allow-test-failures` and verify report output.
3) If app builds still fail for a specific SHA, add a targeted recipe and note it in the config.
