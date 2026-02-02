PersonaKit MCP Server (Swift)

The PersonaKit MCP server is provided by the Swift CLI and exposes PersonaKit context over stdio as read-only MCP Resources and Prompts.

Important:
- The Swift CLI and Swift codebase are the single source of truth for PersonaKit behavior and contracts.
- The Swift MCP server is the supported integration path.
- The legacy Node adapter is deprecated and will be removed after verification.

The MCP server does not provide Tools.

What it provides
- Resources: read-only access to Personas, Kits, Directives, Intent Templates, Skills, and Essentials.
- Prompts: session export and session graph.

Transport: stdio
The server runs as a local process and communicates over stdin/stdout. No ports are opened.
The server is designed to be launched and managed by an MCP client, not used directly by end users.

Required environment
- PERSONAKIT_ROOT: absolute path to the directory that contains Packs/.

Example launch (stdio)
From the repo root:
- personakit mcp

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
- The legacy Node adapter must not evolve into a general-purpose replacement for the Swift CLI.
