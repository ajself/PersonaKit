# PersonaKit mod for Claude Code

A Claude Code mod that shows which PersonaKit contract is in force in the current session and flags drift from it.

## Install

At the prompt of a terminal session:

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
  from the end to stay within 120 characters.
- Warnings cover a stale contract (`re-ground?` after compactions), the latest drift since the resolve
  (`drift: <tool> (<class>)`, with a `×N` count), `enforcing <other>` when a PersonaKit hook is installed for a
  different contract, `enforcement manifest unreadable`, and `re-ground blocked`.

The contract is whatever the agent last resolved through the PersonaKit MCP server or the `personakit` CLI in this
session. Warnings use `⚠` rather than color.
Claude Code draws every plugin status line as a `⚠ <plugin>:` notice, so the steady state shows that marker too;
`$.ui.status` offers no styling.

The `/pk` pane shows the resolved contract (persona, directive, steps with stop points, kits, skills, authorization
failures), scope, enforcement state and installed manifest, counted compactions since the resolve, a drift log,
and contracts resolved by subagents. Its Re-ground button pre-fills a prompt.

## Commands

- `/pk` opens the pane.
- `/pk use <session>` pre-fills the prompt box with a request to resolve and export that session and adopt the
  contract. It replaces an empty box and appends on a new line otherwise, so a draft is never lost. You review and
  send it.

## Options

`mcpServerName` (default `personakit`) is the name of the MCP server that serves PersonaKit contracts. Set it if you
registered the server under another name, so the mod recognizes those calls as PersonaKit's own.

## What it does not do

The mod never runs PersonaKit, never blocks a tool call, and never submits a prompt. It only reads files and observes
what the agent already did. Enforcement itself comes from `personakit enforce install`; the mod reports its state.

## Development

```bash
make mod-check
```

runs `claude plugin validate` and `claude plugin test` on this folder. The plugin version tracks PersonaKit's release
version; `make version-bump` and `make version-check` keep them in step.
