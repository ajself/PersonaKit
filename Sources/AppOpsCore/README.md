# AppOpsCore

AppOpsCore defines the **report schema** and **formatting** for AppOps runs.
It is a lightweight, deterministic model layer used by the AppOps CLI.

## What it contains

- `AppOpsReport` and supporting metric structs
- `AppOpsReportFormatter` for Markdown summaries
- Build-compare report structs and formatter helpers used by AppOpsCLI

## Schema notes

- `schema_version` is currently **2**
- Field names are **snake_case**
- Times are **seconds** (Double)
- Sizes are **bytes**
- The schema is intended to be stable for comparison and automation

## Intended usage

AppOpsCore is not part of the app’s feature set. It exists so internal tooling can:

- emit a consistent JSON report
- render a human‑readable Markdown summary
- stay deterministic and file‑based
