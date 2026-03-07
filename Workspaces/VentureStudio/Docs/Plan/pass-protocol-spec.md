# Pass Protocol Spec

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Define the canonical pass sequence and enforce deterministic handoffs.

## Canonical Pass Sequence

1. `intake`
2. `draft`
3. `structure`
4. `evidence`
5. `voice`
6. `qa`
7. `final`

Hard rule: no pass skipping and no reordering in v1.

## Pass Definitions

### 1) Intake

Entry criteria:

- initiative objective is documented
- audience and success criteria are explicit

Required output:

- scoped brief with in/out boundaries

Exit criteria:

- objective, audience, and constraints are unambiguous

### 2) Draft

Entry criteria:

- intake output approved

Required output:

- first complete narrative draft (no TODO placeholders)

Exit criteria:

- all required sections exist in draft form

### 3) Structure

Entry criteria:

- complete draft exists

Required output:

- section ordering and hierarchy pass

Exit criteria:

- narrative flow is coherent and section transitions are explicit

### 4) Evidence

Entry criteria:

- structured draft is stable

Required output:

- claim-to-evidence trace map

Exit criteria:

- no unsupported factual claim remains

### 5) Voice

Entry criteria:

- evidence trace is complete

Required output:

- tone, cadence, and AP style editorial pass

Exit criteria:

- style is consistent with audience and AP style baseline

### 6) QA

Entry criteria:

- voice pass complete

Required output:

- scored rubric and findings register

Exit criteria:

- score is computed
- blockers and major/minor dispositions recorded

### 7) Final

Entry criteria:

- QA score `>= 85`
- blocker count is `0`
- all major/minor findings have owner + disposition

Required output:

- publication-ready artifact set

Exit criteria:

- final artifact package approved and logged

## Handoff Contract

Every pass handoff must include:

- artifact id and version
- pass completed
- unresolved findings summary
- owner and reviewer
- next-pass readiness statement

## Stop Conditions

Progression stops immediately when:

- factual contradiction is found
- unsupported factual claim is present
- required section is missing
- narrative logic is materially broken

## Exception Handling

No protocol exceptions are allowed in v1. Any proposed exception requires a
charter amendment and gate re-review from G1 forward.
