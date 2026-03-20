# Sprint 01: Scaffold And Handoff Discipline

Status: Ready
Milestone: `M0`
Sprint: `M0-S1`
Execution Owner: `samwise`
Review Personas: `architectural-editor`, `venture-product-steward`
Last Updated: 2026-03-18

## Purpose

Freeze the planning scaffold and delegated handoff discipline that all later
Orbit milestone lanes should inherit.

This sprint exists first because later work gets worse if packet shape, stop
rules, and evidence expectations are still fuzzy.

## Persona Anchor

Primary execution identity:

- `samwise`

Why this persona:

- continuity and bounded guidance are the core jobs of this sprint
- the sprint is about orchestration discipline, handoffs, and stop points more
  than product or code design

Review identities:

- `architectural-editor` for invariant and structure discipline
- `venture-product-steward` for planning usability and reviewability

## Worktree Rule

Execute this sprint in a dedicated non-main worktree.

Write scope may cover the `M0` milestone folder and other closely related Orbit
planning docs only if the sprint needs them to eliminate contradictions.

Do not use this sprint to broaden into product design or implementation work.

## Objective

Produce one reusable planning scaffold that later Orbit lanes can trust without
rebuilding the rules of execution each time.

## Preconditions

- `Docs/Orbit/Planning/Orbit-Agentic-Milestone-Roadmap.md` remains the top-level
  sequencing authority
- the current `M0` dossier set exists as the starting scaffold
- PersonaKit grounding is available for the active personas

## Required Inputs

- `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Sprint-Plan.md`
- `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/README.md`
- `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Quality-Bar.md`
- `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Delegated-Handoff-Packet-Template.md`
- `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Evidence-And-Exit-Criteria.md`
- `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Tech-Stack-Posture.md`

## Quality Bar For This Sprint

This sprint is successful only if:

- later lanes can tell what to load, what they may change, and when they must
  stop
- the handoff template is strict enough to make weak delegation harder
- the scaffold reinforces the approved Orbit direction rather than feeling like a
  generic planning shell
- evidence and review expectations are explicit, not implied

This sprint is not successful if it merely preserves existing files without
proving they work together as one scaffold.

## Exact Scope

Include:

- dossier-structure normalization for `M0`
- handoff packet normalization
- closeout and evidence expectation normalization for `M0`
- elimination of contradictions among the core `M0` planning files

Exclude:

- persona-coverage decisions that belong to Sprint 3
- `ProdDoc` resolution itself
- missing-persona approval decisions
- implementation or UI work

## Ordered Work

### Packet 1. Scaffold Audit

Outcome:

- identify whether the current `M0` docs already act like one coherent scaffold

Tasks:

- compare `README.md`, `Quality-Bar.md`, `Delegated-Handoff-Packet-Template.md`,
  and `Evidence-And-Exit-Criteria.md`
- list terminology mismatches or duplicated meanings
- list any missing connection between quality, evidence, stop points, and
  handoff shape

Completion signal:

- one short audit note exists, even if only internal to the sprint lane

### Packet 2. Normalize The Dossier Standard

Outcome:

- `M0` reads like one planning contract rather than several adjacent notes

Tasks:

- tighten section language where it drifts
- ensure file responsibilities are distinct
- ensure the file map and evidence requirements match the actual dossier set

Completion signal:

- a reviewer can explain each `M0` file's job in one sentence without overlap

### Packet 3. Normalize The Delegated Handoff Contract

Outcome:

- later lanes can start from one strict handoff pattern

Tasks:

- verify required grounding, scope, evidence, stop points, and failure
  dispositions are explicit
- verify the template makes worktree and write-scope discipline clear
- verify the template blocks stack or product redefinition by implication

Completion signal:

- the handoff template can be reused for `M1` and `M2` without adding a second
  packet standard

### Packet 4. Review And Tighten

Outcome:

- the scaffold is strong enough to hand to Sprint 2 and Sprint 3

Tasks:

- run architectural-editor review on structure and invariants
- run venture-product-steward review on planning usability
- apply any corrections needed before sprint closeout

Completion signal:

- both review personas can explain why the scaffold is reusable and bounded

## Evidence And Outputs

- updated or confirmed `README.md`
- updated or confirmed `Delegated-Handoff-Packet-Template.md`
- updated or confirmed `Quality-Bar.md`
- updated or confirmed `Evidence-And-Exit-Criteria.md`
- sprint closeout note summarizing what was tightened and what remains for later
  sprints

## Stop Points

- stop if Sprint 1 starts deciding `ProdDoc` or missing-persona questions in
  place of Sprint 3
- stop if the scaffold still permits a later lane to treat approved stack or
  product direction as open
- stop if review personas disagree on whether the scaffold is usable

## Exit Rule

Sprint 1 exits when the `M0` scaffold can be reused by a future lane without
thread reconstruction and without inventing a second handoff standard.

## Handoff Forward

On exit, hand forward to:

- `Sprint-02-Tech-Posture-And-Worktree-Freeze.md`
- `Sprint-03-Persona-Coverage-And-Identity-Closure.md`

The handoff should name any remaining contradictions rather than quietly pushing
them into later work.
