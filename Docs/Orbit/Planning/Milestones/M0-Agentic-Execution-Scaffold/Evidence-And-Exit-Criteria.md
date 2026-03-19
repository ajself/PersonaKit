# M0 Evidence And Exit Criteria

Status: Accepted
Milestone: `M0`
Owner: `samwise`
Last Updated: 2026-03-18

## Purpose

Define the artifacts and review tests required to close `M0` honestly.

## Required Artifacts

`M0` should not close without all of these artifacts existing and being usable:

1. a frozen milestone dossier standard in `Docs/Orbit/Planning/Milestones/README.md`
2. a reusable template library in `Docs/Orbit/Planning/Milestones/_Templates/`
3. a delegated handoff packet template in `M0-Agentic-Execution-Scaffold/Delegated-Handoff-Packet-Template.md`
4. a milestone-to-persona coverage matrix
5. a decision register covering `ProdDoc` and missing-persona questions
6. a quality bar that explains why thin completion is not enough
7. a frozen tech-stack posture for `M0` through `M3`
8. a planning closeout packet that surfaces the final approval asks cleanly and
   records the approval outcome

## Artifact Quality Tests

### Dossier standard

Passes only if:

- later milestone dossiers all share a common structure
- the structure makes packet order, evidence, and stop points explicit
- the structure defines the difference between roadmap, dossier, execution
  packet, and lane execution notes

Fails if:

- the structure is mostly decorative
- later lanes would still need to invent the real planning logic

### Template library

Passes only if:

- the templates encode the frozen dossier standard instead of a parallel shape
- the templates are specific enough that later milestones can start from them
  without guessing which sections matter

Fails if:

- the templates drift from the dossier standard
- later milestone authors would still need to invent the packet shape from
  scratch

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

### Tech-stack posture

Passes only if:

- client and server direction for `M0` through `M3` are explicit
- fixed choices are clearly separated from constrained choices
- AI decision boundaries are explicit enough to prevent stack drift

Fails if:

- core stack choices still look open to agent preference
- infrastructure and deployment posture can still be widened by implication

### Planning closeout packet

Passes only if:

- AJ can review the remaining approval asks without reconstructing thread memory
- the packet distinguishes closed decisions from staged prerequisites

Fails if:

- the final approval asks are scattered across too many notes
- blocked later-milestone persona gaps are easy to miss during review

## Review Questions

`M0` should be reviewed against these questions:

1. Could a new AI lane start from these docs without relying on thread memory?
2. Would later milestones know when to stop for AJ review?
3. Are any persona gaps being hidden behind optimistic wording?
4. Is the `ProdDoc` issue precise enough that `M1` and `M2` can act on it?
5. Are fixed stack choices explicit enough that `M1`, `M2`, and `M3` cannot
   improvise them?
6. Would poor delegation now be easier or harder because of this scaffold?

## Exit Rule

`M0` exits only when all of these are true:

- every roadmap milestone has a named primary owner or an explicit blocked status
- every roadmap milestone has a visible review ring
- missing personas are either approved for creation or explicitly staged as hard
  prerequisites
- the approved stack posture for `M0` through `M3` exists and is reviewable
- the `ProdDoc` question is closed or declared a hard blocker for downstream
  identity-sensitive work
- the handoff packet template is ready to reuse
- the dossier standard and template library agree on section meanings
- the planning closeout packet cleanly presents the remaining AJ approvals
- the current construction window is explicit: implementation proceeds through
  `M3` and pauses afterward until AJ restarts it
- AJ reviews and accepts the role map and staged-decision posture

Current disposition:

- satisfied through the recorded AJ approval outcome in
  `Planning-Closeout-Packet.md`

## Not Enough To Exit

These are not sufficient:

- "we have a spreadsheet of personas"
- "most milestones have an owner"
- "we can decide the missing personas later"
- "the handoff packet can be improvised when we need it"
- "the implementation lane can pick the server stack later"

If the scaffold still depends on good luck or strong memory, `M0` is not done.
