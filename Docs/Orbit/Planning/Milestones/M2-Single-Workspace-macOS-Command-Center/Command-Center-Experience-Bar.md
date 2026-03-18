# Command-Center Experience Bar

Status: Draft
Milestone: `M2`
Owners: `venture-product-steward`, `studio-interaction-quality-lead`
Last Updated: 2026-03-18

## Purpose

Define the bespoke product and interaction bar for the first Orbit macOS room.

This file exists because `M2` is not only an implementation milestone.
It is the first moment where the product either feels like Orbit or collapses
back into a chat pattern.

## Experience Promise

On first open, the command center should communicate five things quickly:

1. where AJ is
2. who is in the room
3. what discussion is active
4. why a response happened
5. what deserves attention now

If one of those is unclear, the room loses force.

## Required Product Surfaces

### 1. Workspace Context Surface

Must communicate:

- active workspace name: `Orbit`
- short purpose or description
- clear sense that this workspace is the boundary of operation

Quality checks:

- the workspace is unmistakable on first scan
- the header does not look like generic page chrome
- the workspace context does real orienting work

Failure smells:

- the workspace label is visually minor
- the surface looks like a generic panel title

### 2. Founding Roster Surface

Must communicate:

- AJ, Samwise, and the approved first-checkpoint third collaborator identity
- durable collaborator presence, not disposable prompt roles
- who is merely present versus who is currently active or addressed

Quality checks:

- the roster reads like persistent collaborators
- no participant is pre-highlighted in a way that implies intent AJ did not make
- participant state is legible without visual noise

Failure smells:

- the roster looks like static labels
- default highlighting creates false action bias
- presence is visually noisy or under-explained

### 3. Conversation Surface

Must communicate:

- one active room thread
- durable turn history
- visible speaker attribution
- enough space for direct address and lightweight multi-participant exchange

Quality checks:

- the thread feels like a workspace discussion, not a scratchpad
- message composition and response display feel stable and intentional
- empty and seeded states both support the same product model
- the first-open empty or seeded thread does not imply false urgency or fake
  activity

Failure smells:

- the thread is visually indistinguishable from commodity chat
- speaker identity is technically present but not product-legible
- seeded content feels like fake demo theater rather than a believable room

### 4. Activation Trace Surface

Must communicate:

- who responded
- which directive guided the response
- whether memory influenced the response

Quality checks:

- trace is discoverable from the command-center surface
- trace is lightweight enough not to dominate the room
- trace gives real confidence rather than token metadata

Failure smells:

- trace is hidden behind unrelated UI
- trace is so subtle it might as well not exist
- trace is so heavy that it becomes the main visual story

## First-Open Product Bar

All of these should be true on first open:

- panel composition is stable and top-aligned
- primary action language is stable
- the room does not depend on inline help disclosure to make sense
- workspace context and roster are legible at a glance

## Orbit-Specific Product Signals

The room should feel like Orbit because:

- the workspace is the operating boundary
- collaborators are persistent and visible
- direct and multi-participant interaction feel first-class
- activation context is inspectable
- state and structure, not copy alone, create the room metaphor

## Review Questions

Use these when judging whether the surface is good enough:

1. Does the screen read as a command center before any message is sent?
2. Does the roster feel like collaborators rather than labels?
3. Does the discussion surface feel durable and attributable?
4. Does the trace affordance make Orbit more trustworthy without making it feel
   heavier than necessary?
5. Would a neutral reviewer call this Orbit rather than "chat with personas"?

## Disqualifying Product Smells

- inline help is still required for first-open understanding
- action language changes meaning by relabeling itself in place
- the layout drifts vertically or loses compositional stability under normal use
- multi-participant behavior feels opaque or magical
- the surface still reads more like chat than Orbit
