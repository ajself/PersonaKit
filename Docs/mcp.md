# PersonaKit MCP Guide

## Why This Exists

PersonaKit MCP gives AI tools a read-only way to discover and resolve PersonaKit operating contracts.

It is for grounding, inspection, and provenance. It is not an execution lane. For handoff context, use `personakit export`.

## What To Do

Start the server:

```bash
personakit mcp
```

For a specific PersonaKit root:

```bash
personakit mcp --root /path/to/project/.personakit
```

Useful scope flags:

```text
--root <root>  Use a specific PersonaKit root.
--no-project   Disable project scope discovery.
--no-global    Disable global scope discovery.
```

Most MCP clients configure local servers as a stdio command plus arguments. Use
an absolute path to the installed `personakit` executable when the client does
not inherit your shell `PATH`:

```json
{
  "command": "/absolute/path/to/personakit",
  "args": ["mcp"]
}
```

If your client supports environment variables or workspace-relative commands,
you can adapt that shape, but the server process is the same: `personakit mcp`.

An unfamiliar MCP client or AI agent should follow this path:

1. Read `personakit://catalog/start`.
2. Read `personakit://catalog/sessions` or call `personakit_recommend_session`.
3. Call `personakit_resolve_contract` for the selected session.
4. Call `personakit_trace_session` when provenance matters.
5. Read raw pack or essential resources only as needed.

The key tools are:

- `personakit_recommend_session`: find a session for a natural-language task.
- `personakit_resolve_contract`: resolve persona, directive, kits, intents, essentials, and skill authorization.
- `personakit_trace_session`: audit where resolved constraints came from.
- `personakit_resolve_references`: select triggered references for explicit paths or tags.
- `personakit_export`: assemble human-readable Markdown grounding.

## Client Setup Notes

Client configuration formats differ, so treat these as starting points and
check the current client docs before sharing a checked-in config.

Current client docs:

- [OpenCode MCP servers](https://opencode.ai/docs/mcp-servers/)
- [Claude Code MCP](https://code.claude.com/docs/en/mcp)
- [Codex MCP](https://developers.openai.com/codex/mcp)
- [GitHub Copilot CLI MCP](https://docs.github.com/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers)
- [VS Code MCP configuration](https://code.visualstudio.com/docs/copilot/reference/mcp-configuration)

### OpenCode

PersonaKit Studio can install or update the OpenCode MCP entry for the local
user. The generated shape is:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "personakit": {
      "command": ["/absolute/path/to/personakit", "mcp"],
      "enabled": true,
      "type": "local"
    }
  }
}
```

Studio will not rewrite an existing JSONC config automatically; it reports a
manual merge snippet instead so comments and trailing commas are not stripped.

### Claude Code

Claude Code supports MCP servers through `claude mcp` and project `.mcp.json`
files. A project-scoped local server uses the standard `mcpServers` shape:

```json
{
  "mcpServers": {
    "personakit": {
      "command": "/absolute/path/to/personakit",
      "args": ["mcp"],
      "env": {}
    }
  }
}
```

Claude Code may prompt before using project-scoped servers from `.mcp.json`.

### Codex

Codex can connect to MCP servers from the CLI or config file. For local stdio
servers, the config file shape is:

```toml
[mcp_servers.personakit]
command = "/absolute/path/to/personakit"
args = ["mcp"]
```

Use `codex mcp --help` for the current management commands. In the Codex TUI,
use `/mcp` to inspect active MCP servers.

### GitHub Copilot CLI

GitHub Copilot CLI supports local/stdio MCP servers through interactive
`/mcp add`, the `copilot mcp add` command, or `~/.copilot/mcp-config.json`.

```json
{
  "mcpServers": {
    "personakit": {
      "type": "local",
      "command": "/absolute/path/to/personakit",
      "args": ["mcp"],
      "env": {},
      "tools": ["*"]
    }
  }
}
```

### VS Code

VS Code supports MCP configuration in a workspace `.vscode/mcp.json` or user
profile config. VS Code uses a `servers` object rather than `mcpServers`:

```json
{
  "servers": {
    "personakit": {
      "type": "stdio",
      "command": "/absolute/path/to/personakit",
      "args": ["mcp"]
    }
  }
}
```

### Other Clients

Cursor, Windsurf, and other MCP-aware coding tools also support local MCP
servers, but their configuration files and UI flows change over time. Use the
generic stdio shape above and follow the current client docs.

## Safety Model

PersonaKit MCP is read-only.

MCP resources and tools provide context. They do not authorize execution, file mutation, shell commands, workflow orchestration, memory, or autonomous planning.

If a contract does not authorize a needed skill, stop and re-ground instead of improvising.

## How To Verify

Use these checks after MCP behavior changes:

```bash
swift test --no-parallel --filter MCP
swift run personakit validate
swift run personakit mcp --help
```

## Related Docs

- [Repository Overview](../README.md)
- [PersonaKit For Agents](./agent-guide.md)
