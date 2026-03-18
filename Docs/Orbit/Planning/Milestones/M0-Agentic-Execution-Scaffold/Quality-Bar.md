# M0 Quality Bar

Status: Draft
Milestone: `M0`
Primary Owner: `samwise`
Last Updated: 2026-03-18

## Purpose

Define what counts as impressive, review-worthy completion for `M0`.

The purpose of `M0` is not to produce paperwork.
The purpose of `M0` is to remove ambiguity that would otherwise cause later AI
lanes to drift, rush, or silently broaden scope.

## Non-Negotiable Standard

`M0` is reached only when later milestones can start from a stable execution
scaffold and produce disciplined, reviewable work.

The milestone is not reached if the outputs are merely present.
They must also be:

- precise
- reusable
- reviewable
- deterministic
- aligned with PersonaKit guardrails

## Quality Attributes

### 1. Role Clarity

High bar:

- every milestone has one named execution persona
- every milestone has a visible review ring
- no lane depends on blended active personas

Failure signs:

- "whoever is available" language
- execution owner not named
- review owner implied but not explicit

Evidence:

- `Persona-Coverage-Matrix.md`

### 2. Persona Fidelity

High bar:

- each assigned persona fits the milestone's actual job
- missing personas are named explicitly instead of papered over
- later delegated lanes do not rely on speculative identities

Failure signs:

- forcing an existing persona into a role it does not actually cover
- creating placeholder labels with no approval path
- pretending `ProdDoc` is settled when it is not

Evidence:

- `Persona-Coverage-Matrix.md`
- `Decision-Register.md`

### 3. Handoff Determinism

High bar:

- every delegated lane starts from one bounded packet shape
- inputs, write scope, review gates, and failure dispositions are explicit
- the packet can be reused without needing thread reconstruction

Failure signs:

- free-form delegation prompts
- unclear write boundaries
- no explicit blocked state or review stop

Evidence:

- `Delegated-Handoff-Packet-Template.md`

### 4. Reviewability And Stop-Point Discipline

High bar:

- major decisions have explicit AJ review gates
- missing personas block later delegation instead of being hand-waved
- the scaffold makes it obvious when to stop rather than improvise

Failure signs:

- later milestones are allowed to begin on unresolved identity questions
- human review is implied but not attached to an artifact
- stop points are written as soft suggestions instead of hard boundaries

Evidence:

- `Decision-Register.md`
- `Evidence-And-Exit-Criteria.md`

### 5. Reusability

High bar:

- the scaffold works for `M1`, `M2`, and later milestones without being rewritten
- terms are consistent across planning docs
- the dossier structure scales with complexity without growing vague

Failure signs:

- each milestone would need its own invented packet structure
- planning language conflicts across documents
- the scaffold works only for one narrow case

Evidence:

- `README.md`
- `Delegated-Handoff-Packet-Template.md`

### 6. Constraint Fidelity

High bar:

- the scaffold reinforces PersonaKit grounding before delegation
- skill authorization and stop points remain first-class constraints
- no artifact quietly authorizes broader execution than the repo allows

Failure signs:

- cached context treated as equivalent to live grounding for open-ended work
- missing mention of unauthorized or blocked states
- later lanes appear allowed to improvise plans outside the directive stack

Evidence:

- `Delegated-Handoff-Packet-Template.md`
- `Evidence-And-Exit-Criteria.md`

### 7. Decision Closure

High bar:

- high-impact questions are turned into named decisions with clear criteria
- each unresolved item has a consequence if delayed
- recommended defaults are visible without pretending AJ approval already exists

Failure signs:

- decision notes that only restate the question
- no criteria for resolving collaborator identity or missing personas
- delay impact hidden or ignored

Evidence:

- `Decision-Register.md`

## Disqualifying Shortcuts

Any of these mean `M0` is not complete:

- later milestones still require blended or unnamed execution identities
- delegated lanes still need thread memory to know what to do
- the `ProdDoc` question is left ambiguous while `M1` and `M2` proceed as if it
  were settled
- missing personas are neither approved for creation nor explicitly staged as
  prerequisites
- stop points are absent from the handoff standard

## What "Impressive" Looks Like

`M0` should make the next milestone feel calmer and sharper.

An impressive `M0` result means:

- a new lane can be grounded quickly
- the lane knows exactly what it may change
- the lane knows exactly how quality will be judged
- the lane knows when to stop for review
- later milestone plans look more disciplined because `M0` removed ambiguity

If the result only says "here is a plan," it is not enough.
If the result lets a later agent execute with precision and restraint, it is.
