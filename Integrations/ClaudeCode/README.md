# PersonaKit mod for Claude Code

A Claude Code mod that shows which PersonaKit contract is in force in the current session, flags drift from it, and
lets you browse your PersonaKit library. From the library it pre-fills a request to resolve, export, and adopt a
session's contract, which you review and send.

## Install

The mod needs the `personakit` CLI: install it from the signed `.pkg` on
[GitHub Releases](https://github.com/ajself/PersonaKit/releases/latest), or see the
[Install page](https://ajself.github.io/PersonaKit/install/). The status comes from what the agent resolves through
the PersonaKit MCP server or the CLI, so register the server too:

```bash
claude mcp add personakit --scope user -- "$(which personakit)" mcp
```

Then, at the prompt of a terminal session:

```text
/plugin install personakit --marketplace ajself/PersonaKit
```

Answer `y` to add the marketplace, then pick a scope. From a shell, the same install is
`claude plugin install personakit --marketplace ajself/PersonaKit`.

## What it shows

The status line under the prompt reads one of:

- `◇ no contract · /pk use <session>` when nothing has been resolved.
- `◆ <session> · <warnings> · enforced|advisory · <scope> · <persona> › <directive>` for the contract in force.
  Warnings and enforcement come first so a narrow terminal's cut hides the names, not them; the names are dropped
  from the end to stay within 120 characters, and a long session id is shortened with `…` when the line still
  does not fit.
- Warnings cover a stale contract (`re-ground?` after compactions), the latest drift since the resolve
  (`drift: <tool> (<class>)`, with a `×N` count), `enforcing <other>` when a PersonaKit hook is installed for a
  different contract, `enforcement manifest unreadable`, and `re-ground blocked`.

The contract is whatever the agent last resolved through the PersonaKit MCP server or the `personakit` CLI in this
session. Warnings use `⚠` rather than color. The mod reads the installed hook again whenever a turn ends, so a hook
installed or removed mid-session shows once the current turn finishes; Claude Code itself applies it within a few
seconds, without a restart.
Claude Code draws every plugin status line as a `⚠ <plugin>:` notice, so the steady state shows that marker too;
`$.ui.status` offers no styling.

The `/pk` pane shows the resolved contract (persona, directive, steps with stop points, kits, skills, authorization
failures), scope, enforcement state and installed manifest, counted compactions since the resolve, drift counted
since the latest grounding with the full drift log below it, and contracts resolved by subagents. Its Re-ground button
pre-fills a prompt. When the agent's resolution carried no contract JSON, the pane reads the kits, skills, and scope
itself and says so beside them. With a hook installed, the Enforcement section lists what the hook blocks and which
tool calls it checks; without one, Drift check lists what the handoff context forbids, which the mod flags when the
agent does it anyway. Each drift log entry reads `blocked` when the hook denied the call, `not blocked` when a
forbidden call ran with no hook to stop it, or `re-ground blocked`.

## The Library

The Library is the other half of the `/pk` pane: your personas, sessions, and components, read from the same
`.personakit` roots the CLI resolves. It loads each time it is shown, and Refresh loads it again.

- **People** lists each persona with the sessions that use it. A session shows its directive title first, then its id,
  and a Use button, which reads Switch while another session is in force. A session shows a scope badge only when its
  scope differs from its persona's or it overrides. The session in force is marked `● in force`. A persona no session
  uses says so and has no button.
- **Components** opens the plain lists of directives, kits, and skills, with a count for each.
- **Filter** narrows both by id, name, or a session's directive title as you type, and the words `project` and
  `global` filter by scope. It appears only where the surface can draw a text field, so it is absent on mobile.
- **Scope badges** are always words: `project`, `global`, or `project · overrides global` when a project entity
  shadows a global one. Color only reinforces them.
- Every name opens a detail view, with Back to where you came from. A persona shows its sessions, responsibilities,
  non-goals, and boundaries. A directive shows its goal, steps with stop points, and acceptance criteria. A kit shows
  its skills, and a skill its description; both show what uses them.
- A session's detail is a preview of its contract, read for that session and labeled `preview, not in force`. Use
  pre-fills the prompt, as `/pk use` does; nothing is in force until you send it and the agent resolves the contract.
- When the Library loads from other `.personakit` roots than the contract in force came from, a warning above the
  list names both (`⚠ Library loaded from …; the contract in force came from …`).

When the library cannot load, the pane says why instead of showing an empty list: no library in this project or in
`~/.personakit` (with a `personakit init` hint), a `personakit` binary that could not run (it names the binary and
points at `personakitPath`), a CLI too old for the mod ("This needs PersonaKit 2.2.0 or later."), files that failed
validation (listed by scope and path), or a host that cannot run processes at all.

## Commands

- `/pk` opens the pane on the Contract when one is in force in the session, and on the Library otherwise.
- `/pk use <session>` pre-fills the prompt box with a request to resolve and export that session and adopt the
  contract. It replaces an empty box and appends on a new line otherwise, so a draft is never lost. You review and
  send it. An id outside PersonaKit's id rule (letters, digits, `.`, `_`, and `-`, not starting with `.`) is
  rejected with a reply that states the rule, and nothing is pre-filled.

## Options

`mcpServerName` (default `personakit`) is the name of the MCP server that serves PersonaKit contracts. Set it if you
registered the server under another name, so the mod recognizes those calls as PersonaKit's own.

`personakitPath` (default `personakit`) is the executable the pane runs to load the Library and the contract
previews, and the one the grounding prompt tells the agent to run when the MCP server is not connected. Set it to a
path or name when `personakit` is not on the `PATH` Claude Code sees.

## What it does not do

The mod never blocks a tool call, never submits a prompt, and never writes a file. The only commands it runs are
`personakit list all --json`, `personakit contract`, and `personakit export`, all read-only, and only from the `/pk`
pane. Everything else it does is read files and observe what the agent already did. What the pane loads never reaches
the status line or the drift log. Enforcement itself comes from the PreToolUse hook that `personakit enforce install`
writes; the mod only reports its state.
[Docs/enforcement.md](https://github.com/ajself/PersonaKit/blob/main/Docs/enforcement.md) covers what enforcement
blocks and how to install and remove it.

## Development

```bash
make mod-check
```

runs `claude plugin validate` and `claude plugin test` on this folder. The plugin version tracks PersonaKit's release
version; `make version-bump` and `make version-check` keep them in step.
