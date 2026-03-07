# Persona Hiring Calibration Playbook

Use this essential to calibrate reverse-interview scoring quality across repeated hiring assessments.

## Purpose

1. Reduce scoring drift between assessments and sessions.
2. Improve consistency of verdicts for similar role requirements.
3. Detect false positives and false negatives in hiring judgments.

## Benchmark Case Set

Maintain at least three benchmark candidate profiles:

1. Strong-fit candidate (expected verdict: `qualified`)
2. Mixed-fit candidate (expected verdict: `qualified-with-gaps`)
3. Weak-fit candidate (expected verdict: `not-yet-qualified`)

For each benchmark, include:

1. Role context
2. Expected strengths
3. Expected high/medium/low gaps
4. Expected confidence range
5. Expected recommended first step

## Calibration Pass

1. Run reverse interview on all benchmark cases.
2. Compare actual output to expected output.
3. Measure drift:
   - verdict mismatch
   - confidence delta > 10 points
   - missing high-severity gaps
4. Record calibration findings and proposed rubric adjustments.

## Pass/Fail Rule

Calibration pass is considered healthy when:

1. All benchmark verdicts match expected categories.
2. Confidence deltas stay within 10 points.
3. No high-severity expected gap is missed.

If any rule fails:

1. Mark calibration as failed.
2. Propose bounded rubric or workflow adjustments.
3. Re-run benchmarks after approved updates.

## Output Requirements

Each calibration pass should produce:

1. Benchmark matrix (expected vs actual).
2. Drift summary.
3. Proposed adjustments (if any).
4. Follow-up action owner and next run trigger.
