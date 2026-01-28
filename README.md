# PersonaKit

PersonaKit is a **local, deterministic, boring-by-design macOS utility for persona-based prompt composition**.

It exists to help engineers and technical creators preserve intent when switching mental modes without prompt drift or accidental inconsistency.

* Reviewer
* Critic
* Designer
* Explainer
* and so on...

PersonaKit does not:

* talk to AI providers.
* execute prompts.
* optimize or rewrite your work.

---

## Quick Start (under 2 minutes)

### App
```bash
swift run PersonaKitApp
```
1) Select a persona in the left sidebar.  
2) Open the inspector and fill **Context**, **Evidence**, and **Task**.  
3) Use the Prompt/JSON toggle in the main pane, then copy the prompt.

### CLI
```bash
swift run personakit list
swift run personakit compose --persona senior-ios-engineer --context "Repo: PersonaKit" --evidence "Determinism tests" --task "Review changes"
```

The built-in pack is included, so both commands work out of the box.


---

## What PersonaKit Is

PersonaKit treats personas as first-class, file-based objects.

Each persona:
- is defined in human-readable JSON
- is validated against a versioned schema
- produces deterministic, structured prompts
- behaves identically across the app and CLI

PersonaKit is designed for people who:
- reuse prompts across time and tools
- care about consistency more than cleverness
- want predictable, boring reliability

If you’ve ever re-run a “known good” prompt and wondered why it felt different, PersonaKit is for you.

---

## What PersonaKit Is Not

PersonaKit is intentionally *not*:

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

The value of PersonaKit isn't the prompt text; it's a reliable mental-mode switch.

PersonaKit prevents:
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

PersonaKit is split into three parts:

### PersonaKitCore
A Swift library that provides:
- Codable persona models
- schema validation
- deterministic prompt composition
- pack loading and resolution

### PersonaKitApp (macOS)
A native macOS app that provides:
- sidebar browsing and filtering
- prompt/JSON output preview
- an inspector for parameters and persona metadata
- confidence through visibility

### personakit (CLI)
A command-line tool that:
- loads persona packs
- composes prompts deterministically
- mirrors app behavior exactly

The app exists for confidence and inspection.  
The CLI exists for repeatability and automation.

---

## Prompt Structure

PersonaKit enforces a structured prompt format.

Sections are:
- explicit
- ordered
- deterministic

This structure is intentional.  
Free-form prompts are not supported in v1.

PersonaKit is opinionated about structure, flexible about content, and neutral about tone.

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

PersonaKit operates entirely locally.

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

PersonaKit uses a **versioned JSON schema**.

- Schema v1 is stable
- Future schema versions will be explicit
- Backward compatibility is not implied without versioning

This is a tool, not a promise to support everything forever.

---

## Installation & Running

### App (SwiftPM)
```bash
swift run PersonaKitApp
```

### CLI
```bash
swift run personakit list
swift run personakit compose --persona <id> --context "Example" --evidence "Example" --task "Example"
```
Other section flags (`--goal`, `--constraints`) are optional when a persona defines them.

## Loading the Example Pack in the App
The app loads built-ins automatically. To load the example pack from `Examples/`:
1) Copy `Examples/personakit.pack.json` to `~/Library/Application Support/PersonaKit/Packs/`
2) Click **Reload** in the app toolbar

---

## Development Standards

PersonaKit follows the project style guide at `Docs/Standards/SwiftUI-App-Style-Guide.md`.

Highlights:
- Swift 6.2 language mode with strict concurrency checks where practical.
- Explicit feature models (`@Observable`) with direct method calls; no `State`/`Action` routing.
- Dependencies routed through `pointfreeco/swift-dependencies` (no direct `Date()`, `UUID()`, or `Task.sleep` in feature logic).
- Shared logic lives in `PersonaKitCore` so the app and CLI stay behavior-identical.

### Formatting
```bash
swift-format --configuration swift-format.json --in-place Sources Tests
```

### Linting
```bash
swiftlint --config .swiftlint.yml
```

---

## When PersonaKit Is “Done Enough”

PersonaKit is considered complete when:

- the CLI causes no anxiety
- prompt previews never surprise you
- schema errors are boring and obvious
- outputs are trusted without rereading
- the app feels stable and unexciting

If it feels clever, it is not done.

## Project Contracts

PersonaKit intentionally documents its constraints.

If you are contributing, using automation, or proposing changes, please read:

- **[PersonaKit v1 Scope & Contract](Docs/PersonaKit_v1_Scope_and_Contract.md)**  
  Defines what PersonaKit v1 *is*, *is not*, and when it is considered “done enough”.

- **[PersonaKit 2.0 Codex Prompt Pack](Docs/PersonaKit_2_0_Prompt_Pack_Index.md)**  
  Defines the allowed 2.0 work units, execution order, and acceptance criteria.

- **[AGENTS.md](AGENTS.md)**  
  Defines how automated agents (including Codex) and contributors should interact with the codebase.

  Staged refactor milestones with context and acceptance criteria for new agent sessions.

These documents take precedence over issues, pull requests, or feature ideas.

---

## Open Source

PersonaKit is open source with an MIT-style mindset.

Contributions are welcome, but:
- scope is intentionally narrow
- not every feature request will be accepted
- long-term maintainability matters more than growth

Please read `Docs/PersonaKit_v1_Scope_and_Contract.md` before proposing large changes.

---

## License

MIT
