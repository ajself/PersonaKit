# Pilot Validation Plan

Status: Active (Executed; pending AJ signoff)  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Validate that the planning-management foundation works end-to-end before
phase-2 encoding.

## Pilot Scope

- one StoryPilot artifact set
- one full pass sequence (`intake` through `final`)
- one daily gardening loop

## Required Scenarios

### 1) Happy Path

- run complete pass sequence with no blockers
- expected result: publish-ready decision achieved

### 2) Blocker Path

- seed one blocker (unsupported factual claim)
- expected result: progression halts before `final` until fixed

### 3) Deferred-Major Path

- seed one major issue with explicit `defer`
- expected result: publish-ready allowed only if score and blocker rules pass

### 4) Daily Gardening Loop Path

- introduce stale metadata and one broken link
- expected result: drift detected, disposition recorded, remediation verified

## Acceptance Criteria

1. All required scenarios are executed and logged.
2. Gate evidence is complete from G0 through G5.
3. Rubric double-score calibration remains within `+/-5` and same severity class.
4. No unresolved blockers remain at pilot close.

## Reporting Format

Pilot report must include:

- scenario results table
- gate pass/fail table with evidence links
- calibration results
- unresolved risks
- recommendation (`ready for phase-2` or `needs revision`)

## Exit Decision Rule

Advance to phase-2 PersonaKit encoding only if all acceptance criteria are met.

## Execution Snapshot

Execution evidence recorded in:

- `Workspaces/VentureStudio/Docs/Plan/pilot-validation-report.md`
