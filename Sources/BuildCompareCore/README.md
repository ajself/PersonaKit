# BuildCompareCore

BuildCompareCore is the shared, pure Swift module that defines the build-compare
report schema and helper utilities. It has no file or process side effects and is
used by the CLI to encode results and format markdown summaries.

## Contents

- Report data models: `Report`, `RunMetadata`, `RevisionMetrics`, `BuildStepMetrics`,
  and related metric types.
- Helpers for parsing warnings, extracting xcodebuild timing summaries, and
  generating markdown reports.

## Typical usage

- BuildCompareCLI gathers metrics and encodes a `Report` to JSON.
- Other tools can decode `report.json` using these models to analyze results.

Example decode flow:

```
let data = try Data(contentsOf: reportURL)
let report = try JSONDecoder().decode(Report.self, from: data)
```
