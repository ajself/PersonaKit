# Session Stack Review Rubric

Use this essential when Samwise is reviewing a PersonaKit session and the
artifacts that define or expose its behavior.

## Purpose

1. Make session reviews deterministic and comparable across passes.
2. Force the review to resolve and trace the session through PersonaKit MCP
   before secondary reading begins.
3. Force the review to trace the session through its directive, intent,
   essentials, and exposed operator docs once the target is normalized.
4. Separate current confidence from post-red-pen projected confidence.
5. Keep session review outputs compact, explicit, durable, and ready for AJ
   follow-up.

## MCP-First Rule

For PersonaKit session reviews:

1. PersonaKit MCP is the primary source of truth for understanding and planning.
2. Resolve `targetSessionRef` through PersonaKit MCP before attempting the
   review.
3. Use PersonaKit MCP for:
   - session-reference normalization
   - session trace/graph inspection
   - entity explanation
   - resolved session export context
4. Raw file reads are allowed only:
   - after MCP has already resolved the target graph, or
   - when AJ explicitly approved implementation work after the review
5. If MCP is unavailable or missing required capability, fail closed and write
   an MCP-gap artifact instead of pretending confidence was earned.

## Required Review Order

Review artifacts in this order:

1. normalize `targetSessionRef` to one canonical session id
2. target session
3. target directive
4. required intents
5. included essentials most responsible for behavior
6. exposed operator docs and session-directory references
7. continuity and maintenance records when the session is new or materially
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
4. fixed risk-dimension scores for each reviewed artifact:
   - contract clarity
   - enforcement strength
   - drift resistance
   - hallucination risk
   - persona/identity collision risk
   - operator surprise risk
   - reviewability
   - MCP dependency health
5. a current confidence score for deliverable expectations per artifact
6. a red-pen section describing the smallest fixes that would raise confidence
7. a second confidence score pass after red-pen assumptions
8. one summary table covering:
   - artifact
   - current confidence
   - projected confidence
   - highest-risk note
9. one short concluding paragraph
10. one explicit verdict:
    - `safe`
    - `caution`
    - `unsafe`
    - `blocked`

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

Default verdict thresholds:

1. `8.5+`
   `safe`
2. `6.5-8.4`
   `caution`
3. `<6.5`
   `unsafe`
4. MCP unavailable or capability gap blocks the review
   `blocked`

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
5. call out MCP dependency gaps before suggesting any manual workaround
6. rerun confidence after the proposed fixes, not after imagined unrelated
   improvements

## Non-Goals

- Do not rewrite the target stack during the review itself unless AJ explicitly
  requests implementation.
- Do not hide uncertainty by averaging away major weaknesses.
- Do not treat a vivid session description as proof that the workflow is
  enforceable.
- Do not silently fall back to manual graph reconstruction when MCP is the
  missing dependency.
