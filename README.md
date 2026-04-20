# PersonaKit

PersonaKit eliminates prompt setup before using AI tools.

PersonaKit V1 is for solo developers to invoke AI coding tasks with consistent, reusable context without rebuilding that context every session.

It is not an agent, planner, memory system, or workflow platform. PersonaKit resolves known context and launches work with that context applied.

## Current Direction

PersonaKit V1 is focused on one core workflow:

```bash
personakit run --session <id> --agent <agent> -- "<task>"
```

That command:

- resolve reusable context from a named session
- assemble deterministic runtime context from PersonaKit data
- launch one supported AI agent with that context applied
- remove the need for manual copy/paste prompt setup

If a feature does not directly support that workflow, it is out of scope for V1.

For the active product direction, read `Docs/V1_DIRECTION.md`.

## What PersonaKit Is

PersonaKit is a context resolver and launcher for AI work.

It helps you define and reuse:

- **Persona** — who is doing the work
- **Kits** — how that role works
- **Directive** — what kind of work is being done
- **Essentials** — rules and references that must be present
- **Session** — a named pairing of persona + directive, with optional overrides

PersonaKit resolves those inputs into deterministic runtime context so you do not have to restate them every time you start an agent task.

## What PersonaKit Is Not

PersonaKit is deliberately not:

- an agent
- a workflow engine
- a memory platform
- a remote orchestration system
- a task management product
- a replacement for your coding agent

PersonaKit prepares context. Another tool performs the work.

## V1 Product Principles

- boring over clever
- explicit over inferred
- deterministic over magical
- local workflow first
- one sharp workflow over many partial ones

If a proposed feature violates these principles, it does not belong in V1.

## V1 Scope

In scope:

- session-based context resolution
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

> PersonaKit resolves reusable professional context so an AI agent can start work already grounded.

The core model is:

```text
Persona (who)
+ Kits (how)
+ Directive (what kind of work)
+ Essentials (must-include grounding)
= Session context
```

A session is the practical entry point for V1. It gives a stable name to a context pairing you want to reuse.

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

### 3. Export a session manually when needed

```bash
personakit export --session review-swiftui
```

This is useful for inspection and debugging.

To copy the stitched prompt directly to the clipboard:

```bash
personakit export --session review-swiftui --copy
```

### 4. Run work with grounded context

```bash
personakit run --session review-swiftui --agent opencode -- "Review the current SwiftUI change and propose the smallest safe refactor."
```

That is the intended V1 experience: one command, known context, one live task.

## Sessions

A session is a named shortcut for reusable context.

Example:

```json
{
  "id": "review-swiftui",
  "personaId": "senior-swiftui-engineer",
  "directiveId": "apply-style"
}
```

Sessions are important in V1 because they reduce setup friction and give you a stable entry point across tools.

## CLI Surface

Current CLI commands:

```text
personakit validate
personakit export --session <id>
personakit export --session <id> --copy
personakit list personas|kits|directives|intents|skills|essentials|sessions
personakit graph --session <id>
personakit mcp
personakit run --session <id> --agent <agent> -- "<task>"
```

`run` is the primary product direction for V1.

## MCP

PersonaKit includes a read-only MCP server so compatible tools can read PersonaKit context directly.

```bash
personakit mcp
```

MCP is an integration surface, not the core product story. For V1, focus on deterministic context resolution and the `run` workflow.

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

PersonaKit exists to make expectations explicit and reusable so your tools can start from a known professional operating context instead of improvising from scratch.

## For Agents Working In This Repo

`AGENTS.md` is binding for agent behavior in this repository.

Agents working here must preserve the V1 direction:

- do not introduce memory systems
- do not reintroduce removed platform concepts
- do not expand into workflow orchestration
- do not broaden PersonaKit into a platform product
- prefer reuse of existing resolver and export logic

PersonaKit V1 wins by being narrow, predictable, and useful.
