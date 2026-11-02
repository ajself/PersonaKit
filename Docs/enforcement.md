# PersonaKit Enforcement

A PersonaKit contract is intent by default. PersonaKit resolves it and exports
it, and your agent is expected to follow it, but nothing stops a tool call the
contract forbids. Enforcement is the opt-in step that changes that for one
project: `personakit enforce install` freezes a session's contract into a
manifest and wires it into the host's tool hook, so the host denies some of what
the contract forbids.

The contract stays authoritative either way. Enforcement denies some of what it
forbids, and a call that is not denied still has to follow the contract.

## Supported Hosts

- **Claude Code**, through a `PreToolUse` hook in the project's
  `.claude/settings.json`.
- **OpenCode** (tested on 1.19.5), through the PersonaKit OpenCode plugin, whose
  server half is the hook.

Every other host gets the contract as intent only.

## What It Blocks

Enforcement reads the persona's `forbiddenCapabilities`. Three of them map to
host tools:

| Forbidden capability | Claude Code tools denied | OpenCode tools denied |
| --- | --- | --- |
| `edit-files` | Edit, Write, NotebookEdit | edit, write, apply_patch |
| `run-commands` | Bash, Monitor, PowerShell | bash |
| `network-access` | WebFetch, WebSearch | webfetch, websearch |

`read-only-inspection` and `autonomous-loop` have no tool a hook can deny;
`enforce install` notes that enforcement cannot block them and that the agent
must still follow them. When the contract forbids none of the three capabilities
above, install writes nothing and says so. If an earlier install's hook or
manifest is still in place, it stays in force, and install says to run
`enforce uninstall` to remove it. The command and review checks that
`personakit checks` lists, and that the export shows under Boundaries, are not
run by any hook.

### Shell Tools Are Judged By Name Only

The checker never reads the command a shell tool runs. With `run-commands`
forbidden, every shell call is denied, whatever it runs. With `run-commands`
allowed, every shell call is allowed, including one that edits files, reaches
the network, or changes the enforcement files. A contract that forbids
`edit-files` or `network-access` but not `run-commands` therefore blocks only the
dedicated tools, and `enforce install` warns when that is the case. Forbid
`run-commands` too to close the shell route.

### Tools PersonaKit Cannot Classify

On **Claude Code** every tool goes to the checker. Each call gets one of three
answers:

- **Deny** a tool from the table above whose capability the contract forbids.
- **Allow** read-only built-ins such as Read, Glob, and Grep, subagents of
  Claude Code's built-in types started with no `isolation`, and PersonaKit's own
  MCP tools and resources from the trusted server (see below).
- **Ask** you about any other tool: Skill, custom agent types, subagents started
  in a worktree or remote environment, MCP tools from other servers, and tools
  Claude Code adds later. Claude Code shows the reason and lets you approve or
  refuse. Where no one can answer, as in `claude -p`, Claude Code refuses the
  call, and under `bypassPermissions` the checker denies it.

On **OpenCode** every tool except the read-only built-ins (glob, grep, invalid,
lsp, plan_exit, question, read, skill, task, todowrite) goes to the checker. MCP
tools, other plugins' tools, and custom tools cannot be classified, so they are
denied. OpenCode cannot ask you instead: its permission rules never apply to
plugin and custom tools, and `opencode run --auto` approves any ask.

### Enforcement Files Are Protected

While a contract is enforced, the file-edit tools cannot change the files that
would switch enforcement off, even when the contract allows edits:

- **Claude Code:** `.claude/personakit/`, `.claude/settings.json`,
  `.claude/settings.local.json`, the user settings (`~/.claude/settings.json`, or
  `$CLAUDE_CONFIG_DIR`'s), and the `personakit` binary.
- **OpenCode:** `.opencode/` and `opencode.json(c)` or `tui.json(c)` anywhere in
  the repo, the global OpenCode config and cache (which holds the installed
  plugin), `~/.opencode/`, `$OPENCODE_CONFIG`, `$OPENCODE_CONFIG_DIR`,
  `$OPENCODE_TUI_CONFIG`, and the `personakit` binary.

Make those edits by hand.

### Denials Fail Closed

A contract deny starts with `Blocked by PersonaKit contract:` and tells the
agent not to work around it but to stop and tell you what it needs. A checker
that cannot run, a manifest it cannot read, or a tool call it cannot parse also
denies the call; those reasons start with `Blocked by PersonaKit contract:`,
`PersonaKit enforcement could not`, or `PersonaKit could not`. They name the fix,
such as installing again or restarting the host, and end with the same
instruction to stop and tell you.

On Claude Code the hook names the `personakit` binary by the absolute path found
at install time (pass `--executable` to choose another). If that binary moves or
crashes, the hook blocks every tool call until you fix it or install again.
Claude Code lets a call through when a hook times out, so the checker denies any
call it has not decided within 10 seconds, well inside the hook's 60-second
timeout. Hooks installed by an earlier PersonaKit version route only a few named
tools to the checker and let a call through when the checker fails; install
again to route every tool and block on failure.

On OpenCode the plugin records the manifest's SHA-256 when OpenCode starts. A
manifest that changes or goes away while OpenCode runs denies every checked call
until the next restart. An unreadable manifest denies every checked call too,
and more than one manifest between the start folder and the repo root denies
every call.

## Install

Enforcement covers one session per project. Run install from the project folder,
or pass `--project-dir <path>`. Add `--dry-run` to print what would be written
without writing it.

### Claude Code

Install the `personakit` CLI first; the hook runs it on every tool call. Then:

```bash
personakit enforce install --session <id>
```

This writes `.claude/personakit/<id>.checks.json` and merges a `PreToolUse`
hook into `.claude/settings.json`. Other settings and hooks are kept; a previous
PersonaKit hook is replaced, so one contract is in force per project. Claude
Code watches its settings, so running sessions pick up the hook within a few
seconds; restart Claude Code if they do not.

### OpenCode

OpenCode enforcement needs the PersonaKit OpenCode plugin at the same version as
the CLI. Install it from a checkout of the matching release tag:

```bash
git clone https://github.com/ajself/PersonaKit.git
cd PersonaKit
git checkout "v$(personakit --version)"
make opencode-install
```

`make opencode-install` copies the plugin to
`${XDG_CACHE_HOME:-~/.cache}/opencode/personakit/plugin` and registers it for
every project on the machine with `opencode plugin -g --force`. Run it again
after you upgrade the CLI. Then, from your project:

```bash
personakit enforce install --host opencode --session <id>
```

This writes only `.opencode/personakit/<id>.checks.json` and removes any other
manifest in that folder. Restart OpenCode so the plugin loads it. Install,
`--dry-run` included, refuses when the plugin is missing or its version differs
from the CLI's, and
warns when the machine-wide OpenCode config does not list the plugin. The
`personakit` CLI never edits OpenCode config.

### Install Refusals

Install refuses, before writing anything, when `.claude`, `.claude/personakit`,
`.claude/settings.json`, `.opencode`, or `.opencode/personakit` is a symbolic
link, so the hook and manifest stay inside the project. It also refuses when
`.claude/settings.json` cannot be read or is not a JSON object, and when the
OpenCode manifest folder holds a `*.checks.json` entry that is not a regular
file.

## Remove

`personakit enforce uninstall` reverses what install wrote. Preview it first:

```bash
personakit enforce uninstall --dry-run
personakit enforce uninstall
```

For OpenCode, add `--host opencode`. Both accept `--project-dir <path>`.

- **Claude Code:** removes the PersonaKit hook from `.claude/settings.json`,
  keeping every other setting and hook, and removes each `*.checks.json` in
  `.claude/personakit/`. A settings file or folder left empty is removed too, so
  an install into a bare project uninstalls to nothing.
- **OpenCode:** removes each `*.checks.json` in `.opencode/personakit/` and any
  folder left empty. It never touches OpenCode config, and the plugin stays
  installed; with no manifest it enforces nothing.

Claude Code drops the hook within a few seconds; restart it if calls are still
blocked. Restart OpenCode afterward: until then, the plugin keeps checking calls
against a manifest that is gone, so it blocks them.
Uninstall refuses where install does: a symbolic link on the path, a
`*.checks.json` entry that is not a regular file, or settings that are not a
JSON object. With nothing installed it says so and changes nothing.

## Trusted MCP Server Names

An enforced session still lets the agent re-ground. The checker allows
PersonaKit's own read-only MCP tools, but only from the server name recorded in
the manifest: `personakit` by default, or the name you pass to
`enforce install --mcp-server <name>`. Pass it when you registered the PersonaKit
MCP server under another name.

The trusted tools are `personakit_best_guidance`, `personakit_compare_entities`,
`personakit_explain_entity`, `personakit_export`, `personakit_graph`,
`personakit_recommend_session`, `personakit_resolve_contract`,
`personakit_resolve_grounding_skills`, `personakit_resolve_session_ref`,
`personakit_trace_session`, and `personakit_validate`.

- **Claude Code** matches the full tool name, `mcp__<name>__<tool>`, exactly.
  The MCP resource tools (ListMcpResourcesTool, ReadMcpResourceDirTool,
  ReadMcpResourceTool) are allowed only for that server. A same-named tool on
  any other server is asked about. The name may hold letters, digits, `-`, and
  `_`, but not `__`.
- **OpenCode** matches `<name>_<tool>`, with any character other than a letter,
  digit, `_`, or `-` in the name read as `_`, only while that server is
  configured, and withdraws trust when another configured server's name could
  produce the same tool id. OpenCode's MCP resource tools are not trusted. The name may hold
  letters, digits, `.`, `_`, and `-`.

The `mcpServerName` option of the Claude Code mod and the OpenCode plugin only
tells their status displays which calls are PersonaKit's; enforcement reads the
name from the manifest.

## What It Does Not Cover

Enforcement is not a sandbox.

- Hosts run programs on their own: Claude Code runs other hook scripts, a
  `statusLine` command, and MCP server commands; OpenCode runs formatters,
  language servers, MCP server commands, and plugins referenced by path. A
  contract that allows edits but denies commands still lets the agent rewrite
  one of those when it lives outside the protected files, and the host then runs
  the new code.
- Shell commands you run yourself in OpenCode (`!cmd`, `/command`
  substitutions) are not checked.
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
    the PersonaKit plugin first in the `plugin` array.
  - A session whose directory is inside `.opencode/` or the global config can
    write there.
  - The rules cannot express case variants of a new protected file name, such
    as `OpenCode.json`, and a protected path reached through a symlink (file or
    directory) is judged by its target.
  - Later plugins can add agents or rules that override these.

## Related Docs

- [PersonaKit For Agents](./agent-guide.md)
- [PersonaKit MCP Guide](./mcp.md)
- [Claude Code mod](../Integrations/ClaudeCode/README.md)
- [OpenCode plugin](../Integrations/OpenCode/README.md)
