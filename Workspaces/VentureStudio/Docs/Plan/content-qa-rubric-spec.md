# Content QA Rubric Spec

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Define a deterministic scoring model and severity policy for publish readiness.

## Weighted Dimensions (Total = 100)

| Dimension | Weight | Description |
| --- | --- | --- |
| Clarity | 25 | Is the writing plain, precise, and easy to follow? |
| Coherence | 20 | Do sections connect logically with clear transitions? |
| Evidence Traceability | 20 | Are claims supported and traceable to evidence? |
| Audience Fit | 15 | Is framing appropriate for the target audience? |
| Voice + AP Style | 10 | Is tone consistent and AP style compliant? |
| Actionability | 10 | Are next actions explicit and usable? |

## Publish Readiness Threshold

Publish-ready only when all are true:

1. weighted score `>= 85`
2. blocker count is `0`
3. every Major/Minor finding has owner + disposition

## Severity Taxonomy

### Blocker

Definition:

- factual contradiction
- unsupported factual claim
- missing required section
- broken narrative logic

Effect:

- blocks progression to `final`

### Major

Definition:

- materially harms comprehension or trust
- recoverable in current cycle

Effect:

- must have explicit owner and disposition

### Minor

Definition:

- polish/readability issue that does not break intent

Effect:

- must have explicit owner and disposition

## Finding Dispositions

Allowed values only:

- `fix now`
- `accept`
- `defer`

## Determinism Rules

For calibration, score the same artifact twice:

- total score variance must be within `+/-5`
- severity class must match across both runs

If either condition fails, rubric definitions must be refined before approval.

## QA Report Schema (Required Fields)

- artifact id
- pass date
- scorer
- weighted score
- finding table with: severity, issue, owner, disposition
- blocker count
- publish-ready decision (`yes`/`no`)
