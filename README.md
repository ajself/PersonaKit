PersonaKit

PersonaKit is an execution-free system for structuring AI work around real professional roles.

It helps you work with AI agents the same way you work with people on a strong team: clear roles, explicit constraints, shared standards, and well-defined directives — without automation magic or hidden behavior.

If you’ve ever thought “this agent is smart, but it doesn’t work the way we do”, PersonaKit is for you.

⸻

Quick start (CLI + MCP)

PersonaKit is designed to be used with a human in the loop. The typical workflow looks like this:

1. Initialize a kit repository:

   personakit init ./MyKit

2. Edit Personas, Kits, Directives, and Essentials under `Packs/` until they reflect how you actually work.

3. Validate the kit:

   personakit validate --root ./MyKit

4. Consume the session context in one of two ways:

   • CLI export (paste into an agent):
     personakit export --root ./MyKit --persona <persona-id> --directive <directive-id>

   • MCP (recommended for live agent integration):
     - Run the PersonaKit MCP server via `personakit mcp` with PERSONAKIT_ROOT=./MyKit
     - Let your MCP-compatible agent read Resources and Prompts directly
     - Default behavior relies on Swift scope discovery unless override mode is enabled

Agents are expected to *consume* PersonaKit output, not modify it.

What PersonaKit is

PersonaKit lets you define:
	•	Personas — who the agent is supposed to be (a role you would actually hire)
	•	Kits — how that role works (standards, constraints, style, guardrails)
	•	Directives — what work is being done right now

PersonaKit then:
	•	validates everything deterministically
	•	resolves relationships by ID
	•	exports or serves a single, predictable session context

PersonaKit never executes code, runs tools, or makes decisions for you.

⸻

What PersonaKit is not

PersonaKit is deliberately not:
	•	an agent framework
	•	a planner or workflow engine
	•	a skills runtime
	•	an automation system
	•	a replacement for Codex, ChatGPT, or editor agents

PersonaKit prepares context. Agents execute elsewhere.

⸻

The core model (in one minute)

Persona (role)
   ↓ brings
Kit(s) (standards + constraints)
   ↓ applied to
Directive (work to do now)
   ↓
Session context → consumed by an agent

This mirrors how strong engineering teams actually work.

⸻

Personas: real roles, not vibes

A Persona represents a role you would hire for.

Examples:
	•	Senior SwiftUI Engineer
	•	Pragmatic Product Manager
	•	Code Review Physician

A Persona defines:
	•	responsibilities
	•	values and judgment
	•	blind spots and non-goals
	•	default Kits it brings to the job

PersonaKit requires a persona for any session. There is no omniscient “do everything” agent.

⸻

Kits: how work gets done

A Kit is a reusable bundle of professional context.

Kits typically include:
	•	style guides
	•	tools & constraints
	•	environment assumptions
	•	non-goals / anti-patterns
	•	approved intent templates
	•	skill awareness

Kits are composable and reusable across personas.

A Persona defines the role. A Kit defines how that role works.

⸻

Directives: explicit work, no improvisation

A Directive defines the work being done right now.

Directives include:
	•	a concrete goal
	•	ordered steps
	•	acceptance criteria
	•	verification instructions
	•	explicit stop points for review

Directives prevent scope creep and invented plans.

⸻

Intent Templates: repeatable judgment

An Intent Template encodes how a class of work should be approached.

Examples:
	•	Safe Swift refactor
	•	Add tests without behavior changes
	•	Accessibility review

Intent Templates:
	•	are reusable
	•	may be parameterized
	•	reference required standards and skills
	•	never execute anything

They are PersonaKit’s alternative to executable “skills”.

⸻

Skills: descriptive only

PersonaKit acknowledges that agents have capabilities.

A Skill describes:
	•	what a capability is
	•	who provides it
	•	its risk level

Skills:
	•	are metadata only
	•	contain no commands
	•	are never invoked by PersonaKit

PersonaKit describes skills so intent can be explicit and bounded.

⸻

Essentials: ground truth

Essentials are foundational context that is always included.

Typically:
	•	Swift / SwiftUI style guides
	•	tools & constraints
	•	environment assumptions
	•	non-goals

Essentials are included verbatim in exports and MCP prompts.

⸻

Using PersonaKit

PersonaKit provides two ways to consume context.

Swift CLI

personakit init <path>
personakit validate [--root <path>] [--no-project] [--no-global]
personakit export [--root <path>] [--no-project] [--no-global] --persona <id> --directive <id>
personakit list [--root <path>] [--no-project] [--no-global] personas|kits|directives|intents|skills|essentials
personakit graph [--root <path>] [--no-project] [--no-global] --persona <id> --directive <id>

