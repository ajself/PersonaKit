# Session Stack Review Rubric

Use this runtime rubric when reviewing a PersonaKit session and the artifacts that define its behavior.
For the full review walkthrough, see `session-stack-review-rubric-reference`.

## Required Order

1. Normalize the target session reference.
2. Review the target session.
3. Review the target directive and required intents.
4. Review the essentials most responsible for behavior.
5. Review exposed operator docs and continuity records only after the stack is traced.

## Output Contract

Each review should include:

1. Goal restatement.
2. Ordered findings with severity and file references.
3. One SWOT per reviewed artifact.
4. Current confidence and projected post-red-pen confidence.
5. Bounded next steps.

## Guardrails

1. Prefer PersonaKit MCP for session normalization and trace when available.
2. Do not skip directly to prose conclusions without tracing the defining files.
3. Keep findings explicit, comparable, and ready for AJ follow-up.
