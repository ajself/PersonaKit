# Orbit macOS Command Center

Status: Draft
Owner: Samwise
Meeting: `2026-03-09-meeting-001`
Workspace: Orbit
Last Updated: 2026-03-09
Revision: 2

## Purpose

Describe the macOS product surface that should support the Orbit proving loop.

This document is product-facing. It should answer what the first usable Orbit
app feels like before we break the work down into implementation tasks.

## Product Role

The macOS app is the first proving surface for Orbit.

It is not "the whole platform," but it is the first place where the Orbit idea
must become real enough to use:

- a workspace is visible
- persistent collaborators are present
- discussion is durable
- meetings can happen
- memory can be reviewed and reused

The macOS app should feel like a command center, not a chat window with
decorations.

## Design Goal

When AJ opens the app into the Orbit workspace, the app should immediately
communicate:

1. where AJ is
2. who is available in the room
3. what discussion is active
4. what the system learned recently
5. what needs review or action

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

### 4. Memory Review Surface

The app should expose a clear place where proposed memory candidates appear for
AJ review.

The user should be able to:

- inspect a candidate
- understand what discussion or summary it came from
- approve or reject it

Why it matters:

Governed learning is one of the main things that makes Orbit different from
plain chat history.

## First-Open Experience

The first Orbit macOS command-center experience should feel like this:

1. AJ opens the app.
2. The Orbit workspace is already visible.
3. AJ can see the founding group roster.
4. AJ can see the active discussion thread.
5. AJ can start a message immediately.
6. The app can later surface a summary and a memory candidate from that
   discussion.

The app should not require deep setup or hidden navigation before the proving
loop becomes available.

## What Makes This Feel Like Orbit

The macOS app should feel like Orbit, not persona chat, because:

- the workspace is the boundary of operation
- the collaborators are persistent and visible
- multi-participant exchange is a first-class behavior
- the system can summarize and propose durable learning
- memory review is part of the product surface

If one of those pieces is missing, the app may still be useful, but it risks
feeling like a thinner variation of existing AI chat tools.

## Intentionally Deferred in This Product Surface

The first command-center draft does not need to define:

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
