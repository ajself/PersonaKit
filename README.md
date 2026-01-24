# PersonaPad

PersonaPad is a **local, deterministic, boring-by-design macOS utility for persona-based prompt composition**.

It exists to help engineers and technical creators preserve intent when switching mental modes without prompt drift or accidental inconsistency.

* Reviewer
* Critic
* Designer
* Explainer
* and so on...

PersonaPad does not:

* talk to AI providers.
* execute prompts.
* optimize or rewrite your work.

---

## Quick Start (under 2 minutes)

### App
```bash
swift run PersonaPadApp
```
1) Select a persona in the left sidebar.  
2) Open the inspector and fill **Context**, **Evidence**, and **Task**.  
3) Use the Prompt/JSON toggle in the main pane, then copy the prompt.

### CLI
```bash
swift run personapad list
swift run personapad compose --persona senior-ios-engineer --context "Repo: PersonaPad" --evidence "Determinism tests" --task "Review changes"
```

The built-in pack is included, so both commands work out of the box.


---

## What PersonaPad Is

PersonaPad treats personas as first-class, file-based objects.

Each persona:
- is defined in human-readable JSON
- is validated against a versioned schema
- produces deterministic, structured prompts
- behaves identically across the app and CLI

PersonaPad is designed for people who:
- reuse prompts across time and tools
- care about consistency more than cleverness
- want predictable, boring reliability

If you’ve ever re-run a “known good” prompt and wondered why it felt different, PersonaPad is for you.

---

## What PersonaPad Is Not

PersonaPad is intentionally *not*:

- an AI chat client
- an execution or runtime environment
- a cloud-synced service
- a collaboration or sharing tool
- a prompt optimizer or enhancer
- a marketplace or platform
- a persona inheritance/composition system

If it executes, syncs, optimizes, or phones home — it is out of scope.

---

## Core Idea

The value of PersonaPad isn't the prompt text; it's a reliable mental-mode switch.

PersonaPad prevents:
- accidental persona drift
- loss of intent between tools
- inconsistent prompt composition
- subtle changes caused by copy/paste reuse

It succeeds when:
- you stop rewriting prompts manually
- outputs are trusted without second-guessing
- using it feels dull — in a good way

---

## What’s Included

PersonaPad is split into three parts:

### PersonaPadCore
A Swift library that provides:
- Codable persona models
- schema validation
- deterministic prompt composition
- pack loading and resolution

### PersonaPadApp (macOS)
A native macOS app that provides:
- sidebar browsing and filtering
- prompt/JSON output preview
- an inspector for parameters and persona metadata
- confidence through visibility

### personapad (CLI)
A command-line tool that:
- loads persona packs
- composes prompts deterministically
- mirrors app behavior exactly

The app exists for confidence and inspection.  
The CLI exists for repeatability and automation.

---

## Prompt Structure

PersonaPad enforces a structured prompt format.

Sections are:
- explicit
- ordered
- deterministic

This structure is intentional.  
Free-form prompts are not supported in v1.

PersonaPad is opinionated about structure, flexible about content, and neutral about tone.

---

## Persona Metadata (Discovery Only)

Personas can include lightweight metadata used only for discovery:
- `tags`: an optional array of strings
- `description`: a short human-readable "about" blurb

These fields are used for search/filtering in the macOS app and do **not** affect
prompt composition or output.

Example:
```json
{
  "id": "senior-ios-engineer",
  "name": "Senior macOS/iOS Engineer",
  "tags": ["swift", "code-review"],
  "description": "Pragmatic pair engineer; minimal diffs."
}
```

---

## Local-First by Design

PersonaPad operates entirely locally.

- No network access
- No accounts
- No analytics
- No tracking

Persona files are meant to:
- live in version control
- be shared manually if desired
- remain portable across tools

---

## Schema Stability

PersonaPad uses a **versioned JSON schema**.

- Schema v1 is stable
- Future schema versions will be explicit
- Backward compatibility is not implied without versioning

This is a tool, not a promise to support everything forever.

---

## Installation & Running

### App (SwiftPM)
```bash
swift run PersonaPadApp
```

### CLI
```bash
swift run personapad list
swift run personapad compose --persona <id> --context "Example" --evidence "Example" --task "Example"
```
Other section flags (`--goal`, `--constraints`) are optional when a persona defines them.

## Loading the Example Pack in the App
The app loads built-ins automatically. To load the example pack from `Examples/`:
1) Copy `Examples/personapad.pack.json` to `~/Library/Application Support/PersonaPad/Packs/`
2) Click **Reload** in the app toolbar

---

## When PersonaPad Is “Done Enough”

PersonaPad is considered complete when:

- the CLI causes no anxiety
- prompt previews never surprise you
- schema errors are boring and obvious
- outputs are trusted without rereading
- the app feels stable and unexciting

If it feels clever, it is not done.

## Project Contracts

PersonaPad intentionally documents its constraints.

If you are contributing, using automation, or proposing changes, please read:

- **[PersonaPad v1 Scope & Contract](Docs/PersonaPad_v1_Scope_and_Contract.md)**  
  Defines what PersonaPad v1 *is*, *is not*, and when it is considered “done enough”.

- **[PersonaPad 2.0 Codex Prompt Pack](Docs/PersonaPad_2_0_Prompt_Pack_Index.md)**  
  Defines the allowed 2.0 work units, execution order, and acceptance criteria.

- **[AGENTS.md](AGENTS.md)**  
  Defines how automated agents (including Codex) and contributors should interact with the codebase.

These documents take precedence over issues, pull requests, or feature ideas.

---

## Open Source

PersonaPad is open source with an MIT-style mindset.

Contributions are welcome, but:
- scope is intentionally narrow
- not every feature request will be accepted
- long-term maintainability matters more than growth

Please read `Docs/PersonaPad_v1_Scope_and_Contract.md` before proposing large changes.

---

## License

MIT
