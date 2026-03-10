# Session Stack Review Rubric

Use this essential when Samwise is reviewing a PersonaKit session and the
artifacts that define or expose its behavior.

## Purpose

1. Make session reviews deterministic and comparable across passes.
2. Force the review to trace the session through its directive, intent,
   essentials, and exposed operator docs.
3. Separate current confidence from post-red-pen projected confidence.
4. Keep session review outputs compact, explicit, and ready for AJ follow-up.

## Required Review Order

Review artifacts in this order:

1. target session
2. target directive
3. required intents
4. included essentials most responsible for behavior
5. exposed operator docs and session-directory references
6. continuity and maintenance records when the session is new or materially
   changed

Do not skip directly to prose conclusions without tracing the defining files.

## Required Output Shape

Each review should include:

1. a short goal restatement
2. ordered findings with severity and file references
3. one SWOT per reviewed artifact:
   - Strengths
   - Weaknesses
   - Opportunities
   - Threats
4. a current confidence score for deliverable expectations per artifact
5. a red-pen section describing the smallest fixes that would raise confidence
6. a second confidence score pass after red-pen assumptions
7. one summary table covering:
   - artifact
   - current confidence
   - projected confidence
   - highest-risk note
8. one short concluding paragraph

## Confidence Rules

Use a `0.0-10.0` scale.

Interpret the score as:

1. `0.0-3.9`
   not credible for the promised deliverable
2. `4.0-5.9`
   partially credible but structurally weak
3. `6.0-7.9`
   credible with meaningful gaps
4. `8.0-9.4`
   strong and likely to hold in real use
5. `9.5-10.0`
   highly reliable with only minor residual risk

Score what the artifact is likely to produce in practice, not how good the
intent sounds.

## Red-Pen Discipline

For the red-pen pass:

1. identify the smallest changes that most improve enforcement or clarity
2. prefer hardening machine-readable contracts over adding more prose
3. call out lifecycle-state mismatches when a default workflow depends on a
   `candidate` session
4. call out operator-surprise risks when important warnings only live in
   secondary docs
5. rerun confidence after the proposed fixes, not after imagined unrelated
   improvements

## Non-Goals

- Do not rewrite the target stack during the review itself unless AJ explicitly
  requests implementation.
- Do not hide uncertainty by averaging away major weaknesses.
- Do not treat a vivid session description as proof that the workflow is
  enforceable.
