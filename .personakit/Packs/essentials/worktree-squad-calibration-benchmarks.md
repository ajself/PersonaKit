# Worktree Squad Calibration Benchmarks

Use this essential to calibrate Worktree Squad Lead quality across repeated
delivery loops.

## Purpose

1. Keep loop quality and review quality stable over time.
2. Detect false positives (declared success with hidden blockers).
3. Detect false negatives (declared failure when gate evidence is sufficient).

## Benchmark Cases

Maintain these baseline cases:

1. Strong-fit case:
   - expected verdict: `qualified`
   - expected confidence range: `85-95`
2. Mixed-fit case:
   - expected verdict: `qualified-with-gaps`
   - expected confidence range: `70-84`
3. Weak-fit case:
   - expected verdict: `not-yet-qualified`
   - expected confidence range: `40-65`

## Required Signals Per Case

1. Scope/authorization policy enforcement quality.
2. Gate evidence completeness.
3. Staff-level review severity quality.
4. Handoff clarity and next-action quality.
5. Retrospective quality and improvement specificity.

## Drift Rules

Calibration is considered drifted when any occur:

1. Verdict mismatch against expected case class.
2. Confidence delta greater than `10`.
3. Missing blocker finding in a known-blocker case.
4. Recommendation/action items that are not concrete enough to execute.

## Pass Rule

Calibration pass is healthy when:

1. All three benchmark verdicts match expected class.
2. All confidence deltas are within `10`.
3. No expected blocker is missed.
4. Retrospective recommendations include owner and next checkpoint.

## Output

Each calibration pass should produce:

1. A benchmark matrix (expected vs actual).
2. Drift summary with severity.
3. Concrete artifact updates needed for next pass.
