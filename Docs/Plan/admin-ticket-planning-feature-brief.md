# Admin Ticket Planning Feature Brief

Status: Draft  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Define a bounded v1 feature for PersonaKit Studio: an `Admin` sidebar area that provides Trello/GitHub-Issues-style project and ticket planning using editable lane templates.

## Problem Statement

PersonaKit Studio currently lacks a first-class planning surface for turning initiative work into visible, trackable tickets. Planning lives across markdown notes and logs, which makes day-to-day project and task flow harder to scan and update quickly.

## Target User And Context

- Primary user: AJ (working as founder/operator with multiple personas and subagents).
- Usage context: in-app planning during active product sessions, before and during implementation phases.
- Core need: create project lanes quickly from templates, then add/move/edit/delete tickets without leaving Studio.

## Desired Outcome

Add an in-app planning workflow that makes project state obvious at a glance and reduces planning friction to under one minute for common operations (create lane, create ticket, update ticket status).

## Proposed Scope

### In Scope (v1)

1. New sidebar section: `Admin`.
2. New Admin destination: `Ticket Planning`.
3. Lane model with CRUD:
   - create lane from template
   - edit lane metadata
   - delete lane
   - reorder lanes
4. Ticket model with CRUD per lane:
   - create ticket
   - edit ticket fields
   - move ticket between lanes
   - delete ticket
5. Default lane templates inspired by Trello/GitHub Issues workflows:
   - `Inbox`
   - `Ready`
   - `In Progress`
   - `Blocked`
   - `Review`
   - `Done`
6. Persistence in workspace-local data file (deterministic schema, no cloud sync in v1).

### Out Of Scope (v1)

1. Multi-user collaboration or live sync.
2. GitHub/Trello API integrations.
3. Notifications/automations.
4. Time tracking, story points, or advanced reporting.
5. Cross-workspace ticket federation.

## UX Shape (v1)

1. Sidebar:
   - Add section `Admin`.
   - Add row `Ticket Planning` with dedicated icon.
2. Main panel:
   - Horizontal lane board.
   - Lane header actions: add ticket, edit lane, delete lane.
   - Ticket cells with concise fields (`title`, `owner`, `priority`, `status`, `labels`).
3. Interactions:
   - drag-and-drop tickets across lanes
   - context menu for lane/ticket edit/delete
   - quick-add controls for new lane and ticket

## Data Model Draft

1. `PlanningBoard`
   - `id`
   - `name`
   - `lanes: [PlanningLane]`
2. `PlanningLane`
   - `id`
   - `title`
   - `templateID` (optional)
   - `order`
   - `tickets: [PlanningTicket]`
3. `PlanningTicket`
   - `id`
   - `title`
   - `description` (optional)
   - `owner` (optional)
   - `priority` (`low|medium|high`)
   - `labels: [String]`
   - `createdAt`
   - `updatedAt`

## Risks And Unknowns

1. Drag-and-drop behavior quality in SwiftUI board layouts may need iteration.
2. Board state schema will need migration strategy before v2 features.
3. Potential overlap with existing sessions panel workflows needs clear boundaries in UX copy.

## Dependencies

1. Studio sidebar/navigation updates for new `Admin` section.
2. New state/store slice for planning board entities and actions.
3. Persistence client for workspace-local planning board JSON.
4. New UI panels/components for board, lane, and ticket editing.

## Acceptance Criteria

1. `Admin` section appears in sidebar and opens `Ticket Planning`.
2. User can create/edit/delete lane from template and reorder lanes.
3. User can create/edit/delete ticket and move tickets across lanes.
4. Board state persists per workspace and reloads correctly on app restart.
5. Empty-state and error-state messaging are present for missing/invalid board data.

## Decision Gate

- Approver: AJ
- Approval condition:
  - Discovery brief accepted.
  - Gate result is `pass-with-notes` or `pass`.
  - v1 scope boundary confirmed (no integrations/collaboration additions).

## First Next Action

Implement a UI shell milestone: add `Admin` + `Ticket Planning` navigation target with placeholder board view and deterministic sample lane template data.

After `ATP-M1`, run `studio-interaction-quality` red-pen pass before moving to `ATP-M2`.

## Milestone Plan (Planning Pass)

### M1

- Milestone ID: `ATP-M1`
- Goal: Deliver sidebar/nav and board shell.
- Scope: Sidebar `Admin` section, `Ticket Planning` destination, placeholder board view.
- Owner: AJ + Samwise
- Status: `not-started`
- Risks: navigation-state regressions
- Dependencies: sidebar enum/state wiring
- Exit Criteria: App builds; `Admin` route is reachable; placeholder board renders.
- Next Checkpoint Date: 2026-03-08

### M2

- Milestone ID: `ATP-M2`
- Goal: Deliver lane template and lane CRUD.
- Scope: Template picker, create/edit/delete/reorder lanes.
- Owner: AJ + Samwise
- Status: `not-started`
- Risks: lane ordering drift in persistence
- Dependencies: M1 shell + data store shape
- Exit Criteria: Lane CRUD works and persists in workspace-local file.
- Next Checkpoint Date: 2026-03-09

### M3

- Milestone ID: `ATP-M3`
- Goal: Deliver ticket CRUD and lane movement.
- Scope: Ticket create/edit/delete and move between lanes.
- Owner: AJ + Samwise
- Status: `not-started`
- Risks: drag-and-drop edge cases on macOS
- Dependencies: M2 lane structure
- Exit Criteria: Tickets can move lanes and persist after restart.
- Next Checkpoint Date: 2026-03-10

### M4

- Milestone ID: `ATP-M4`
- Goal: Stabilize and prep for rollout.
- Scope: Empty/error states, quality pass, docs updates.
- Owner: AJ + Samwise
- Status: `not-started`
- Risks: unclear UX copy for lane/ticket lifecycle
- Dependencies: M1-M3 complete
- Exit Criteria: Manual QA checklist passes; docs updated; rollout decision recorded.
- Next Checkpoint Date: 2026-03-11

## Quality Gate Result

- Discovery artifact gate: `pass-with-notes`
- Notes:
  1. Persistence format versioning policy should be decided before M2 close.
  2. Ticket field set may need one revision after first real usage cycle.

## Related Docs

- `Docs/Plan/TODO.md`
- `Docs/Plan/partner-context-log.md`
- `.personakit/Sessions/venture-product-discovery.session.json`
- `.personakit/Sessions/venture-product-planning.session.json`
- `.personakit/Sessions/studio-interaction-quality.session.json`
