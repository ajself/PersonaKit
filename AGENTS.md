# AGENTS.md — Working With PersonaPad

This document defines how **automated agents (e.g. Codex)** and human contributors
should interact with the PersonaPad codebase.

It exists to:
- preserve product intent
- protect scope and determinism
- prevent well-meaning overengineering
- keep the project boring, reliable, and maintainable

If an agent or contribution conflicts with this document, **this document wins**.

---

## Project Identity (Non-Negotiable)

PersonaPad is a **local, deterministic utility**.

It is:
- file-based
- schema-driven
- offline
- boring on purpose

It is **not**:
- a platform
- a runtime
- an execution engine
- a cloud service
- a chat client
- an AI product in the startup sense

Any agent operating on this repository must respect this framing.

---

## Source of Truth

All agent behavior is constrained by the project’s scope contract:

- **[PersonaPad v1 Scope & Contract](PersonaPad_v1_Scope_and_Contract.md)**

Agents must not propose or implement changes that violate that contract,
even if technically feasible or seemingly useful.

---

## What Agents Are Allowed To Do

Automated agents may be used for work that **hardens trust** and **reduces entropy**.

Good uses include:
- improving determinism
- increasing CLI ↔ app parity
- adding or strengthening tests
- clarifying error messages
- simplifying code paths
- removing dead or speculative abstractions
- improving documentation accuracy
- tightening release tooling and scripts

Agents are especially valuable for:
- repetitive refactors
- test coverage
- verification tasks
- release readiness checks

---

## What Agents Must Not Do

Agents must **not**:

- add new product features without explicit direction
- introduce execution, chat, or provider integration
- introduce network access or dependencies that require it at runtime
- add cloud sync, accounts, telemetry, or analytics
- invent new abstractions “for flexibility”
- expand schema semantics without a versioned proposal
- add inheritance, composition, or “smart” behavior
- optimize prompts or rewrite user content
- add configuration surfaces that increase support burden

If a change increases scope, cleverness, or surprise, it is likely wrong.

---

## Schema & Determinism Rules

PersonaPad’s core value depends on **deterministic behavior**.

Agents must ensure:
- same persona + same inputs → identical output
- section ordering is fixed and documented
- defaults are explicit, not inferred
- no hidden mutation or reordering occurs

Schema rules:
- Schema v1 is stable
- Unsupported fields (e.g. `extends`, `systemAppend`) are **explicitly rejected**
- Invalid input must fail loudly and clearly
- Schema evolution must be versioned and intentional

---

## Opinionated by Design

PersonaPad is opinionated about:
- structure
- validation
- failure modes

Agents should **not** attempt to:
- add free-form prompt modes
- make validation optional
- “helpfully” recover from invalid input
- infer user intent

Clarity beats convenience.

---

## macOS App vs CLI Expectations

The macOS app and CLI must:
- share core logic
- produce identical output for identical inputs
- diverge only in presentation, not behavior

Agents should prefer:
- refactoring shared logic into `PersonaPadCore`
- adding parity tests when touching either surface

---

## How Agents Should Propose Work

When an agent proposes changes, it should:
1. State which constraint(s) it is reinforcing
2. State which scope boundary it is *not* crossing
3. Prefer small, reversible changes
4. Avoid speculative future-proofing

If a proposal cannot justify itself in these terms, it should not proceed.

---

## Release-Oriented Mindset

PersonaPad values:
- boring releases
- calm usage
- predictable behavior

Agents should optimize for:
- fewer surprises
- fewer knobs
- fewer edge cases
- fewer promises

If a change makes the project feel more exciting, pause.

---

## Living Document

This file is expected to evolve.

When updating `AGENTS.md`:
- prefer tightening language over expanding it
- record intent, not implementation
- assume future agents will not have full context

This document exists to protect future-you.
