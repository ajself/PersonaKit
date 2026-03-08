# Taskboard Board + Card Parity Checklist

Use this essential when building or reviewing Taskboard against the Trello-like
board and card-detail bar for this initiative.

## Parity Bar

Taskboard clears parity for this initiative only when a human user could work in
its board and card-detail flows and reasonably think it is Trello.

## Must-Pass Board Criteria

1. Board density and hierarchy feel intentional at first glance.
2. Lane and card scanning is fast in both empty and dense states.
3. Core board actions are obvious and low-friction:
   - add lane
   - add ticket
   - move ticket within a lane
   - move ticket across lanes
   - reorder lanes
   - open card detail
   - edit common fields without awkward detours
4. Search and filter behavior is coherent, visible, and useful for daily work.
5. Keyboard-first usage is credible for navigation, triage, and movement.
6. Quick add, quick edit, and drag feedback do not feel heavyweight or generic.

## Must-Pass Card Criteria

1. Card detail feels like a working surface, not a data-entry form.
2. Title, assignees, labels, due date, checklist, description, and comments feel
   like one coherent product surface.
3. Board cards expose enough metadata for scanning without overwhelming the eye.
4. Checklist, due date, and label interactions feel first-class and not bolted on.
5. Description and comments support realistic markdown-backed working behavior.
6. Board-to-detail and detail-to-board transitions preserve user context.

## Must-Pass Trust Criteria

1. No obvious template-app or AI-scaffolding feel remains.
2. Snapshot and red-pen review show no blocker-level visual regressions.
3. Accessibility review passes for supported board and card workflows.
4. Final parity review can honestly say a Trello user would not immediately
   dismiss the result as a weak imitation.

## Guardrails

- This checklist applies to board and card-detail parity only.
- It does not authorize broader Trello product parity across other views.
- Blocker findings must stop parity claims until resolved.
