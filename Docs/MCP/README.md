# MCP Docs

Status: Active
Owner: AJ
Last Reviewed: 2026-03-09

## Purpose

Provide the current MCP behavior, launch guidance, onboarding flow, and
troubleshooting docs for PersonaKit's read-only MCP surface.

## Server Overview

The PersonaKit MCP server is provided by the Swift CLI and exposes PersonaKit context over stdio as read-only MCP resources, prompts, and tools.

Important:

- The Swift CLI and Swift codebase are the single source of truth for PersonaKit behavior and contracts.
- The Swift MCP server is the supported integration path.

## Capabilities

- Resources: read-only access to Personas, Kits, Directives, Intent Templates, Skills, Essentials, and catalog endpoints.
- Prompts: session export and session graph.
- Tools: validate/export/graph plus discussion primitives (`explain`, `compare`, `recommend`, `trace`).

All MCP capabilities are read-only. The server never writes pack files and never executes shell commands.

## Transport

- `stdio` only.
- No network ports are opened.
- The server is meant to be launched by an MCP client.

## Scope Selection (MCP Local-First, Single Scope)

MCP scope resolution is deterministic and selects exactly one scope:

1. `--root <path>`
2. `PERSONAKIT_ROOT`
3. local project `.personakit`
4. `~/.personakit`
5. fail with explicit startup error

Notes:

- `PERSONAKIT_ROOT` must point to a PersonaKit root containing `Packs/`.
- `PERSONAKIT_ROOT_OVERRIDE=1` is compatibility mode and requires `PERSONAKIT_ROOT`.
- `--no-project` and `--no-global` disable discovery fallback steps.

## Launch

From any directory:

- `personakit mcp`
- `personakit mcp --root /absolute/path/to/.personakit`

## MCP Client Config Example

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

## First-Use Guides

- [Starter Flows](./Starter-Flows.md)
- [Error Contracts](./Error-Contracts.md)
- [Troubleshooting](./troubleshooting.md)

## Relationship To The Rest Of `Docs/`

- `Docs/MCP/` is the active MCP documentation lane.
- `Docs/Archive/MCP/` contains historical MCP planning material.
- `Docs/PersonaKit/` documents the engine and repository operating model behind
  the MCP server.
