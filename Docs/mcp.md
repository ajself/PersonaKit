# PersonaKit MCP Guide

## Why This Exists

PersonaKit MCP lets an agent resolve the active operating contract before it picks tools, skills, or files: who is acting, what is allowed, what is forbidden, and when to stop.

Connecting a server makes context available; the contract decides whether it should be used this session. The MCP surface is read-only grounding, not an execution lane. For handoff context, use `personakit export`.

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
5. Read raw pack resources only as needed.

The key tools are:

- `personakit_recommend_session`: find a session for a natural-language task.
- `personakit_resolve_contract`: resolve persona, directive, kits, skills, and skill authorization.
- `personakit_trace_session`: audit where resolved constraints came from.
- `personakit_resolve_grounding_skills`: select triggered grounding skills for explicit paths or tags.
- `personakit_export`: assemble the Markdown handoff context.

Export and grounding-skill lookup check only what the requested session uses. A problem elsewhere in the library does not block them and is left out of their results, so the export stays plain Markdown; when the session itself fails validation, the error lists those problems as `warning:` lines after the session's own errors. `personakit_validate` checks the whole library.

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

Add the server to your OpenCode config (`opencode.json`). PersonaKit Studio's
Set Up Agents sheet shows the same entry to copy; Studio writes nothing itself.

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

The PersonaKit OpenCode plugin adds a status chip, a Library, and `/pk`
commands. After `personakit enforce install --host opencode --session <id>`
and an OpenCode restart, it is the hook that enforces the contract. Install the
plugin with `make opencode-install` from a checkout of the release tag that
matches your CLI;
[Integrations/OpenCode/README.md](../Integrations/OpenCode/README.md) has the
steps. [Docs/enforcement.md](./enforcement.md) covers enforcement on OpenCode:
what it blocks, how to install and remove it, and what it does not cover.

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

#### Claude Code enforcement

`personakit enforce install --session <id>` writes
`.claude/personakit/<id>.checks.json` and a `PreToolUse` hook in
`.claude/settings.json` that runs `personakit hook-check` on every tool call;
`personakit enforce uninstall` removes both.
[Docs/enforcement.md](./enforcement.md) covers what the hook denies, allows, and
asks about, and what it does not cover.

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

MCP never hands an agent text a person reviewing it would not see. `personakit_export`, `personakit_graph`, and error messages strip control characters, bidirectional overrides, and invisible characters such as Unicode tag characters from `.personakit` content. JSON results write those characters as `\uXXXX` escapes, so values stay exact. Raw pack resources are the files as written.

With no enforcement installed, PersonaKit checks no MCP calls, and the contract alone governs them. Under an enforced contract, `hook-check` allows PersonaKit's own MCP tools from the server named `personakit`, or from the name given to `enforce install --mcp-server`, so agents can re-ground. On OpenCode that trust holds only while the server is configured and no other configured server's name could produce the same tool id, and MCP tools from other servers are denied. On Claude Code you are asked about them; where no one can answer, as in `claude -p`, Claude Code refuses them, and under `bypassPermissions` the checker denies them. See [Docs/enforcement.md](./enforcement.md#trusted-mcp-server-names).

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
- [PersonaKit Enforcement](./enforcement.md)
