# Codex Session Notes

Goal: resolve all SwiftLint violations in small, reversible steps with frequent commits.

## Step 0 — Baseline audit (no code changes)
- Run `swiftlint --reporter json` and summarize counts by rule and by file.
- Identify rules that appear to conflict with `swift-format` output.
- Identify schema/JSON model files that intentionally use snake_case keys.
- Commit: `chore(lint): capture baseline lint audit` (notes-only change if needed).
- Ask for approval to proceed to Step 1.

## Step 1 — Tooling alignment
- If rules conflict with `swift-format`, update `.swiftlint.yml` to align.
- Update `Docs/Standards/SwiftUI-App-Style-Guide.md` to match any config changes.
- Keep changes minimal and explain rationale in the commit message/body.
- Commit: `chore(lint): align swiftlint with formatter`.
- Ask for approval to proceed to Step 2.

## Step 2 — Schema/model naming consistency
- For schema/JSON-facing models, choose one approach:
  - Option A: convert to camelCase + `CodingKeys`.
  - Option B: add file-level `swiftlint:disable identifier_name` with a brief justification comment.
- Apply consistently to all schema/report model files.
- Commit: `refactor(schema): normalize lint strategy for encoded keys`.
- Ask for approval to proceed to Step 3.

## Step 3 — Structural violations (size/length)
- Refactor files with `function_body_length`, `type_body_length`, and `file_length` issues.
- Extract helpers or split into new files; keep behavior unchanged.
- Tackle one file per commit when possible.
- Commit pattern: `refactor(lint): split <file>` or `refactor(lint): extract helpers from <type>`.
- Ask for approval to proceed to Step 4.

## Step 4 — Line length cleanup
- Address remaining `line_length` errors/warnings by wrapping lines or extracting variables.
- Prefer readability; avoid semantic changes.
- Commit: `style(lint): wrap long lines`.
- Ask for approval to proceed to Step 5.

## Step 5 — Final pass
- Run `swift-format` on touched files.
- Run full `swiftlint` and confirm zero violations.
- Commit: `chore(lint): final cleanup`.
- Report results and wait for further instructions.
