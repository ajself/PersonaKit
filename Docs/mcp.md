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

#### OpenCode enforcement

Enforcement needs the `opencode-personakit` plugin, tested on OpenCode 1.19.5,
whose server half blocks the tool calls the active contract forbids. The
package is not on npm yet. Once it
is published, install an exact version with OpenCode (add `-g` for a global
install), freeze a session's contract for the project, and restart OpenCode:

```bash
opencode plugin opencode-personakit@2.1.0
personakit enforce install --host opencode --session <id>
```

Install from npm, so the plugin lives in OpenCode's cache, which enforcement
protects; a plugin loaded from a project file outside `.opencode/` is one the
agent can edit. The plugin's status chip, Library, commands, and options are in
[Integrations/OpenCode/README.md](../Integrations/OpenCode/README.md).

`enforce install --host opencode` writes only
`.opencode/personakit/<id>.checks.json` and removes any other manifest in that
folder. It never edits OpenCode config; it warns when no OpenCode config lists
the plugin. The plugin reads the manifest and records its SHA-256 when OpenCode
starts, which is why the restart is needed. After that, a manifest that changes
or goes away while OpenCode runs denies every checked call until the next
restart. An unreadable manifest denies every checked call too, and more than one
manifest between the start folder and the repo root denies every call.

The plugin's `tool.execute.before` hook does the checking, and it covers the
TUI, `opencode run`, the web app, ACP, and subagents. Every tool except
OpenCode's read-only built-ins goes to `personakit hook-check --host opencode`.
MCP tools, other plugins' tools, and custom tools cannot be classified, so they
are denied whenever the contract forbids anything such a tool could do.

While a contract is enforced the agent cannot edit OpenCode's config or plugin
files through its edit, write, and patch tools, even when the contract allows
edits: `.opencode/` and `opencode.json(c)` or `tui.json(c)` anywhere in the
repo, the global OpenCode config and cache, `~/.opencode/`, `$OPENCODE_CONFIG`,
`$OPENCODE_CONFIG_DIR`, `$OPENCODE_TUI_CONFIG`, and the `personakit` binary.
Make those edits by hand.

What enforcement does not cover:

- It is not a sandbox. OpenCode launches programs on its own: formatters,
  language servers, MCP server commands, and plugins referenced by path. When
  one of them lives outside the protected files above, a contract that allows
  edits but denies commands still lets the agent rewrite it, and OpenCode then
  runs the new code. With commands allowed, nothing is protected.
- Shell commands you run yourself (`!cmd`, `/command` substitutions) are not
  checked.
- `opencode --pure` loads no external plugins, so it runs with no enforcement.
  That is your explicit choice, and PersonaKit does not detect it.
- Sessions created through `opencode serve`'s `/api/session` API run no plugin
  hooks. They get only the deny rules the plugin adds when OpenCode starts: the
  commands, edits, and network access the contract denies, plus the protected
  files above when edits are allowed. An unreadable manifest, or more than one,
  denies all three. OpenCode 1.19.5 offers no MCP or plugin tools in these
  sessions. The rules have limits:
  - Denials read as OpenCode's own generic messages, not the contract's reason.
  - A manifest change after startup is not seen.
  - The rules come from the manifest in the directory `opencode serve` started
    in, so a session for any other directory gets the start directory's rules,
    or none.
  - A session started before plugins finish loading can run unchecked. List
    `opencode-personakit` first in the `plugin` array.
  - A session whose directory is inside `.opencode/` or the global config can
    write there.
  - The rules cannot express case variants of a new protected file name, such
    as `OpenCode.json`, and a protected path reached through a symlink (file or
    directory) is judged by its target.
  - Later plugins can add agents or rules that override these.

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
`.claude/settings.json` that runs `personakit hook-check` on every tool call.
Restart Claude Code after installing, since it reads hooks at startup.

The hook names the `personakit` binary by the absolute path found when you
installed (pass `--executable` to choose another). If the checker cannot run,
because the binary moved or crashed, the hook blocks every tool call until you
fix the binary or run `enforce install` again.

Each call gets one of three answers:

- **Deny** a tool that does what the contract forbids: Edit, Write, and
  NotebookEdit edit files; Bash, Monitor, and PowerShell run commands; WebFetch
  and WebSearch reach the network. The reason tells the agent to stop and tell
  you what it needs, rather than find another way.
- **Allow** read-only built-ins, such as Read, Glob, Grep, and subagents of
  Claude Code's built-in types, and PersonaKit's own MCP tools and resources.
- **Ask** you about any other tool, including Skill, custom agent types,
  subagents started in a worktree or remote environment, MCP tools from other
  servers, and tools Claude Code adds later. Claude Code shows the reason and
  lets you approve or refuse the call. Where no one can answer, as in
  `claude -p`, Claude Code refuses it, and under `bypassPermissions` the checker
  denies it.

A tool is only asked about when the contract forbids editing files, running
commands, or reaching the network.

While a contract is enforced the agent cannot use Edit, Write, or NotebookEdit
on the enforcement files, even when the contract allows edits:
`.claude/personakit/`, `.claude/settings.json`, `.claude/settings.local.json`,
the user settings (`~/.claude/settings.json`, or `$CLAUDE_CONFIG_DIR`'s), and
the `personakit` binary. Make those edits by hand. Hooks installed by an
earlier PersonaKit version route only a few named tools to the checker, so
other tools, such as Monitor, pass unchecked, and a checker that fails to run
lets the call through; run `enforce install` again to route every tool and
block on failure.

It is not a sandbox. Claude Code runs programs on its own, such as other hook
scripts, a `statusLine` command, and MCP server commands. A contract that allows
edits but denies commands still lets the agent rewrite those, and Claude Code
then runs the new code. With commands allowed, the agent can change the
enforcement files through the shell.

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

Under an enforced contract, `hook-check` allows PersonaKit's own MCP tools from the server named `personakit`, or from the name given to `enforce install --mcp-server`, so agents can re-ground. Other MCP tools need the operator's approval on Claude Code and are denied on OpenCode.

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
