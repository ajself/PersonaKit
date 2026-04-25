# PersonaKit

PersonaKit eliminates prompt setup before using AI tools.

PersonaKit V1 is for solo developers to invoke AI coding tasks with a deterministic, reusable operating contract instead of rebuilding role, constraints, and grounding every session.

It is not an agent, planner, memory system, or workflow platform. PersonaKit resolves a known operating contract and launches work with that contract applied.

## Current Direction

PersonaKit V1 is focused on one core workflow:

```bash
personakit run --session <id> --agent <agent> -- "<task>"
```

That command:

- resolve a named operating contract from PersonaKit data
- assemble deterministic runtime grounding from that contract
- launch one supported AI agent with that contract applied
- remove the need for manual copy/paste prompt setup

If a feature does not directly support that workflow, it is out of scope for V1.

For the active product direction, read `Docs/V1_DIRECTION.md`.

## What PersonaKit Is

PersonaKit is an operating-contract resolver and launcher for AI work.

It does not just bundle prompt text. It resolves the active role, required grounding, allowed skills, and stop points for the work.

It helps you define and reuse:

- **Persona** — who is doing the work
- **Kits** — how that role works
- **Directive** — what kind of work is being done
- **Essentials** — rules and references that must be present
- **Session** — a named entry point to a resolved operating contract

PersonaKit resolves those inputs into a deterministic operating contract so you do not have to restate them every time you start an agent task.

## What PersonaKit Is Not

PersonaKit is deliberately not:

- an agent
- a workflow engine
- a memory platform
- a remote orchestration system
- a task management product
- a replacement for your coding agent

PersonaKit activates the contract. Another tool performs the work.

## Authority Stack

Use these layers in order:

- `AGENTS.md` constrains local repo behavior.
- PersonaKit activates the current operating contract.
- skills provide authorized procedures.
- tools execute within those repo and contract constraints.

## V1 Product Principles

- boring over clever
- explicit over inferred
- deterministic over magical
- local workflow first
- one sharp workflow over many partial ones

If a proposed feature violates these principles, it does not belong in V1.

## V1 Scope

In scope:

- session-based contract resolution
- deterministic merging of personas, kits, directives, and essentials
- a CLI `run` command
- one agent adapter
- dry-run inspection for debugging and trust

Out of scope:

- memory systems
- multi-session continuity
- remote execution platforms
- workflow orchestration patterns
- Studio expansion beyond basic administration

## Mental Model

Think in one sentence:

> PersonaKit resolves a reusable operating contract so an AI agent can start work already grounded.

The core model is:

```text
Persona (who)
+ Kits (how)
+ Directive (what kind of work)
+ Essentials (must-include grounding)
+ Skill authorization
= Resolved operating contract
```

A session is the practical entry point for V1. It gives a stable name to a contract you want to reuse.

## Quick Start

### 1. Create or locate a PersonaKit root

PersonaKit expects PersonaKit content under `.personakit/` in a project, and may also use `~/.personakit/` for global content.

Example:

```text
.project/
  .personakit/
    Packs/
      personas/
      kits/
      directives/
      intents/
      skills/
      essentials/
    Sessions/
```

### 2. Validate your authored data

```bash
personakit validate
```

If validation fails, fix the first error before moving on.

### 3. Choose a session when the lane is not obvious

```bash
personakit recommend --goal "Review the current SwiftUI change"
```

Use this when you are unsure which session best fits the task.

### 4. Inspect a session contract manually when needed

```bash
personakit contract --session architectural-editor-review
```

This is useful when you want to inspect the resolved role, skill authorization, and stop points directly.

### 5. Export a session manually when needed

```bash
personakit export --session architectural-editor-review
```

This renders a human-readable prompt form of the resolved contract. It is useful for inspection and debugging.

To copy the stitched prompt directly to the clipboard:

```bash
personakit export --session architectural-editor-review --copy
```

### 6. Run work with grounded context

```bash
personakit run --session architectural-editor-review --agent opencode -- "Review the current SwiftUI change and propose the smallest safe refactor."
```

That is the intended V1 experience: one command, known context, one live task.

To copy the dry-run payload instead of printing it:

```bash
personakit run --session architectural-editor-review --agent opencode --dry-run --copy -- "Review the current SwiftUI change and propose the smallest safe refactor."
```

## Sessions

A session is a named shortcut for a reusable operating contract.

Example:

```json
{
  "id": "architectural-editor-review",
  "personaId": "architectural-editor",
  "directiveId": "review-architecture-invariants"
}
```

Sessions are important in V1 because they reduce setup friction and give you a stable entry point across tools.

## CLI Surface

Current CLI commands:

```text
personakit validate
personakit recommend --goal "<task>"
personakit contract --session <id>
personakit export --session <id>
personakit export --session <id> --copy
personakit list personas|kits|directives|intents|skills|essentials|sessions
personakit graph --session <id>
personakit mcp
personakit run --session <id> --agent <agent> -- "<task>"
personakit run --session <id> --agent <agent> --dry-run --copy -- "<task>"
```

`run` is the primary product direction for V1.

## MCP

PersonaKit includes a read-only MCP server so compatible tools can read PersonaKit context directly.

```bash
personakit mcp
```

MCP is an integration surface, not the core product story. For V1, focus on deterministic contract resolution and the `run` workflow.

## Safety And Determinism

PersonaKit should remain:

- execution-light in its core context model
- deterministic in output ordering and resolution
- explicit in failures
- inspectable through export and dry-run flows

If a feature makes PersonaKit feel magical, hidden, or difficult to trust, it is probably the wrong feature.

## Repository Status

This repository is being actively simplified around the V1 direction.

That means:

- PersonaKit is the product
- `Docs/V1_DIRECTION.md` is the active direction document
- older exploratory directions that do not support V1 should be treated as non-authoritative or removed
- Studio is paused for V1

## Why This Exists

AI tools are powerful, but repeated context setup is tedious and error-prone.

PersonaKit exists to make expectations explicit and reusable so your tools can start from a known professional operating contract instead of improvising from scratch.

## For Agents Working In This Repo

`AGENTS.md` is binding for agent behavior in this repository. Use it as the local authority for repo rules and execution boundaries.

PersonaKit V1 wins by being narrow, predictable, and useful.
