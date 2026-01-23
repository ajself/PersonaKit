# PersonaPad v2 — Intent & Exploration Draft

Archived: PersonaPad v1.x is the current active product focus.

⚠️ **This is a working draft, not a commitment.**

PersonaPad v1 remains the source of truth.
See **[PersonaPad v1 Scope & Contract](../PersonaPad_v1_Scope_and_Contract.md)** and **[AGENTS.md](../../AGENTS.md)**.
This document exists to explore **where PersonaPad may grow next**
*without violating v1 principles*.

Nothing in this file is promised.
Anything here may be revised or removed.

---

## v2 Framing

PersonaPad v2 explores **scale of use**, not scope of ambition.

If v1 is about **trust and determinism**,  
v2 is about **ergonomics when the number of personas grows**.

v2 is explicitly **not** about:
- execution
- intelligence
- optimization
- platforms
- growth mechanics
- collaboration

If those become interesting, they belong in a different project.

---

## What v2 Is Allowed to Change

v2 may explore:
- how personas are **discovered**
- how they are **described**
- how they are **organized for recall**

while preserving:
- deterministic prompt composition
- schema validation
- local-only operation
- boring failure modes
- v1 CLI and app behavior

If a change affects composition semantics, it is **out of scope for v2 exploration**.

---

## Core v2 Question

> How does PersonaPad remain calm and trustworthy when a user has
> dozens or hundreds of personas?

If a proposed v2 idea does not clearly answer this question,
it does not belong here.

---

## Current v2 Exploration: Persona Discovery

The first v2 exploration focuses on **discovery-only ergonomics**.

### Goals
- Reduce cognitive load when many personas exist
- Make recall easier than memory
- Preserve v1 determinism and simplicity

### Allowed Concepts
- Lightweight, file-based metadata
- Tags or intent labels
- Short human-readable descriptions
- Search and filtering in the macOS app
- Read-only orientation affordances

### Explicit Constraints
- Metadata must **not** affect prompt composition
- Metadata must be deterministic and portable
- No ranking, inference, or “smart” behavior
- No lifecycle semantics (no projects, no teams)

Discovery improves *orientation*, not behavior.

---

## What v2 Is Still Not

Even in v2, PersonaPad is **not**:

- a chat client
- an execution environment
- a prompt optimizer
- a cloud-synced service
- a collaboration or sharing tool
- a marketplace or plugin platform

v2 must not undermine the calm established in v1.

---

## Schema Evolution (v2 Considerations)

v2 is the **earliest point** where schema evolution may be considered.

Constraints:
- Any schema changes must be versioned (e.g. Schema v2)
- Additive only; no silent behavior changes
- Migration must be explicit and opt-in
- No backward compatibility is implied without documentation

Schema evolution is allowed only to support **ergonomics**, not intelligence.

---

## Success Criteria for v2 Work

v2 exploration is successful if:

- users manage more personas with less anxiety
- discovery feels faster than recall
- the app feels calmer, not more powerful
- v1 users are not surprised
- nothing feels “smart”

If v2 makes PersonaPad feel bigger, it failed.

---

## Development Rules for v2 Exploration

Until v2 is locked:

- v1 behavior must remain unchanged
- all v2 work must be reversible
- experiments should be small and scoped
- no promises are made in README or release notes

Think in terms of **affordances**, not features.

---

## Open Questions (Intentionally Unanswered)

These are design tensions to observe, not problems to rush:

- How much metadata is enough?
- When does discoverability become distraction?
- Do collections emerge naturally, or stay implicit?
- What breaks first when persona count grows?

If you feel urgency to answer these, slow down.

---

## Status

- This document is **not final**
- Nothing here is committed
- Everything here is allowed to change

v2 begins in earnest only when:
- v1 has been used long enough to feel boring
- real friction appears from scale, not imagination
- ergonomics become the bottleneck, not trust

---

## Reminder

PersonaPad grows by **resisting temptation**, not chasing possibility.

v2 exists to protect v1 — not replace it.