When `--root` is omitted, PersonaKit loads the nearest `.personakit` in the
current directory (project scope) and `~/.personakit` (global scope), merging
with project overrides. Use `--root` to bypass scope discovery, or
`--no-project` / `--no-global` to disable a scope.

The CLI is deterministic, testable, and intended for local workflows.

⸻

MCP Server (read-only)

Configuring the MCP server

The PersonaKit MCP server is provided by the Swift CLI and exposes PersonaKit context over stdio.
See `Docs/MCP/README.md` for a quick setup guide and example client configs.

Important

The Swift CLI and Swift code are the single source of truth for PersonaKit behavior and contracts.
- The Swift MCP server is the supported integration path.
- The legacy Node adapter is deprecated and will be removed after verification.

Basic setup (default, recommended):

1. Choose a project directory that contains `.personakit/` (project scope), or ensure `~/.personakit` exists (global scope).

2. Set a working directory for discovery:

   PERSONAKIT_ROOT=/path/to/your/project

3. Start the MCP server:

   personakit mcp

4. Configure your MCP-compatible agent or client to connect to the server via stdio.

Example MCP client configuration

Most MCP-compatible clients connect to servers using a JSON configuration file that declares how the server is launched.

A minimal example (stdio transport):

```json
{
  "mcpServers": {
    "personakit": {
      "command": "personakit",
      "args": ["mcp"],
      "env": {
        "PERSONAKIT_ROOT": "/absolute/path/to/your/kit"
      }
    }
  }
}
```

Notes:
- `command` and `args` must launch `personakit mcp`.
- In default mode, `PERSONAKIT_ROOT` sets the working directory for Swift scope discovery (project/global).
- To bypass discovery, set `PERSONAKIT_ROOT_OVERRIDE=1` and point `PERSONAKIT_ROOT` at a directory that contains `Packs/`.
- The server communicates over **stdio**; no ports are opened.
- Paths should be absolute to avoid ambiguity.

Once configured, MCP clients can:
- list PersonaKit resources
- read Personas, Kits, Directives, and Essentials
- request session export and graph prompts

No write or execution permissions are granted to the server.

The MCP server is read-only:
- it never writes to the kit
- it never executes external commands

Multiple agents may safely connect to the same kit root concurrently.

Resources (read-only)
	•	personakit://packs/personas/<id>
	•	personakit://packs/kits/<id>
	•	personakit://packs/directives/<id>
	•	personakit://packs/intents/<id>
	•	personakit://packs/skills/<id>
	•	personakit://essentials/<id>

Prompts
	•	personakit.session.export — resolved session context (Markdown)
	•	personakit.session.graph — resolved dependency graph (text)

The MCP server:
	•	is read-only
	•	never executes external commands
	•	enforces deterministic ordering and stable output

This enables copy/paste-free, live integration with MCP-compatible agents while keeping Swift as the single source of truth.

⸻

Determinism & safety

PersonaKit guarantees:
	•	no execution (no subprocesses, no shell calls)
	•	deterministic output
	•	stable ordering
	•	explicit, actionable errors
	•	no hidden state

If it validates, it can be consumed. If it doesn’t validate, it won’t.

⸻

Why this exists

AI tools are powerful, but most fail in the same ways:
	•	style drift
	•	constraint erosion
	•	hallucinated confidence
	•	forgotten decisions

PersonaKit doesn’t try to make agents smarter.

It makes expectations explicit.

⸻

Who this is for

PersonaKit is designed for:
	•	senior and staff-level engineers
	•	people used to working with PMs and designers
	•	teams that care about standards and correctness
	•	anyone new to AI who wants predictability first

⸻

Philosophy
	•	boring over clever
	•	explicit over inferred
	•	structure over autonomy
	•	humans in control

If a feature violates these principles, it’s out of scope.

⸻

Using AI agents responsibly

PersonaKit assumes AI agents are assistants operating under human supervision.

When using PersonaKit with agents:
- Follow the rules defined in AGENTS.md
- Do not allow agents to execute commands autonomously
- Do not allow agents to expand scope beyond the Directive
- Require review at explicit stop points

[AGENTS.md](./AGENTS.md) is considered a binding contract for agent behavior in this repo.

Status

PersonaKit is a complete, execution-free MVP:
	•	CLI
	•	validation
	•	export
	•	discovery (list, graph)
	•	MCP Resources + Prompts

The next step is real-world use, not more abstraction.

⸻

PersonaKit helps AI agents behave like disciplined teammates — without giving up control.
