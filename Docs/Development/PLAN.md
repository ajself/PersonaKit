# Sessions UX Refresh Plan (Layout-First Milestone)

## Status Snapshot
- Last updated: 2026-02-17
- Status: In Planning
- Owner(s): PersonaKit Studio contributors
- Scope: Sessions layout architecture only

## Problem Statement
- Current tab-first Sessions/Preview/Map flow hides session selection context.
- Goal: keep session list and selected session context visible while working in Preview/Map.

## Chosen Direction (Locked Decisions)
- Three-column desktop experience (app sidebar + sessions navigator + sessions detail)
- Segmented control for Preview/Map in detail header
- Remember last-used detail mode
- Layout-first milestone; map polish follows

## Goals
- Persistent sessions navigation while viewing detail content
- Faster mode switching without context loss
- Preserve existing preview/map correctness and async safety

## Non-Goals (This Milestone)
- No major map visual redesign
- No schema/model changes
- No inspector-driven metadata redesign

## Proposed UI Architecture
- Replace tab-rooted Sessions panel with split navigation/detail composition
- Left: session list + CRUD actions
- Right: selected session detail with Preview/Map segmented switch
- Empty/loading/error states remain mode-specific and full-height

## State Model
- `SessionsDetailMode` enum: `preview`, `map`
- `selectedSessionID` remains primary selection
- scene-persisted last detail mode (`@SceneStorage`)

## Implementation Checklist
- [ ] Refactor `SessionsPanelView` away from `TabView`
- [ ] Add detail header + segmented mode switch
- [ ] Keep existing Preview and Map content components as detail bodies
- [ ] Preserve selection-triggered refresh behavior
- [ ] Preserve session editor sheet and delete confirmation flows
- [ ] Ensure map node navigation callbacks still route through root state

## Testing Plan
- [ ] Add/extend pure state tests for mode persistence and selection transitions
- [ ] Verify Preview/Map refresh behavior on selection/workspace changes
- [ ] Keep existing map/preview lifecycle tests green
- [ ] Full `swift test` pass

## Acceptance Criteria
- Session list remains visible while viewing Preview/Map
- Selected session identity remains visible in detail header
- Preview/Map switching is immediate and does not lose selection
- Last-used detail mode restores correctly
- Existing session preview/map correctness is unchanged

## Risks & Mitigations
- Risk: state churn from dual-mode refresh
- Mitigation: retain current stale-result guards and refresh token checks
- Risk: UI regressions from layout refactor
- Mitigation: add focused state-level tests before larger visual iteration

## Follow-Up Milestone (Map Refinement)
- Node density/readability tuning
- Better issue triage presentation
- Optional inspector-style contextual metadata

## Collaboration Protocol
- Use this file as canonical roadmap
- Record decisions inline under "Decision Log"
- Update checklist items with date/owner on completion

## Decision Log
- Add dated bullet entries for any scope or behavior changes during implementation

## Test Cases and Scenarios
1. Session selected + Preview mode active: preview renders while list remains visible.
2. Session selected + Map mode active: map renders while list remains visible.
3. Switching modes preserves selected session.
4. Changing selected session updates active detail content and refreshes needed data.
5. Workspace change clears invalid selection and returns to safe empty-state.
6. Last-used detail mode persists across view reloads.

## Assumptions and Defaults
1. Target remains macOS desktop (`.macOS(.v26)`), optimizing for split-pane workflows.
2. Existing `WorkspaceStore` preview/map APIs remain unchanged.
3. No docs tooling changes are needed; plain Markdown under `Docs/Development`.
4. This plan supersedes prior relationship-map completion notes for Sessions-focused follow-up work.
