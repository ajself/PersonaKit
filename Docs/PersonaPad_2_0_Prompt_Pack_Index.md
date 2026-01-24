# PersonaPad 2.0 Codex Prompt Pack — Index

This document defines the **allowed 2.0 work units** and their execution order.
Each prompt is a bounded, shippable unit. Work outside this pack is out of scope.

PersonaPad 2.0 remains:
- local, file-based, deterministic
- offline, no accounts, no telemetry
- boring and predictable

---

## Execution Ladder (Order Matters)

1. **P01 — Storage & Portability Core**
2. **P02 — Import / Export Flows**
3. **P03 — Diffing & Diagnostics**
4. **P04 — Validation UX (App + CLI)**
5. **P05 — Organization Views (Filters, Pins, Grouping)**
6. **P06 — Parity Tests + Release Gates**

Later prompts must not change the semantics established earlier.

---

## Prompt Index

### P01 — Storage & Portability Core
Scope:
- Define user-visible storage roots for packs and state
- Deterministic file layout and naming
- Reveal-in-Finder surfaces

Out of scope:
- Cloud sync or background mutation
- Hidden or opaque storage formats

Acceptance criteria:
- Storage is deterministic and user-visible
- Files are editable and removable by the user

---

### P02 — Import / Export Flows
Scope:
- File-based import (copy into PersonaPad storage)
- Deterministic export/share to disk (JSON/ZIP as defined)

Out of scope:
- Sharing links, accounts, or live collaboration

Acceptance criteria:
- Import copies files under the selected root only
- Export writes deterministic output

---

### P03 — Diffing & Diagnostics
Scope:
- Deterministic diffing between packs/personas
- Diagnostics that are stable and user-facing

Out of scope:
- Auto-merge or conflict resolution

Acceptance criteria:
- Diffs are deterministic and stable across runs
- Diagnostics do not mutate state

---

### P04 — Validation UX (App + CLI)
Scope:
- Clear validation errors for user-owned files
- CLI and app present identical validation outcomes

Out of scope:
- Auto-fixes or “best effort” recovery

Acceptance criteria:
- Invalid input fails loudly and clearly
- Validation does not change composition semantics

---

### P05 — Organization Views (Filters, Pins, Grouping)
Scope:
- Saved filters, pins, grouping views
- File-backed, deterministic state

Out of scope:
- Cross-user sharing or sync
- New schema semantics

Acceptance criteria:
- State is human-readable JSON
- Deterministic ordering and sorting

---

### P06 — Parity Tests + Release Gates
Scope:
- App/CLI parity tests for composition + validation
- Deterministic outputs verified by tests
- Release checklist gates

Out of scope:
- New features

Acceptance criteria:
- `swift test` and `./Scripts/release-check.sh` stay green
- Parity tests cover core flows

---

## Rules of Engagement

- Each prompt is a single, bounded unit of work.
- Do not invent 2.0 features outside this index.
- Composition semantics must remain aligned with the v1 contract unless the
  contract is explicitly revised.
