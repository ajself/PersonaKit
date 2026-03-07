# Artifact Template Library Spec

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Standardize planning and delivery artifacts so depth and quality are consistent.

## Global Template Requirements

Every template must include:

1. metadata block:
   - `Status`
   - `Owner`
   - `Last Reviewed`
2. purpose statement
3. required inputs
4. required outputs
5. verification section
6. related docs

## Required Minimum Depth

- No placeholder-only sections.
- At least one concrete example per critical section.
- Explicit acceptance criteria for any decision-bearing artifact.

## Planning Templates (v1)

### 1) Charter Template

Required sections:

- mission
- objectives
- scope boundaries
- roles/accountability
- governance rules

### 2) Pass Protocol Template

Required sections:

- pass sequence
- per-pass entry/exit criteria
- handoff contract
- stop conditions

### 3) QA Rubric Template

Required sections:

- weighted dimensions
- thresholds
- severity taxonomy
- disposition rules

### 4) Operations Policy Template

Required sections:

- cadence
- drift triggers
- remediation workflow
- logging requirements

### 5) Automation Contract Template

Required sections:

- command purpose
- input/output contract
- failure semantics
- deterministic output expectations

### 6) Pilot Validation Template

Required sections:

- scenarios
- expected outcomes
- acceptance criteria
- reporting format

## Delivery Artifact Templates (Story Pilot Alignment)

The following remain required for StoryPilot continuity:

1. `01-customer-brief.md`
2. `02-message-arc.md`
3. `03-site-structure.md`
4. `04-build-checklist.md`
5. `05-qa-report.md`
6. `06-vqa-report.md`
7. `07-ranked-requirements.md`

## Traceability Requirement

Every delivery artifact must support this chain:

`requirement -> artifact section -> evidence reference`

A missing link in the chain is treated as a QA finding.
