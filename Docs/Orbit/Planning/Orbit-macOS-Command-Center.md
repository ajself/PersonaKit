# Orbit macOS Command Center

Status: Approved (AJ)
Owner: Samwise
Meeting: `2026-03-09-meeting-001`
Workspace: Orbit
Last Updated: 2026-03-18
Revision: 3

## Purpose

Describe the macOS product surface that should support the Orbit proving loop.

This document is product-facing. It should answer what the first usable Orbit
app feels like before we break the work down into implementation tasks.

## Current Role In The Planning Stack

This document remains the product source for the first Orbit room experience.

Use it to judge whether the first checkpoint feels like Orbit.

Do not use it by itself to infer:

- long-term Orbit Server architecture
- memory governance scope
- mobile-client scope
- later team, squad, or workstream milestones

Those are now sequenced by
`Docs/Orbit/Planning/Orbit-Agentic-Milestone-Roadmap.md`.

## Product Role

The macOS app is the first proving surface for Orbit.

It is not "the whole platform," but it is the first place where the Orbit idea
must become real enough to use:

- a workspace is visible
- persistent collaborators are present
- discussion is durable
- meetings can happen
- activation context can be inspected

The macOS app should feel like a command center, not a chat window with
decorations.

## Design Goal

When AJ opens the app into the Orbit workspace, the app should immediately
communicate:

1. where AJ is
2. who is available in the room
3. what discussion is active
4. why a response happened
5. what needs attention or action now

## Core Surfaces

The first proving build should include four visible surfaces working together.

### 1. Workspace Context

The app should make the active workspace unmistakable.

The user should be able to see:

- workspace name: `Orbit`
- short workspace description or purpose
- current active discussion or meeting context

Why it matters:

Without clear workspace context, Orbit collapses back into generic AI chat.

### 2. Founding-Group Roster

The app should show the initial Orbit founding group as durable workspace
participants:

- AJ
- Samwise
- ProdDoc

For planning purposes, keep this roster language until `M0` resolves whether
`ProdDoc` remains the product-facing collaborator name, becomes a formal
PersonaKit persona, or is renamed.

The roster should communicate:

- who is available
- who is active in the current discussion
- who is being addressed or invited into a meeting

Why it matters:

Orbit should feel like collaboration with persistent roles, not a single model
wearing different hats invisibly.

### 3. Conversation and Meeting Surface

The app should provide one primary discussion surface where AJ can:

- continue an existing discussion
- address one participant directly
- trigger a lightweight meeting involving multiple participants

The surface should preserve:

- durable turn history
- visible speaker attribution
- room for short summary artifacts

For the proving loop, the meeting experience can stay lightweight. It does not
need elaborate orchestration visuals. It does need to make multi-participant
discussion feel intentional rather than accidental.

#### Activation Trace Visibility

Even in the first proving build, the conversation surface should allow AJ to see basic activation context for persona responses. This does not need to be visually heavy, but it should be possible to reveal metadata such as:

- which persona responded
- which directive guided the response
- whether memory influenced the response

This reinforces Orbit's principle of **explainable collaboration**, where responses are attributable and inspectable rather than opaque model output.

### 4. Activation Trace Surface

The app should expose a clear place where lightweight activation context can be
reviewed without leaving the command-center surface.

The user should be able to:

- inspect which participant responded
- understand which directive guided the response
- understand whether memory influenced the response

Why it matters:

Explainable collaboration is one of the main things that makes Orbit different
from plain chat history.

## First-Open Experience

The first Orbit macOS command-center experience should feel like this:

1. AJ opens the app.
2. The Orbit workspace is already visible.
3. AJ can see the founding group roster.
4. AJ can see the active discussion thread.
5. AJ can start a message immediately.
6. AJ can inspect lightweight activation context without the product drifting
   into a generic chat shell.

The app should not require deep setup or hidden navigation before the proving
loop becomes available.

## What Makes This Feel Like Orbit

The macOS app should feel like Orbit, not persona chat, because:

- the workspace is the boundary of operation
- the collaborators are persistent and visible
- multi-participant exchange is a first-class behavior
- activation context is inspectable and attributable
- the room metaphor is supported by visible state rather than by copy alone

If one of those pieces is missing, the app may still be useful, but it risks
feeling like a thinner variation of existing AI chat tools.

## Intentionally Deferred in This Product Surface

The first command-center draft does not need to define:

- summary generation
- memory candidate review
- memory reuse
- iPhone or iPad surfaces
- advanced squad management UI
- complex roster composition controls
- deep meeting visualization
- broad settings/admin systems
- cross-workspace memory promotion UI

Those can follow after the first proving loop is real.

## Review Questions

When AJ or ProdDoc reviews this draft, the most useful feedback is:

1. what feels missing from the first macOS surface
2. what feels too heavy for the first build
3. what would make the app feel more like Orbit and less like chat
4. whether the four-surface model is clear enough

## Revision Notes

- 2026-03-09: Initial Samwise draft created from meeting `2026-03-09-meeting-001`.
- 2026-03-09: ProdDoc review integrated. Clarified activation trace visibility and updated document metadata to reflect external revision.
- 2026-03-18: Clarified that this file is the product source for the first
  command-center checkpoint only, with broader Orbit sequencing now owned by the
  roadmap.
