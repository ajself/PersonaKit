PersonaKit

PersonaKit is an execution-free system for structuring AI work around real professional roles.

It helps you work with AI agents the same way you work with people on a strong team: clear roles, explicit constraints, shared standards, and well-defined directives — without automation magic or hidden behavior.

If you’ve ever thought “this agent is smart, but it doesn’t work the way we do”, PersonaKit is for you.

## Current Direction

PersonaKit remains the engine and context system in this repository.

The forward product direction now being explored in-repo is **Orbit**: a
workspace-centric command center for running persistent AI teams. In that
direction:

- Orbit is the product/platform surface
- PersonaKit is the identity, directive, and grounding engine inside Orbit

That means this repository currently contains both:

- stable PersonaKit engine/runtime documentation
- newer Orbit product, architecture, and planning documents

For the clearest current product direction, start in `Docs/Orbit/`.

⸻

The mental model (60 seconds)

PersonaKit assembles context by combining **who** is working with **what** they are doing, using shared standards.

Think in questions, not files:
- **Persona** — Who is doing the work?
- **Kits** — How do we do things here?
- **Directive** — What needs to be done now?
- **Essentials** — What rules or references must always be followed?
- **Session** — This exact situation (Persona + Directive, with optional overrides).

A Session is not a workflow or runtime. It’s simply the result of combining inputs into a single, deterministic context.

⸻

Quick start: from zero to grounded agent (5 minutes)

This is the shortest path to using PersonaKit for real work.

Scenario: you want an AI agent to review a SwiftUI change as a **Senior SwiftUI Engineer**, following your Swift and SwiftUI style guides, without inventing scope.

1) Have a `.personakit/` directory

In your project root:

```
.project/
  .personakit/
    Packs/
      personas/
      directives/
      kits/
      intents/
      skills/
      essentials/
```

PersonaKit will also load `~/.personakit/` if it exists and merge both scopes (project overrides global).

2) Validate

From the project root:

```
personakit validate
```

If validation fails, stop here and fix the first error.

3) Discover available IDs (optional)

```
personakit list personas
personakit list directives
```

This tells you exactly which IDs are valid.

4) Export the session context (CLI)

```
personakit export \
  --persona senior-swiftui-engineer \
  --directive apply-style
```

This output is the canonical session context—paste it into an agent or consume it via MCP.

With a Session in place, you can export the same context more simply:

```
personakit export --session review-swiftui
```

4a) Save this pairing as a Session (optional, recommended)

If you find yourself using the same Persona + Directive repeatedly, you can save that pairing as a Session.

Create a file under `Sessions/`:

```
Sessions/review-swiftui.session.json
```

```json
{
  "id": "review-swiftui",
  "personaId": "senior-swiftui-engineer",
  "directiveId": "apply-style"
}
```

A Session is a named shortcut for a Persona + Directive pairing. It introduces no new behavior.

For you, this means:
- fewer flags to remember
- a stable name you can reuse across tools

For the agent, this means:
- a consistent, repeatable context
- no ambiguity about which Persona or Directive is active

Architectural Editor sessions (project example):

```
personakit export --session architectural-editor-review
personakit export --session architectural-editor-prompt-review
```

These pair the `architectural-editor` persona with directive-specific review flows:
- `architectural-editor-review` → `review-architecture-invariants`
- `architectural-editor-prompt-review` → `review-implementation-prompts`

5) Use MCP instead of copy/paste (optional)

Start the MCP server from the project directory:

```
personakit mcp
```

Configure your MCP client (example):

```json
{
  "mcpServers": {
    "personakit": {
      "command": "personakit",
      "args": ["mcp"]
    }
  }
}
```

Your agent can now read PersonaKit resources and prompts directly.

No copy/paste is required, and the agent always sees the same context as the CLI.

6) Ground the agent (one line)

When you prompt an agent, give it a one-line grounding cue:

```
Ground with PersonaKit: senior-swiftui-engineer / apply-style
```

Or, if you are using a Session:

```
Ground with PersonaKit: review-swiftui
```

Then ask for the work you want done.

At this point, the agent is fully grounded. You can now ask for work—reviews, refactors, explanations—without restating roles, rules, or constraints.

⸻

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

Persona (who)
+ default Kits (how)
+ Directive (what)
------------------
Session (assembled context)

A Session is the assembled context that an agent consumes. It’s derived, not authored.

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

If you can explain a piece of work in plain English, it belongs in a Directive.

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

Creating new Directives and Sessions (fast path)

You don’t need generators or special commands.

To create a new Directive:
- Copy an existing file in `Packs/directives/`
- Rename it
- Edit the words

To create a Session (optional convenience):
- Create a file in `Sessions/` that names a Persona and a Directive

Sessions are shortcuts. If you don’t need one, you can always export directly with `--persona` and `--directive`.

⸻

Using PersonaKit

PersonaKit provides two ways to consume context.

Swift CLI

personakit init <path>
personakit validate [--root <path>] [--no-project] [--no-global]
personakit export [--root <path>] [--no-project] [--no-global] --persona <id> --directive <id>
personakit list [--root <path>] [--no-project] [--no-global] personas|kits|directives|intents|skills|essentials|sessions
personakit graph [--root <path>] [--no-project] [--no-global] --persona <id> --directive <id>
personakit mcp [--root <path>] [--no-project] [--no-global]

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

Basic setup (default, recommended):

1. Choose a project directory that contains `.personakit/` (project scope), or ensure `~/.personakit` exists (global scope).

2. Start the MCP server:

   personakit mcp

3. Configure your MCP-compatible agent or client to connect to the server via stdio.

Example MCP client configuration

Most MCP-compatible clients connect to servers using a JSON configuration file that declares how the server is launched.

A minimal example (stdio transport):

```json
{
  "mcpServers": {
    "personakit": {
      "command": "personakit",
      "args": ["mcp"]
    }
  }
}
```

Notes:
- `command` and `args` must launch `personakit mcp`.
- MCP scope resolution is local-first and single-scope:
  1) `--root <path>` (highest priority)
  2) `PERSONAKIT_ROOT`
  3) local project `.personakit`
  4) `~/.personakit`
  5) fail if none are available
- `PERSONAKIT_ROOT` must point to a PersonaKit root containing `Packs/`.
- `PERSONAKIT_ROOT_OVERRIDE=1` remains supported and requires `PERSONAKIT_ROOT`.
- MCP loads only one scope (project or global). It does not merge both scopes.
- Use `--no-project` or `--no-global` to disable fallback steps in discovery.
- The server communicates over **stdio**; no ports are opened.
- Paths should be absolute to avoid ambiguity.

Example: force local project identity context

```json
{
  "mcpServers": {
    "personakit": {
      "command": "personakit",
      "args": ["mcp", "--root", "/Users/ajself/Code/PersonaKit/.personakit"]
    }
  }
}
```

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
