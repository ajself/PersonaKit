# PersonaPad v2 — Scope & Contract (Discovery)

This document locks the **first v2 increment**: **Persona Discovery**.

It exists to:
- preserve v1 guarantees
- define what “v2 discovery” means (and what it does not mean)
- prevent discovery work from quietly becoming projects, collaboration, or execution

If something conflicts with this document, **this document wins**.

---

## Relationship to v1

PersonaPad v1 remains the foundation.
See **[PersonaPad v1 Scope & Contract](PersonaPad_v1_Scope_and_Contract.md)** for v1 guarantees.

v2 Discovery is **additive**:
- it must not change prompt composition behavior or output
- it must not change CLI `compose` semantics
- it must not weaken validation, determinism, or parity

If discovery work changes composition in any way, it is out of scope.

---

## Product Statement (v2 Discovery)

PersonaPad v2 Discovery improves **orientation and recall** when users have many personas.

It helps users:
- find the right persona faster
- understand what a persona is for before using it
- reduce cognitive load as collections grow

Discovery improves **selection**, not **behavior**.

---

## Core Value (v2 Discovery)

The value is:

> **Calm navigation and clear intent** across dozens/hundreds of personas, without introducing hidden state or “smart” behavior.

v2 Discovery succeeds when:
- users search less by memory and more by intent
- picking a persona feels fast and confident
- nothing about composition feels different than v1

---

## Scope (What Ships)

### Included
- Optional persona metadata used for discovery only:
  - tags (categorization)
  - short “about” description (orientation)
- macOS app enhancements:
  - search/filter by name/id/about/tags
  - simple tag filtering UI
  - display about/metadata alongside preview (read-only is acceptable)
- Parsing and validation:
  - metadata is loaded locally and deterministically
  - metadata does not affect composition output
- Documentation:
  - describes metadata format and its discovery-only role
- Tests:
  - parsing tests for metadata
  - deterministic rendering/ordering where relevant (e.g., tags sorted)
  - regression guard: composition output unchanged

### Explicitly Excluded
- Any composition behavior changes (structure, ordering, defaults, rendering)
- Prompt optimization, rewriting, or auto-tuning
- Ranking, inference, or “smart” recommendations
- Projects, teams, collaboration, sharing workflows
- Cloud sync, accounts, telemetry/analytics
- Remote packs, marketplaces, plugin systems
- Editing workflows that create long-term support burden (unless trivial)

If it introduces lifecycle semantics or intelligence, it is out of scope.

---

## Metadata Rules

Metadata must be:
- local-first
- deterministic
- file-based and portable
- version-control friendly
- optional

Metadata must **not**:
- change prompt composition output
- change CLI `compose` semantics
- introduce hidden state or dynamic behavior

### Storage (Record What You Chose)
Choose one approach and keep it simple:

- [x] Persona JSON fields (e.g., `tags`, `description`)
- [ ] Sidecar metadata files
- [ ] Pack manifest mapping IDs → metadata

**Chosen approach:** Persona JSON fields: `tags` (array of strings) and `description` (used as the short “about” blurb).
