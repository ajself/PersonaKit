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

All agent behavior is constrained by the following documents, in order of authority:

1. **PersonaPad v1 Scope & Contract**  
   (`Docs/PersonaPad_v1_Scope_and_Contract.md`)
   - Governs prompt composition semantics, determinism, schema rules, and non-goals.
   - Nothing may change composition behavior without explicitly revising this contract.

2. **PersonaPad 2.0 Codex Prompt Pack**  
   - Governs *which new capabilities are allowed* in 2.0 (organization, import/export, diff, validation).
   - Defines sequencing, scope boundaries, and acceptance criteria for 2.0 work.
   - Each prompt file represents a bounded, shippable unit of work.
   - Agents must not invent 2.0 features outside this pack, even if they seem useful.

3. **AGENTS.md** (this document)  
   - Governs how agents operate, propose changes, and interact with the codebase.

If there is a conflict:
- v1 Scope & Contract wins on composition semantics and determinism.
- The 2.0 Codex Prompt Pack wins on allowed feature work.
- AGENTS.md governs execution discipline.

---

## Coding Style & Standards (Source of Truth)

PersonaPad’s SwiftUI coding standards are documented here:

- `Docs/Standards/SwiftUI-App-Style-Guide.md`

Tooling configs are authoritative for formatting and linting:
- `swift-format.json`
- `swiftlint.yml`

If guidance conflicts, the style guide and tooling configs win.

---

## What Agents Are Allowed To Do

Automated agents may be used for work that **hardens trust**, **reduces entropy**, and
implements explicitly approved 2.0 capabilities.

Good uses include:
- improving determinism
- increasing CLI ↔ app parity
- adding or strengthening tests
- clarifying error messages
- simplifying code paths
- removing dead or speculative abstractions
- improving documentation accuracy
- tightening release tooling and scripts

Agents are explicitly allowed to:
- implement file-based import features
- implement deterministic export/share via files (md/txt/json/zip)
- persist user state in file-backed JSON when portability is expected
- surface validation, diffing, and diagnostics for user-owned files
- add organization features defined as **views** (saved filters, pins, grouping)

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
- introduce network access or dependencies required at runtime
- add cloud sync, accounts, telemetry, or analytics
- invent new abstractions “for flexibility”
- expand schema semantics without a versioned proposal
- add inheritance, composition, or “smart” behavior
- optimize prompts or rewrite user content
- add configuration surfaces that increase support burden
- introduce “sharing” concepts that are not file-based (accounts, links, live collaboration)

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

## 2.0 Storage & Portability Rules

PersonaPad 2.0 treats user data as **first-class, user-owned files**.

Agents must follow these rules:

- Persona packs must be:
  - persistent
  - editable
  - removable
  - stored in a user-visible on-disk location

- The app must provide:
  - Import flows (copying files into PersonaPad-managed storage)
  - Export flows (writing deterministic files to disk)
  - “Reveal in Finder” for storage roots and selected packs

- File-backed state (e.g., saved filters, pins, collections) must be:
  - deterministic
  - human-readable
  - safe to check into version control

- Built-in/sample packs may exist, but must be clearly labeled read-only.

Agents must not:
- hide user data behind opaque storage
- introduce silent sync or background mutation
- invent proprietary formats when JSON will suffice

---

## Composition Semantics Are Opinionated

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

---

## Git

- Use Conventional Commits for messages (RFC 2119 semantics apply).
- ABSOLUTELY NEVER run destructive git operations (e.g. `git reset --hard`, `rm`, `git checkout/git restore` to an older commit) unless explicitly instructed in writing.
- Never revert files you didn’t author without coordination.
- Always double-check `git status` before committing.
- Keep commits atomic and list each path explicitly.
- Never amend commits unless explicitly approved.