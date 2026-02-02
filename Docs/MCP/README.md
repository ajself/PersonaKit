PersonaKit MCP Adapter

The PersonaKit MCP adapter exposes PersonaKit context over stdio as read-only MCP Resources and Prompts.

Important:
- This Node.js project exists only to support MCP clients.
- It is not a user-facing CLI.
- It is not a second implementation of PersonaKit logic.
- The Swift CLI and Swift codebase are the single source of truth for PersonaKit behavior and contracts.

The MCP adapter does not provide Tools.

What it provides
- Resources: read-only access to Personas, Kits, Directives, Intent Templates, Skills, and Essentials.
- Prompts: session export and session graph.

Transport: stdio
The server runs as a local process and communicates over stdin/stdout. No ports are opened.
The adapter is designed to be launched and managed by an MCP client, not used directly by end users.

Required environment
- PERSONAKIT_ROOT: absolute path to the directory that contains Packs/.

Example launch (stdio)
From the repo root:
- npm run start

Example MCP client config
See `Docs/MCP/examples/stdio-npm.json` for a ready-to-use config.
If you want to run the built output directly, see `Docs/MCP/examples/stdio-node.json`.

Notes
- The MCP adapter is read-only and never writes to disk.
- The MCP adapter never executes commands or shells out to the Swift CLI.
- Output is deterministic (stable ordering, no timestamps).
- The adapter must not evolve into a general-purpose replacement for the Swift CLI.
