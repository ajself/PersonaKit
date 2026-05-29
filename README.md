# PersonaKit

PersonaKit eliminates repeated prompt setup before using AI coding tools.

PersonaKit is for solo developers who want one reusable operating contract and one inspectable handoff for their coding tool:

```bash
personakit export --session <id> --copy
```

PersonaKit is not an agent, planner, memory system, task manager, or orchestration layer. It resolves a known contract; your coding agent does the work.

PersonaKit is released under the MIT license.

## First Five Minutes

### Requirements

PersonaKit currently builds with:

- macOS 26 SDK
- Swift tools 6.2
- Xcode 26 or newer

### 1. Build The CLI

From the repository root:

```bash
swift build --product personakit
```

For local development, run commands through SwiftPM:

```bash
swift run personakit --help
```

To install the CLI locally:

```bash
make cli-install INSTALL_BIN_DIR="$HOME/.local/bin"
```

Make sure the install directory is on your `PATH`.

### 2. Validate The Public Starter

This repository includes a minimal public PersonaKit root at `Examples/public-starter/.personakit`.
See [Examples](./Examples/) for why the starter keeps the real `.personakit`
project shape.

```bash
swift run personakit validate --root Examples/public-starter/.personakit
```

### 3. Inspect The Contract

```bash
swift run personakit contract --root Examples/public-starter/.personakit --session solo-dev
```

Use this before handing context to another tool when you want to inspect the resolved persona, directive, kits, skill authorization, and stop points.

### 4. Export The Handoff Context

```bash
swift run personakit export --root Examples/public-starter/.personakit --session solo-dev
```

The export command prints the resolved operating contract as Markdown so you can review it or hand it to your coding tool.

### 5. Copy The Handoff Context

```bash
swift run personakit export --root Examples/public-starter/.personakit --session solo-dev --copy
```

Paste the copied context into the coding tool you use for the actual work.

When you are unsure which session fits a task:

```bash
swift run personakit recommend --root Examples/public-starter/.personakit --goal "Make a small, reviewable CLI improvement"
```

## Create Your Own Root

PersonaKit expects content under `.personakit/` in a project, and may also use `~/.personakit/` for global content.

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

To create starter content in a new or throwaway project:

```bash
mkdir -p /tmp/personakit-demo
swift run personakit init /tmp/personakit-demo/.personakit
swift run personakit validate --root /tmp/personakit-demo/.personakit
swift run personakit export --root /tmp/personakit-demo/.personakit --session solo-dev --copy
```

`personakit init` refuses to replace a non-empty destination by default. Use `--force` only when you intentionally want to replace an existing starter root:

```bash
swift run personakit init /tmp/personakit-demo/.personakit --force
```

## How It Works

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

PersonaKit helps you define and reuse:

- **Persona** — who is doing the work
- **Kits** — how that role works
- **Directive** — what kind of work is being done
- **Essentials** — rules and references that must be present
- **Session** — a named entry point to a resolved operating contract

A session is the practical entry point. It gives a stable name to the contract you want to reuse.

Example:

```json
{
  "id": "solo-dev",
  "personaId": "solo-developer",
  "directiveId": "small-cli-change"
}
```

## CLI Surface

Primary path:

```text
personakit validate
personakit contract --session <id>
personakit export --session <id>
personakit export --session <id> --copy
```

Authoring, inspection, and integration:

```text
personakit init <path>
personakit create <subcommand>
personakit guidance
personakit recommend --goal "<task>"
personakit export --session <id> --output <path>
personakit resolve-references --session <id>
personakit list personas|kits|directives|intents|skills|essentials|sessions
personakit graph --session <id>
personakit mcp
```

Deterministic contract resolution and export are the primary product direction. If a feature does not directly support validation, inspection, handoff context, or read-only MCP grounding, it is out of scope for PersonaKit.

## MCP

PersonaKit includes a read-only MCP server so compatible tools can read PersonaKit context directly.

```bash
personakit mcp
```

MCP is an integration surface, not the core product story. Focus on deterministic contract resolution and exported handoff context.

For unfamiliar MCP clients and AI agents, start with:

1. Read `personakit://catalog/start`.
2. Read `personakit://catalog/sessions` or call `personakit_recommend_session`.
3. Call `personakit_resolve_contract` for the selected session.
4. Call `personakit_trace_session` when you need provenance for persona, directive, kits, skills, essentials, and references.
5. Read raw pack or essential resources only as needed.

PersonaKit MCP is read-only grounding. It does not authorize execution, write files, run shell commands, add orchestration, add memory, or perform autonomous planning.

More detail: [Docs/mcp.md](./Docs/mcp.md).

## Studio Status

Studio is available in the repository as a GUI for managing PersonaKit packs and sessions. Use it when you want a local visual administration surface alongside the CLI and MCP flows.

Use `make studio-review` to build the app, launch deterministic demo workspaces, and capture screenshots under `.build/studio-review/` for human inspection. The Make targets keep Xcode output under hidden build directories such as `.build/XcodeDerivedData`.

## Product Boundaries

PersonaKit should remain:

- boring over clever
- explicit over inferred
- deterministic over magical
- local workflow first
- one sharp workflow over many partial ones
- inspectable through contract and export flows

PersonaKit is deliberately not:

- an agent
- a workflow engine
- a remote execution platform
- a task management product
- a replacement for your coding agent

PersonaKit activates the contract. Another tool performs the work.

## Repository Status

This repository is focused on the contract and export paths described above.
Use `make public-check` before public-facing changes.

## Contributing

PersonaKit work should preserve the boundaries above. Keep changes focused, deterministic, and covered by `make public-check` when public behavior or examples change.

## For Agents Working In This Repo

`AGENTS.md` is binding for agent behavior in this repository. Use it as the local authority for repo rules and execution boundaries.

PersonaKit wins by being narrow, predictable, and useful.
