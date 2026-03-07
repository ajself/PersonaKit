# Venture Product Quality Gate

Use this gate before accepting any discovery, planning, or tracking artifact.

## Gate Checklist

1. Problem clarity: Is the user problem specific and non-generic?
2. Outcome clarity: Is success measurable?
3. Scope control: Are in-scope and out-of-scope explicit?
4. Risk transparency: Are key risks and mitigations documented?
5. Dependency clarity: Are prerequisites and sequencing explicit?
6. Actionability: Is there one concrete next action with owner?

## Gate Result

Classify each artifact:

1. `pass`: ready for decision or handoff.
2. `pass-with-notes`: usable now, minor follow-up needed.
3. `fail`: revise before proceeding.

## Guardrails

- Do not advance a failed artifact to implementation planning.
- Do not mark pass if required sections are missing.
- Record gate result in the planning output.
