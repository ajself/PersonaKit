# Interaction Quality Report Template

Use this template for red-pen interaction reviews.

## Required Sections

1. Scope under review
2. Build/version context
3. Flows tested
4. Scorecard by rubric dimension
5. Findings by severity
6. Recommended fixes (ordered)
7. Stop/go recommendation
8. Next checkpoint

## Severity Taxonomy

1. `blocker`: flow-breaking issue that prevents dependable use.
2. `major`: materially harms usability but has workaround.
3. `minor`: polish/readability issue that does not break core flow.

## Findings Contract

Each finding should include:

1. ID (`IQ-###`)
2. Severity
3. Repro steps
4. Expected behavior
5. Observed behavior
6. Proposed fix
7. Owner
8. Disposition (`fix-now`, `accept`, `defer`)

## Stop/Go Rules

1. Any blocker => `stop`.
2. No blockers and score `>= 85` => `go`.
3. No blockers and score `75-84` => `go-with-notes`.
4. Score `< 75` => `stop`.
