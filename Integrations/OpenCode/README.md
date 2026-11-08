# PersonaKit for OpenCode

An OpenCode plugin that shows which PersonaKit contract is in force in the current session, flags drift from it, and
lets you browse your PersonaKit library. From the library it pre-fills a request to resolve, export, and adopt a
session's contract, which you review and send. Once you opt in, it also enforces the contract: its server half is the
hook that blocks the tool calls the contract forbids. It is the OpenCode counterpart of the
[Claude Code mod](https://github.com/ajself/PersonaKit/blob/main/Integrations/ClaudeCode/README.md) and is tested
on OpenCode 1.19.5.

## Install

The plugin installs from a PersonaKit checkout, at the release tag that matches your `personakit` CLI:

```bash
git clone https://github.com/ajself/PersonaKit.git
cd PersonaKit
git checkout "v$(personakit --version)"
make opencode-install
```

`make opencode-install` copies the plugin to `${XDG_CACHE_HOME:-~/.cache}/opencode/personakit/plugin` and registers it
for every project on the machine with `opencode plugin -g --force file://<that folder>`, which adds the entry to both
OpenCode's server config (`opencode.json`) and its TUI config (`tui.json`). The `personakit` CLI never writes either
file. The plugin lives in OpenCode's cache, which enforcement protects from the agent's edits. Run the install again
after you upgrade the CLI: `personakit enforce install --host opencode` refuses a plugin whose version differs from
the CLI's. Restart OpenCode to load the plugin.

To enforce a session's contract in this project, install it, then restart OpenCode so the plugin loads it:

```bash
personakit enforce install --host opencode --session <id>
```

`personakit enforce uninstall --host opencode` removes it again.
[Docs/enforcement.md](https://github.com/ajself/PersonaKit/blob/main/Docs/enforcement.md) covers what enforcement
blocks, how to install and remove it, and what it does not cover.

The status comes from what the agent resolves through the PersonaKit MCP server or the `personakit` CLI, so register
the server as well; [Docs/mcp.md](https://github.com/ajself/PersonaKit/blob/main/Docs/mcp.md) has the OpenCode config.

## What it shows

The status chip beside the prompt reads the same line as the Claude Code mod:

- `◇ no contract · /pk-use` when nothing has been resolved in the session. With a manifest in the project, the
  enforcement segment takes the hint's place.
- `◆ <session> · <warnings> · enforced|advisory · <scope> · <persona> › <directive>` for the contract in force, cut to
  120 characters with the names dropped first. Warnings cover a stale contract (`re-ground?` after compactions), the
  latest drift since the resolve (`drift: <tool> (<class>)`, with a `×N` count), and `re-ground blocked` when the
  plugin denied the agent's call to resolve the contract again.

The enforcement segment reads:

- `enforced` only when a manifest exists, the resolved OpenCode config lists the server plugin, the manifest is the one
  OpenCode loaded at startup, and it belongs to the contract resolved in the session.
- `advisory` when the project has no manifest.
- `⚠ manifest present · plugin not loaded` when no config lists the plugin `make opencode-install` registered, so
  nothing enforces the manifest.
- `⚠ manifest changed · restart OpenCode` when the manifest was added, changed, or removed since OpenCode started. It
  also shows after you turn the plugin off and on or enable it mid-session, since the plugin can no longer confirm what
  OpenCode loaded at startup.
- `⚠ enforcement manifest unreadable` when the manifest cannot be read, which blocks every checked tool call, or when
  there is more than one between the start directory and the repo root, which blocks every tool call.
- `⚠ enforcing <other>` when the manifest belongs to a different contract than the one resolved.

The chip turns the theme's warning color while it carries a `⚠`. The sidebar shows the contract in force (persona,
directive, steps with stop points, kits, skills), the enforcement state, compactions since the resolve, the last five
drift entries since the latest grounding under their count, and a Re-ground button that pre-fills a prompt to resolve
the contract again. The sidebar's button takes a mouse; from the keyboard, Re-ground is on the Contract tab of `/pk`.
Subagents count as part of the session that started them.

OpenCode continues on its own after it compacts a conversation, so when the session you are viewing compacts, a toast
asks whether to re-ground and points to `/pk`. Nothing is injected into the conversation; re-grounding is your call.

When the agent's attempt to resolve a contract fails in the session you are viewing, a toast says so once and names the
contract that stays in force: `PersonaKit resolve failed; <id> stays in force`. Failures already in a session's history
when you open it are not shown.

## The Library

`/pk` opens a PersonaKit view in place of the session, with Contract and Library tabs. The Contract tab is the mod's
Contract view: the resolved contract, scope, enforcement state and installed manifest, compactions, drift counted since
the latest grounding with the full drift log below it, contracts resolved by subagents, and Re-ground. With a manifest
the plugin enforces, the Enforcement section lists what it blocks; without one, Drift check lists what the handoff
context forbids, which the status flags when the agent does it anyway. Each drift log entry reads `blocked`,
`not blocked` (a forbidden call ran with nothing to stop it), or `re-ground blocked`.

The Library lists your personas, sessions, and components, read from the same `.personakit` roots the CLI resolves. It
loads each time the view opens, and Refresh loads it again.

- **People** lists each persona with the sessions that use it. A session shows its directive title, its id, and a Use
  button, which reads Switch while another session is in force. The session in force is marked `● in force`.
- **Components** opens the plain lists of directives, kits, and skills, with a count for each.
- **Filter**: typing narrows both by id, name, or a session's directive title, and the words `project` and `global`
  filter by scope.
- **Scope badges** are always words: `project`, `global`, or `project · overrides global`. Color only reinforces them.
- Every name opens a detail view. A session's detail is a preview of its contract, labeled `preview, not in force`.
  Use returns to the session and pre-fills the prompt; nothing is in force until you send it and the agent resolves
  the contract.
- When the Library loads from other `.personakit` roots than the contract in force came from, a warning above the
  list names both (`⚠ Library loaded from …; the contract in force came from …`).

↑ and ↓ (or Tab and Shift-Tab) move between controls, Enter presses one, and Esc clears the filter or goes back. Back
on the top view returns to the session `/pk` was opened from.

When the library cannot load, the view says why instead of showing an empty list: no library in this project or in
`~/.personakit` (with a `personakit init` hint), a `personakit` binary that could not run (it says to set
`personakitPath` in both `opencode.json` and `tui.json`), a CLI too old for the plugin ("This needs PersonaKit 2.2.0
or later."), or files that failed validation, listed by scope and path.

## Commands

- `/pk` opens the PersonaKit view on the Contract when one is in force in the session, and on the Library otherwise.
- `/pk-use` lists the library's sessions by directive title, with the id beside each; typing filters by title or id.
  Picking one pre-fills the prompt with a request to resolve and export that session and adopt the contract. A
  session whose id PersonaKit cannot pass safely is listed but disabled, and picking it pre-fills nothing. OpenCode's
  palette commands take no arguments, which is why this is a list rather than the mod's `/pk use <session>`.

Pre-fill appends to the prompt box with no separating newline, since OpenCode does not expose the draft to plugins,
and never sends it. You review and send. If the box cannot take the text, a toast shows it to copy instead.

## Options

Options go in the plugin's entry as `[spec, options]`, with the spec exactly as `make opencode-install` wrote it. The
server plugin reads its entry in the global `opencode.json` and the TUI reads its own in `tui.json`, so set
`personakitPath` in both:

```json
{
  "plugin": [["file:///Users/you/.cache/opencode/personakit/plugin", { "personakitPath": "/usr/local/bin/personakit" }]]
}
```

`personakitPath` (default `personakit`) is the executable the plugin runs: `hook-check` for enforcement, and the Library
and contract previews in the TUI. The grounding prompt names it too, for the agent to run when the MCP server is not
connected. Give an absolute path or a bare name on the `PATH` OpenCode sees. The server plugin rejects a relative path
such as `bin/personakit`, and then blocks every checked tool call until you fix it and restart OpenCode.

`mcpServerName` (default `personakit`) is the name of the MCP server that serves PersonaKit contracts. Set it in
`tui.json` if you registered the server under another name, so the status recognizes those calls as PersonaKit's own.
Enforcement trusts PersonaKit's MCP tools by the name recorded in the manifest instead: pass the same name to
`personakit enforce install --mcp-server <name>`.
[Docs/enforcement.md](https://github.com/ajself/PersonaKit/blob/main/Docs/enforcement.md#trusted-mcp-server-names)
explains which names it trusts.

## Enforcement

At startup the server plugin finds the manifest in `.opencode/personakit/`, records its SHA-256, and resolves
`personakit`. From then on every tool call except OpenCode's read-only built-ins goes to `personakit hook-check`,
which denies what the contract forbids; the reason reaches the model and tells it to stop and tell you what it needs
rather than find another way. MCP tools, other plugins' tools, and custom tools cannot be classified, so they are denied
whenever the contract forbids anything such a tool could do. Claude Code enforcement asks you about such a tool
instead; the plugin cannot, since OpenCode's permission rules never apply to plugin and custom tools, and
`opencode run --auto` approves any ask. A checker that cannot run, or a manifest that changed since startup, denies the
call, and the reason says how to fix it.

This covers the TUI, `opencode run`, the web app, ACP, and subagents. While a contract is enforced the agent cannot edit
OpenCode's config or plugin files, even when the contract allows edits: `.opencode/` and `opencode.json(c)` or
`tui.json(c)` anywhere in the repo, the global OpenCode config and cache, `~/.opencode/`, `$OPENCODE_CONFIG`,
`$OPENCODE_CONFIG_DIR`, `$OPENCODE_TUI_CONFIG`, and the `personakit` binary. Edit those by hand.

Enforcement is not a sandbox. OpenCode launches programs on its own: formatters, language servers, MCP server
commands, and plugins referenced by path. When one of them lives outside the protected files above, a contract that
allows edits but denies commands still lets the agent rewrite it, and OpenCode then runs the new code. With commands
allowed, nothing is protected. Shell commands you run yourself (`!cmd`, `/command` substitutions) are not checked.
Sessions created through `opencode serve`'s `/api/session` API get only static deny rules;
[Docs/enforcement.md](https://github.com/ajself/PersonaKit/blob/main/Docs/enforcement.md#what-it-does-not-cover) lists
what that misses.

## What it does not do

The plugin never writes a file, never edits OpenCode config, and never submits a prompt. The only commands it runs are
`personakit list all --json`, `personakit contract`, and `personakit export`, from the TUI and only on your action
(`/pk`, `/pk-use`, Refresh, a session preview), and `personakit hook-check` from the server plugin for each checked
tool call. Everything else it does is read files and observe what the agent already did.

`opencode --pure` loads no external plugins, so it runs with no PersonaKit view and no enforcement. That is your
explicit choice, and PersonaKit does not detect it.

## Development

```bash
make opencode-check
```

typechecks, tests, and dry-run packs the plugin. The package shares its core with the Claude Code mod
(`Integrations/ClaudeCode/hooks/lib`), and the pack step stages both with the repo layout intact. The package version
tracks PersonaKit's release version; `make version-bump` and `make version-check` keep them in step.
