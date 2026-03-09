# Orbit Proving Loop

Status: Draft
Owner: Samwise
Meeting: `2026-03-09-meeting-001`
Workspace: Orbit
Last Updated: 2026-03-09

## Purpose

Define the smallest real product loop that should count as the first proof of
Orbit.

This document is intentionally narrower than the full Orbit concept and RFC
set. It is meant to translate the larger North Star into one implementation
target for the first serious build.

## Samwise Framing

The first proving loop should answer one question:

Can AJ use a real macOS Orbit app inside the Orbit workspace, with a small
persistent AI founding group, and experience enough durable collaboration and
governed learning to prove that Orbit is more than persona chat?

If the answer is yes, the broader platform direction has earned the right to
expand.

If the answer is no, the larger architecture remains interesting but is not yet
grounded in a working center.

## Current Recommendation

The first proving loop should be:

- client: macOS app
- workspace: Orbit
- founding group: AJ, Samwise, ProdDoc
- mode: real use while shaping Orbit itself

## Required Capabilities

These capabilities must exist together for the first loop to count as a real
Orbit proof.

1. Workspace surface
   The app opens into the Orbit workspace and clearly shows the active
   workspace context.
2. Persistent founding-group roster
   AJ, Samwise, and ProdDoc appear as durable participants in the workspace.
3. Durable conversation thread
   Discussion persists across app restarts with attribution intact.
4. Persona or meeting invocation
   AJ can direct a message to one participant or trigger a lightweight
   multi-participant exchange.
5. Activation trace
   Persona responses can be tied to a concrete activation/directive context.
6. Summary generation
   A short exchange can produce a usable summary artifact.
7. Memory candidate generation
   The system can propose at least one candidate memory from the exchange or
   summary.
8. Human review
   AJ can approve or reject that candidate in the app.
9. Memory reuse
   Approved memory affects a later response in a visible and attributable way.

## Explicitly Deferred

These are valid North Star capabilities, but they are not required for the
first proving loop.

- multi-client operation
- complex team or squad management UI
- cross-workspace memory promotion
- automated gardening or candidate clustering
- elaborate meeting visualization
- broad roster generation for specialist squads
- mature analytics or historical inspection tooling

## Success Test

The first Orbit proving loop is successful if AJ can:

1. open the Orbit workspace in the macOS app
2. see AJ, Samwise, and ProdDoc in the workspace context
3. run a short discussion in that workspace
4. receive a meeting or discussion summary
5. review a proposed memory candidate
6. approve that candidate
7. observe a later response being influenced by the approved memory

If that loop works end-to-end in one coherent product surface, Orbit has moved
from concept into functioning system.

## Language Note

For this proving loop, use the following distinction:

- `founding group`: AJ, Samwise, and ProdDoc in the Orbit workspace
- `squad`: a generated working group for a workspace problem, such as product,
  design, and engineering personas

This avoids confusing the human-plus-two-AI operating group with a generated
persona squad.

## Open Questions

- What term should replace `founding group` later if a better one emerges?
- Should ProdDoc be modeled immediately as a persistent workspace participant,
  or first as an external review counterpart represented inside Orbit?
- How visible should activation trace be in the first macOS surface?

## Review Guidance

When AJ or ProdDoc reviews this draft, the most useful feedback is:

1. what is missing from the proving loop
2. what is too ambitious for the first build
3. what wording would make the success test clearer
4. whether the founding-group vs squad distinction is clear enough

## Revision Notes

- 2026-03-09: Initial Samwise draft created from meeting `2026-03-09-meeting-001`.
