# PersonaPad v1 — Scope & Product Contract

This document locks **PersonaPad v1**.

It exists to:
- prevent scope creep
- make tradeoffs explicit
- define what “done enough” means
- protect long-term maintainability

If something conflicts with this document, **this document wins**.

---

## Companion Documents

This contract defines *product scope*.

For guidance on how contributors and automated agents should work within this scope,
see **[AGENTS.md](AGENTS.md)**.

If there is a conflict, this contract defines *what* is allowed;
AGENTS.md defines *how* work should be performed.

## Product Statement

PersonaPad is a **local, deterministic utility for preserving intent when switching mental modes** using reusable personas.

It is designed for engineers and technical creators who:
- reuse prompts across time and tools
- care about consistency and intent
- want predictable, boring reliability

PersonaPad prevents **persona drift**, **loss of intent**, and **inconsistent prompt composition** across editors, CLIs, and environments.

---

## Core Value (v1)

**Primary value:**  
A reliable *mental mode switch* (reviewer, critic, designer, explainer) that behaves identically every time it is used.

PersonaPad succeeds when users:
- trust outputs without re-reading everything
- stop rewriting prompts manually
- reuse personas confidently weeks later

PersonaPad does *not* aim to generate better prompts — only more **consistent** ones.

---

## Atomic Unit of Value

The atomic unit of value in v1 is:

> **A deterministic persona + invocation that reliably produces the same structured prompt across tools.**

JSON, schema, and UI are implementation details in service of this.

---

## Hard v1 Scope (What Ships)

### Included
- JSON-schema–validated personas (Schema v1)
- Pack-based loading from local folders
- Deterministic prompt composition
- Fixed sectioned prompt structure
- macOS app (SwiftUI + AppKit)
- CLI (`personapad`) with behavioral parity
- Prompt preview and copy
- Local-only, offline operation
- Open source (MIT-style mindset)
- Zero analytics or tracking

### Explicitly Excluded
- AI provider execution or chat
- Cloud sync or accounts
- Remote pack fetching
- Collaboration or sharing
- Prompt optimization or rewriting
- **Persona inheritance or composition**
- Plugin systems
- Marketplaces or discovery layers

If it executes, syncs, optimizes, or phones home — it is **out of scope**.

---

## Explicit Rejection: Persona Inheritance

PersonaPad v1 **does not support persona inheritance or composition**.

- Fields such as `extends` or `systemAppend` are **explicitly rejected**
- Their presence is treated as **invalid input**
- Failures are loud and intentional (no silent fallback, no partial behavior)

This is a deliberate v1 constraint to preserve:
- determinism
- simplicity
- trust
- long-term maintainability

Future schema versions may revisit this, but v1 makes **no promise** to do so.

---

## Opinionated Stance (v1)

PersonaPad is:

- Opinionated about **structure**
- Flexible about **content**
- Neutral about **tone**

This means:
- Prompt sections are enforced
- Section order is deterministic
- Invalid personas are rejected
- Free-form prompts are not supported in v1

Flexibility beyond this is deferred.

---

## Sacred Constraints (Non-Negotiable)

These must not be compromised in v1:

- Human-readable persona JSON
- Stable, versioned schema
- Deterministic output ordering
- CLI / app behavioral parity
- Local-first operation

Features that violate these are rejected outright.

---

## Definition of “Done Enough”

v1 is ready to release when:

- Using the CLI causes no anxiety
- Prompt previews never surprise the author
- Schema errors are boring and obvious
- Outputs are trusted without second-guessing
- The app feels dull, stable, and predictable

If it feels clever, it is not done.

---

## Maintenance Contract

PersonaPad v1 commits to:
- Maintaining Schema v1 behavior
- Supporting the current CLI and app surface

PersonaPad v1 does *not* commit to:
- Supporting all future schema versions indefinitely
- Backward compatibility without versioning
- Feature parity with hypothetical future tools

Schema evolution must be explicit and versioned.

---

## Why a macOS App Exists

The macOS app exists to provide:
- Spatial browsing of persona packs
- Confidence via live preview
- Editing affordances
- Discoverability and inspection

If the app disappeared, users would lose **confidence**, not capability.

---

## Final Lock

PersonaPad v1 is intentionally:
- small
- local
- boring
- trustworthy

It is complete when it stops asking for attention.

Anything that undermines this is deferred or rejected.