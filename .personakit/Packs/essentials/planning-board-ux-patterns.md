# Planning Board UX Patterns

Use this essential when designing or reviewing lane-and-ticket planning surfaces in PersonaKit Studio.

## Terminology Contract

1. Use `ticket` for work item.
2. Use `lane` for stage column.
3. Keep lane names action-oriented (`Ready`, `In Progress`, `Review`, `Done`).

## Required Core Flows

1. Create lane from template.
2. Edit lane title and ordering.
3. Delete lane with explicit confirmation.
4. Create ticket in any lane.
5. Edit ticket fields without context loss.
6. Move ticket between lanes with visible destination feedback.
7. Delete ticket with explicit confirmation.

## UX Baselines

1. Board state should be understandable at first glance.
2. Primary actions should be visible without deep menus.
3. Empty states should explain first action.
4. Inline edits should preserve user context.
5. Keyboard path should exist for core ticket lifecycle.

## Microcopy Rules

1. Prefer concise, plain labels over internal jargon.
2. Keep button/action verbs explicit (`Add Ticket`, `Move`, `Delete`).
3. Avoid status names that imply hidden workflow rules.

## Guardrails

- No feature additions during quality pass unless explicitly approved by AJ.
- No visual redesign detours when the task is flow correctness.
- Keep recommendations prioritized by user impact.
