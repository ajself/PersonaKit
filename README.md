# PersonaKit

You told the agent to stay read-only. It edited anyway.

PersonaKit is a session-start layer between you and your coding agent. Before work begins it resolves a contract you can
inspect, commit, and hand off: who is acting, what is allowed, what is forbidden, and when to stop.

Availability is not authorization. A tool being reachable does not mean it should run in this session. The contract
decides.

A session bundles role, rules, references, stop points, and capability boundaries into exportable Markdown:

```bash
personakit export --session <id> --copy
```

PersonaKit prepares, validates, inspects, and exports the contract. Your coding agent does the work.

PersonaKit is not an agent, launcher, workflow engine, task manager, memory system, or orchestration layer. It is not
trying to be better memory or a bigger prompt. It is the contract layer that says which work mode is active, which
capabilities are allowed, which actions are forbidden, and when the agent must stop.

For a guided overview, examples, and conceptual documentation, use the [PersonaKit
website](https://ajself.github.io/PersonaKit/). Its [Learn page](https://ajself.github.io/PersonaKit/learn/) shows how
PersonaKit compares to prompts, skills, memory, the Managed Agents API, and MCP. The site also includes a host-skill
example for resolving PersonaKit sessions from autocomplete-friendly agent surfaces.

If you are an AI coding agent encountering PersonaKit for the first time, read
[Docs/agent-guide.md](./Docs/agent-guide.md): how to orient (`personakit guidance`), which surface to use, and what
PersonaKit deliberately leaves to your host.

## What PersonaKit Does

Use PersonaKit when the same AI coding setup keeps appearing in prompts:

- "Act as this kind of engineer."
- "Follow these project rules."
- "Use these references."
- "Do not deploy, persist state, or broaden scope."
- "Stop here for review."

Instead of rebuilding that setup in chat, define a session once. PersonaKit then composes the reusable pieces, validates
the authored content, inspects the resolved contract, and exports handoff context when a coding agent needs it.

## Quick Start

The Makefile is the repo command surface:

```bash
make help
```

Build the CLI:

```bash
make build
```

Install the CLI locally:

```bash
make cli-install INSTALL_BIN_DIR="$HOME/.local/bin"
```

Make sure the install directory is on your `PATH`, then check the CLI:

```bash
personakit --help
```

Validate the public starter root:

```bash
personakit validate --root Examples/public-starter/.personakit
```

Inspect the resolved contract:

```bash
personakit contract --root Examples/public-starter/.personakit --session solo-dev
```

Export the handoff context as Markdown:

```bash
personakit export --root Examples/public-starter/.personakit --session solo-dev
```

Copy the handoff context for your coding agent:

```bash
personakit export --root Examples/public-starter/.personakit --session solo-dev --copy
```

Ask for a session recommendation when the right session is not obvious:

```bash
personakit recommend --root Examples/public-starter/.personakit --goal "Make a small, reviewable CLI improvement"
```

## Create A Root

PersonaKit authored content usually lives in `.personakit/` inside a project. Global content may live in
`~/.personakit/`.

```text
FooBarProject/
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

Create starter content:

```bash
mkdir -p /tmp/personakit-demo
personakit init /tmp/personakit-demo/.personakit
personakit validate --root /tmp/personakit-demo/.personakit
personakit export --root /tmp/personakit-demo/.personakit --session solo-dev --copy
```

`personakit init` refuses to replace a non-empty destination by default. Use `--force` only when you intentionally want
to replace an existing starter root:

```bash
personakit init /tmp/personakit-demo/.personakit --force
```

## Core Model

```text
Persona + Directive + Kits + Intents + Essentials + Skill authorization = Operating contract
```

- **Persona**: who is acting.
- **Directive**: what kind of work is being done, and when to stop.
- **Kits**: rules that travel across related sessions.
- **Intents**: reusable decision rails; patterns that belong in more than one lane.
- **Essentials**: required Markdown grounding that always makes it into the contract.
- **Skills**: capability metadata used for authorization.
- **Session**: the named entry point that ties the pieces together.

Sessions are the situational work modes. Broad repo guidance such as `AGENTS.md` can still describe the project's
default operating rules; a PersonaKit session selects the active contract for this specific handoff.

Authored PersonaKit JSON files are checked against JSON schemas and carry explicit version fields. That keeps packs
reviewable as project source and lets the CLI validate structure before a contract is exported.

Example session:

```json
{
  "id": "solo-dev",
  "personaId": "solo-developer",
  "directiveId": "small-cli-change"
}
```

Skills describe capabilities and risk. They are not commands PersonaKit runs.

## Command Surface

Validate, inspect, and export:

```text
personakit validate
personakit contract --session <id>
personakit export --session <id>
personakit export --session <id> --copy
personakit export --session <id> --output <path>
```

Author PersonaKit content:

```text
personakit init <path>
personakit create <subcommand>
```

Discover and visualize:

```text
personakit guidance
personakit recommend --goal "<task>"
personakit list personas|kits|directives|intents|skills|essentials|sessions
personakit graph --session <id>
personakit refs <id>
personakit orphans
personakit resolve-references --session <id>
```

Integrate with MCP clients:

```text
personakit mcp
```

PersonaKit should stay focused on validation, deterministic resolution, inspection, export, and read-only grounding.

## Use With AI Agents

The quickest way to put PersonaKit in an agent's toolbox is the read-only MCP server. Register it once and the agent can
discover and resolve contracts live, in every session, without pasting anything into the prompt.

Claude Code, one command (user scope, available in every project):

```bash
claude mcp add personakit --scope user -- "$(which personakit)" mcp
```

Confirm it connected:

```bash
claude mcp list
```

For Cursor, GitHub Copilot, Codex, VS Code, OpenCode, and the generic stdio shape, use the per-host config table in
[Docs/mcp.md](./Docs/mcp.md).

Once connected, an agent grounds itself by reading `personakit://catalog/start`, then resolving a session. With no MCP
server connected, the same grounding is one CLI call away: `personakit guidance`. A resolved contract is not a locked
door; it is a map: the cleared space to work in, and the marked edge where the agent re-grounds or asks rather than
barreling through or stopping dead.

### Add A Grounding Skill (optional)

The MCP server gives the agent access. A small host skill gives it the instinct to reach for PersonaKit at the right
moment: resolve the active contract before choosing tools, skills, or files. `personakit init` scaffolds a host-neutral
`personakit-grounding/SKILL.md`; per-host variants (Claude Code, Cursor, Copilot, OpenCode) live in the grounding
tutorial on the [PersonaKit website](https://ajself.github.io/PersonaKit/). Copy the variant for your host into the
directory it discovers skills from. For Claude Code that is `.claude/skills/`. PersonaKit never writes into a host
config directory for you.

### Point A Cold Agent At PersonaKit (optional)

An agent that does not know PersonaKit exists will not look for it. If your project keeps an `AGENTS.md`, a short
breadcrumb tells a cold agent where to orient. This snippet is opt-in; PersonaKit does not scaffold it into your repo:

```markdown
## PersonaKit

This project uses PersonaKit for operating contracts. Before starting work,
run `personakit guidance` (or read `personakit://catalog/start` when the
PersonaKit MCP server is connected) to resolve the active session contract:
role, rules, allowed capabilities, forbidden actions, and stop points.
```

## Studio And MCP

PersonaKit Studio is a local GUI for managing packs and sessions. Use it when you want a visual administration surface
alongside the CLI and MCP flows.

For repository development, `make studio-review` builds Studio, opens deterministic demo workspaces, and captures
screenshots under `.build/studio-review/` for operator inspection.

PersonaKit MCP is read-only grounding and provenance:

```bash
personakit mcp
```

MCP does not authorize execution, file writes, shell commands, workflow orchestration, memory, or autonomous planning.

More detail: [Docs/mcp.md](./Docs/mcp.md).

## Repository Work

Run the public verification gate before public-facing changes:

```bash
make public-check
```

Run the package tests:

```bash
make test
```

Use `make test` rather than a bare `swift test`: the CLI tests capture stdout/stderr by redirecting process-global file
descriptors, which races against the test runner's own output under parallel execution. `make test` passes
`--no-parallel` (see `SWIFT_TEST_FLAGS` in the [Makefile](./Makefile)) to keep runs deterministic. A bare `swift test`
will intermittently fail with a JSON-decode error; add `--no-parallel` if you must run it directly.

Check formatting:

```bash
make format-check
```

For AI assistants working in this repository, [AGENTS.md](./AGENTS.md) is the repo-local authority for behavior, scope,
and approval boundaries.

## License

PersonaKit is released under the MIT license.

PersonaKit wins by being narrow, predictable, and useful.
