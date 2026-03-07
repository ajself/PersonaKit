# Story Asset Pipeline

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Prevent team drift by enforcing a deterministic handoff flow for narrative and
website artifacts.

## Pipeline Order

1. Product kickoff: customer brief and success criteria.
2. Narrative design: message arc and section outline.
3. Web build: first interactive draft.
4. Architecture review: technical and maintainability check.
5. QA review: behavior and content correctness.
6. VQA review: tone, readability, emotional clarity.

## Session Mapping

1. `story-product-kickoff`
2. `story-design`
3. `story-build`
4. `story-architecture-review`
5. `story-qa`
6. `story-vqa`

## Required Artifacts

Store all pilot artifacts in `Workspaces/VentureStudio/Docs/Business/StoryPilot/`.

1. `01-customer-brief.md`
2. `02-message-arc.md`
3. `03-site-structure.md`
4. `04-build-checklist.md`
5. `05-qa-report.md`
6. `06-vqa-report.md`
7. `07-ranked-requirements.md`

## Handoff Rule

No stage begins until the previous stage has produced its required artifact.

## Severity Gate

- `High` issues block progression.
- `Medium` issues require explicit acceptance.
- `Low` issues can be queued for next cycle.

Related docs:

- [Chelsea Narrative Pilot](./chelsea-narrative-pilot.md)
- [Cycle 01 Brief](./personakit-venture-cycle-01.md)
