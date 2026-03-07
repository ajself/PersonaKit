# Automation Command Spec

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Define command contracts for future automation helpers. This phase is spec-only;
no command implementation is created here.

## Command 1: `docs-doctor`

### Contract

- checks metadata, links, and structure consistency
- scans only workspace initiative docs by default

### Inputs

- optional root path (default: `Workspaces/VentureStudio/Docs`)

### Outputs

- deterministic report with:
  - missing metadata
  - broken links
  - structure violations

### Exit semantics

- `0`: no blockers/majors
- non-zero: blockers or majors detected

## Command 2: `docs-qa`

### Contract

- scaffolds rubric scoring and finding register for one artifact set

### Inputs

- artifact id
- optional scorer id

### Outputs

- deterministic scoring sheet:
  - dimension scores
  - weighted total
  - findings table (severity, owner, disposition)
  - publish-ready decision

### Exit semantics

- `0`: publish-ready threshold met and no blockers
- non-zero: threshold miss or blockers present

## Command 3: `docs-garden`

### Contract

- runs drift scan and emits maintenance summary

### Inputs

- optional scope path list

### Outputs

- deterministic drift report:
  - trigger list
  - remediation recommendations
  - unresolved item list
  - mirrored event entries in `Docs/Plan/logs/gardening-events.jsonl` using shared gardening contract

### Exit semantics

- `0`: no unresolved blocker drift
- non-zero: unresolved blocker drift present

## Determinism Requirements

All commands must:

- avoid timestamps in core output payloads
- sort findings stably
- avoid environment-specific noise

## Non-goals

- no automatic content rewriting
- no hidden mutation side effects
- no scope expansion outside requested root
