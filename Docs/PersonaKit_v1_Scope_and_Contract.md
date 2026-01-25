# PersonaKit v1 Scope & Contract

This document is the authoritative contract for **PersonaKit v1**. It defines
composition semantics, determinism rules, and non-goals. If code or proposals
conflict with this document, the document wins.

---

## Project Identity (Non-Negotiable)

PersonaKit v1 is:
- local
- deterministic
- file-based
- offline
- boring by design

PersonaKit v1 is **not**:
- a chat client
- a runtime or execution engine
- an AI provider integration
- a cloud service or sync system
- a collaboration platform
- a prompt optimizer or enhancer

---

## Inputs and Outputs

PersonaKit consumes:
- **Persona documents** (JSON) that conform to Schema v1
- **Section values** provided by the user (e.g., context, task)

PersonaKit produces:
- **Deterministic prompt text** (primary output)
- **Resolved JSON** (optional, for inspection)

Output must be identical for the same persona + section values across app and CLI.

---

## Composition Semantics (Authoritative)

Composition is defined by `PromptComposer.compose`.

Given a resolved `Persona` and a dictionary of section values:

1. Start with the persona’s `system` text, trimmed of leading/trailing whitespace.
2. If the persona defines a `template.sections` list:
   - Iterate sections **in the order provided** by the template.
   - For each section:
     - Look up the user value by `section.key`.
     - Trim the value; **skip** if empty.
     - Append:
       - the section label uppercased
       - a newline
       - the section value
     - Append a blank line after each rendered section.
3. If no template sections exist:
   - Use **all provided section keys**, sorted lexicographically.
   - Render each non-empty section using the same format as above.
4. After joining parts, trim trailing whitespace and append **one trailing newline**.

Notes:
- `template.sections[].required` is **metadata**. It does **not** enforce inclusion.
- `outputContract` is **metadata**. It does **not** change composition in v1.
- No substitutions, inheritance, or computed fields exist in v1.

---

## Determinism Rules

Determinism means:
- same persona + same inputs → identical output
- section order is fixed and explicit
- sorting is stable and documented

Forbidden in v1 composition paths:
- time-based values (`Date()`, timers)
- random values (`UUID()`, RNG)
- network access
- implicit reordering of user inputs

If outputs could differ between runs, the change violates v1.

---

## Schema and Validation Rules

Schema v1 is stable and required.

Document requirements:
- `schemaVersion` must be `1`
- `documentType` must be `personaPack` or `persona`
- `personaPack` requires `pack` + non-empty `personas`
- `persona` requires `persona`

Unsupported fields:
- `extends`
- `systemAppend`

If present, they **must be rejected** with a clear diagnostic.

Invalid input must fail loudly and clearly. Silent recovery is not allowed.

---

## Pack Resolution

When multiple packs are loaded:
- Packs are loaded in a deterministic order (built-ins, then user packs).
- If two personas share the same id, the **later load overrides the earlier**.
- Overrides emit a warning diagnostic.

The resolved persona map must be deterministic and stable.

---

## Persona Metadata

Metadata fields such as `tags` and `description`:
- are for discovery and UI display
- do **not** affect composition

---

## Non-Goals (Explicit)

PersonaKit v1 does **not**:
- execute prompts
- call AI providers
- optimize or rewrite user content
- support inheritance/composition (`extends`, `systemAppend`)
- provide sync, accounts, or telemetry
- infer user intent or auto-correct invalid input

---

## Compatibility and Change Control

Any change that affects composition semantics or determinism:
- requires updating this document
- must include explicit tests
- must keep app and CLI behavior identical

If a change makes the product feel “clever,” it is likely out of scope.

---

## Done-Enough Criteria

PersonaKit v1 is “done enough” when:
- prompts never surprise you
- schema errors are obvious and boring
- deterministic outputs are trusted without rereading
- the app feels stable and unexciting
