# M0 Evidence And Exit Criteria

Status: Draft
Milestone: `M0`
Owner: `samwise`
Last Updated: 2026-03-18

## Purpose

Define the artifacts and review tests required to close `M0` honestly.

## Required Artifacts

`M0` should not close without all of these artifacts existing and being usable:

1. a frozen milestone dossier standard
2. a delegated handoff packet template
3. a milestone-to-persona coverage matrix
4. a decision register covering `ProdDoc` and missing-persona questions
5. a quality bar that explains why thin completion is not enough

## Artifact Quality Tests

### Dossier standard

Passes only if:

- later milestone dossiers all share a common structure
- the structure makes packet order, evidence, and stop points explicit

Fails if:

- the structure is mostly decorative
- later lanes would still need to invent the real planning logic

### Delegated handoff template

Passes only if:

- it forces explicit scope, quality, evidence, and stop points
- it can be reused for both planning-heavy and implementation-heavy lanes

Fails if:

- it reads like a generic prompt shell
- it permits silent scope growth

### Persona coverage matrix

Passes only if:

- it marks blocked milestones honestly
- it distinguishes covered, conditional, and missing persona states

Fails if:

- it marks aspirational roles as if they were approved and ready

### Decision register

Passes only if:

- each unresolved decision has criteria, recommended default, and delay cost
- downstream milestones can tell whether they are blocked by the decision

Fails if:

- it merely restates open questions with no consequence model

### Quality bar

Passes only if:

- it defines impressive completion, not minimal presence
- it identifies disqualifying shortcuts

Fails if:

- it can be satisfied by checking boxes with low-confidence content

## Review Questions

`M0` should be reviewed against these questions:

1. Could a new AI lane start from these docs without relying on thread memory?
2. Would later milestones know when to stop for AJ review?
3. Are any persona gaps being hidden behind optimistic wording?
4. Is the `ProdDoc` issue precise enough that `M1` and `M2` can act on it?
5. Would poor delegation now be easier or harder because of this scaffold?

## Exit Rule

`M0` exits only when all of these are true:

- every roadmap milestone has a named primary owner or an explicit blocked status
- every roadmap milestone has a visible review ring
- missing personas are either approved for creation or explicitly staged as hard
  prerequisites
- the `ProdDoc` question is closed or declared a hard blocker for downstream
  identity-sensitive work
- the handoff packet template is ready to reuse
- AJ reviews and accepts the role map and unresolved-decision posture

## Not Enough To Exit

These are not sufficient:

- "we have a spreadsheet of personas"
- "most milestones have an owner"
- "we can decide the missing personas later"
- "the handoff packet can be improvised when we need it"

If the scaffold still depends on good luck or strong memory, `M0` is not done.
