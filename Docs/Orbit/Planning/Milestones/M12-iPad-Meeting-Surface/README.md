# M12 iPad Meeting Surface

Status: Planned
Primary Owner: `senior-swiftui-engineer`
Supporting Personas: `studio-interaction-quality-lead`, `orbit-meeting-coordinator`, `venture-product-steward`
Last Updated: 2026-03-18

## Purpose

Make iPad materially better for meeting orchestration rather than merely a larger
client.

## Preconditions

- `M3` canonical runtime is trusted
- `M5` meeting continuity is already good enough to deserve a dedicated meeting
  surface
- the meeting coordinator persona is approved and available

## Scope Freeze

In scope:

- iPad meeting-first layouts
- roster and comparison surfaces
- richer live facilitation panels
- shared runtime semantics with macOS and iPhone

Out of scope:

- full macOS parity
- device-specific workflow semantics that contradict canonical runtime behavior

## Required Inputs

- `Docs/Orbit/RFCs/RFC-0006-Orbit-Multi-Client-Platform-Architecture.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- `M5` meeting continuity evidence

## Execution Packets

### Packet 1. Freeze The iPad Meeting Wedge

Outcome:

- the iPad client has one clear reason to exist

Work:

- define the meeting workflows that benefit from tablet ergonomics
- define what should remain macOS or phone work
- define the minimal multi-pane value proposition

Done when:

- layout work is driven by facilitation needs, not by generic screen size

### Packet 2. Build Meeting-First Layouts

Outcome:

- iPad presents meetings with more spatial clarity than the phone or desktop

Work:

- build multi-pane layouts
- build roster-aware panels
- keep surfaces anchored to canonical meeting state

Done when:

- the meeting surface reads as tablet-native rather than stretched desktop UI

### Packet 3. Add Comparison And Facilitation Panels

Outcome:

- meeting review and facilitation become easier on iPad

Work:

- add participant comparison surfaces
- add facilitation and progression panels
- support meeting context inspection without losing continuity

Done when:

- the operator can run a live meeting more clearly on iPad than on phone alone

### Packet 4. Run Interaction Review

Outcome:

- the iPad surface earns its device-specific complexity

Work:

- run interaction review on meeting ergonomics
- validate continuity and parity with canonical state
- identify any diluted macOS-copy patterns that need removal

Done when:

- interaction review confirms a distinct iPad value proposition

## Subagent Use Pattern

Safe subagents:

- meeting ergonomics review
- large-screen layout review
- interaction-quality review

Avoid:

- inventing tablet-only workflow semantics that do not exist in Orbit itself

## Evidence Package

- iPad meeting wedge brief
- layout examples
- facilitation panel examples
- interaction review artifact

## Stop Points

- stop if the iPad surface is becoming a diluted macOS clone
- stop if meeting behavior differs semantically from canonical runtime truth

## Exit And Handoff

Exit when iPad adds distinct, reviewable meeting value over the shared Orbit
backend.

Handoff forward to:

- `M13` platform operations and broader multi-client hardening
