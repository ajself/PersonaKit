PersonaKit MCP Server (Swift)

The PersonaKit MCP server is provided by the Swift CLI and exposes PersonaKit context over stdio as read-only MCP Resources and Prompts.

Important:
- The Swift CLI and Swift codebase are the single source of truth for PersonaKit behavior and contracts.
- The Swift MCP server is the supported integration path.

The MCP server does not provide Tools.

What it provides
- Resources: read-only access to Personas, Kits, Directives, Intent Templates, Skills, and Essentials.
- Prompts: session export and session graph.

Transport: stdio
The server runs as a local process and communicates over stdin/stdout. No ports are opened.
The server is designed to be launched and managed by an MCP client, not used directly by end users.

Optional environment
- PERSONAKIT_ROOT: explicit PersonaKit root path (must contain `Packs/`).
- PERSONAKIT_ROOT_OVERRIDE=1: compatibility mode; requires `PERSONAKIT_ROOT`.

Example launch (stdio)
From any directory:
- personakit mcp
- personakit mcp --root /absolute/path/to/.personakit

Example MCP client config
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

Notes
- The MCP server is read-only and never writes to disk.
- The MCP server never executes external commands.
- Output is deterministic (stable ordering, no timestamps).
- MCP scope selection is local-first and single-scope:
  1) `--root <path>`
  2) `PERSONAKIT_ROOT`
  3) local project `.personakit`
  4) `~/.personakit`
  5) error when none exist
- MCP chooses one scope only (project or global), not project/global merge.
- `--no-project` and `--no-global` disable discovery fallback steps.
