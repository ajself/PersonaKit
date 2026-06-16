# PersonaKit For Agents

## Why This Exists

This guide is for an AI coding agent encountering PersonaKit in a project for the
first time. It tells you what PersonaKit is, how to orient yourself, which surface
to use, and — just as important — what PersonaKit deliberately does *not* do, so
you don't waste effort building workarounds for responsibilities that belong
elsewhere.

If you are an agent doing ordinary work *inside the PersonaKit repository itself*,
read [AGENTS.md](../AGENTS.md) instead. That file is repo-local policy. This file
is about *consuming* PersonaKit from any host.

## The One Mental Model

**A PersonaKit contract is authoritative intent. Enforcement is the host or
sandbox.**

PersonaKit resolves a deterministic operating contract — who to act as, what work
mode is active, which capabilities are allowed, which are forbidden, and where to
stop — and exports it as inspectable text. PersonaKit does not run anything, watch
anything, or enforce anything. It states what *should* be true; your host decides
what actually happens.

Every other question in this guide follows from that one sentence. When in doubt:
the contract describes intent; you and your host carry it out.

## Orient Yourself First

Do not start by guessing what exists. PersonaKit content can come from a project
`.personakit/` directory, a global `~/.personakit/`, or both merged together — and
you usually cannot tell which from the file tree alone. Ask the tool.

**CLI — run this first:**

```bash
personakit guidance
```

It returns a deterministic JSON payload describing the resolved scope
(`projectRoot`, `globalRoot`, `loadOrder`, `resolutionOrder`), entity counts,
risks (e.g. "current directory contains a project `.personakit` not in the loaded
scope set"), suggested next actions, and suggested commands. This is the "start
here" command. Treat it as your map before you trust anything else.

If `guidance` reports a scope mismatch — the most common surprise — control which
root loads with `--root <path>` (or disable discovery with `--no-project` /
`--no-global`). These scope flags work on every command, so once you know the
intended root you can pin it explicitly: `personakit validate --root <path>`,
`personakit contract --root <path> --session <id>`, and so on.

**MCP — read this first:**

```text
personakit://catalog/start
```

The MCP server's own startup hint is literally "Read `personakit://catalog/start`
first." From there: `personakit://catalog/sessions` (or call
`personakit_recommend_session`), then resolve.

## Which Surface: CLI or MCP

Both surfaces expose the same deterministic engine. Use whichever your host has
connected:

- If a PersonaKit **MCP server is connected**, prefer it — `personakit://catalog/*`
  resources and the `personakit_*` tools give you structured grounding without
  shelling out.
- If **no MCP server is connected** (the common case in a fresh host — PersonaKit
  does not auto-connect anywhere), use the **CLI**. Start with `personakit guidance`.

Neither surface authorizes execution, writes, or orchestration. MCP in particular
is read-only by design.

## The Normal Flow

1. `personakit guidance` (CLI) or read `personakit://catalog/start` (MCP) — orient.
2. List or recommend a session: `personakit list sessions`, or
   `personakit recommend --goal "<task>"`.
3. Resolve the contract: `personakit contract --session <id>`.
4. Export handoff context when you need it as Markdown:
   `personakit export --session <id>` (add `--copy` or `--output <path>`). Add
   `--stats` to print a size summary (lines / bytes / sections) to stderr when you
   need to budget the payload — it leaves the exported Markdown on stdout untouched.
5. Inspect provenance if a constraint surprises you:
   `personakit graph --session <id>`.

If validation fails for the relevant contract, stop and re-ground rather than
improvising. If a contract does not authorize a skill you need, stop and
re-ground — do not grant yourself the capability.

## Which Entity Is Which

When you author or read packs, these are the building blocks:

| Entity | Answers | Lives in |
| --- | --- | --- |
| **Persona** | Who should the agent act as? (responsibilities, values, non-goals, allowed/forbidden skills) | `Packs/personas/` |
| **Directive** | What kind of work is this? (goal, ordered steps, stop points, acceptance, verification) | `Packs/directives/` |
| **Kit** | Reusable guardrails/defaults bundled together (essentials, skills, references, intents) | `Packs/kits/` |
| **Intent** | A reusable work pattern / decision rail, included by kits or required by directives | `Packs/intents/` |
| **Essential** | Required Markdown grounding (style guides, boundaries) | `Packs/essentials/` |
| **Reference** | Trigger-gated Markdown surfaced for matching paths/tags | `Packs/references/` |
| **Skill** | Capability metadata used for authorization (not a command PersonaKit runs) | `Packs/skills/` |
| **Session** | The named entry point tying persona + directive + overrides together | `Sessions/` |

Rough rule of thumb: reach for a **directive step** when something is part of the
sequence of *this* work; an **intent** when it's a reusable decision pattern across
work; an **essential** when it's standing grounding that's always true.

Author with `personakit create <entity>` (`persona`, `kit`, `directive`, `intent`,
`reference`, `skill`, `session`, `essential`). Use `--dry-run` to preview, and
`personakit schema <entity>` to see required fields before hand-editing JSON.

## Two Facts That Are Easy To Get Wrong

- **`kitOverrides` on a session *merges*, it does not replace.** Despite the name,
  a session's `kitOverrides` are unioned with the persona's `defaultKitIds` — the
  resolved kit set is both, deduplicated. There is no way to *subtract* a default
  kit via overrides.
- **`version` on every entity is reviewable metadata, not behavior.** PersonaKit
  stores it and shows it; it does not compare, gate, or migrate on it. Set it so
  packs stay reviewable as source. Do not expect resolution to change based on it.

## What PersonaKit Deliberately Does Not Do

PersonaKit is narrow on purpose. It is not an agent, launcher, workflow engine,
task manager, memory system, or orchestration layer. If you find yourself wanting
PersonaKit to do one of the following, the responsibility lives elsewhere — do not
build a workaround inside the contract:

| You need… | PersonaKit's role | Where it actually lives |
| --- | --- | --- |
| Unattended / headless behavior at a stop point (abort, skip, defer when no human is present) | Declares the stop point and exports it under "Stop Points". That is the contract. | **Your host runner** decides what to do at each exported stop point. PersonaKit does not provide an `onNoReviewer`-style flag, by design — that is a runtime decision, not contract intent. |
| Where output / deliverables go; tracked vs. scratch; gitignore-awareness | None — output is described in directive steps as intent, not modeled as a target | **Host or project convention.** Pick a location (e.g. a gitignored scratch dir) yourself; this is the agent's responsibility, not a PersonaKit concept. |
| Loops, multi-agent control flow, persistence, memory, task state | None | **Host or an external system.** |
| Running a skill, shell command, or tool | None — skills are capability *metadata* for authorization | **Your host.** PersonaKit authorizes; it never executes. |

A stop point in an exported contract is a real instruction: stop and get review.
In an unattended run with no reviewer, *that is a host decision* — the safe default
is to halt the mutating work, not to invent a contract field that pretends to
decide for you.

## Authoring Hygiene For Shared Content

Keep host-specific guidance out of shared essentials and personas. An essential
that says "Agent guidance (for Codex)" or names a specific CLI tool does not travel
to a different host and will mislead an agent running elsewhere. Describe
*capabilities and constraints*, not specific tools, in anything meant to be reused
across hosts.

## Related Docs

- [Repository Overview](../README.md)
- [PersonaKit MCP Guide](./mcp.md)
- [AGENTS.md](../AGENTS.md) — policy for agents working *in* this repository
