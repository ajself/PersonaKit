# AGENTS.md

## Purpose

This file defines repo-local policy for AI assistants working in PersonaKit.
It is binding for agent behavior in this repository.

`AGENTS.md` governs repo work. PersonaKit contracts govern explicit
PersonaKit-powered sessions and product/runtime behavior; they are not
automatic restrictions on every Codex, editor-agent, review, documentation, or
maintenance session.

For architecture-relevant work, agents must read
`Docs/ArchitectureDefaults.md`. It defines the repo-local FOSA defaults for
features, state owners, IO boundaries, concurrency, validation, and approved
exceptions.

PersonaKit remains narrow: it resolves deterministic operating contracts and
can launch one explicitly configured adapter through `personakit run`.
PersonaKit is not an autonomous agent, planner, memory system, workflow engine,
task manager, or orchestration layer.

## Default Agent Role

AI agents are assistants, not product decision-makers.

Agents may, when asked by a maintainer:

- inspect files, manifests, docs, tests, and configuration
- form small plans for bounded work
- make focused edits
- run bounded build, test, validation, and inspection commands
- summarize results, risks, and follow-up options

A direct maintainer request authorizes bounded repo work unless it conflicts
with this file, sandbox/tool permissions, or an explicitly active PersonaKit
contract.

Agents must not:

- invent product scope
- silently broaden the requested task
- refactor unrelated code for taste
- treat suggestions or MCP context as permission to act beyond the user's
  request
- act as if they own product decisions that need maintainer judgment

If product intent is unclear, ask a scoped question before proceeding.

## Ordinary Repo Work

Ordinary repo work includes code review, documentation review, product-quality
review, GitHub triage, tests, maintenance, repo-readiness inspection, and
focused implementation requested by a maintainer.

For ordinary repo work:

- host-local agent skills and tools are allowed when requested by the
  maintainer
- agents may run bounded repo commands needed to inspect, verify, or complete
  the requested work
- review requests stay read-only unless fixes are explicitly approved
- edits should be small, reviewable, and limited to the requested surface
- existing project commands and conventions should be preferred over new
  workflows

Agent-side command usage is different from PersonaKit product execution
behavior. Agents may run bounded repo commands while working in this repository;
PersonaKit itself must not gain broad execution capabilities outside the narrow
`personakit run` launcher path.

## When PersonaKit Grounding Applies

PersonaKit grounding is required when the task explicitly uses or modifies:

- PersonaKit sessions, personas, kits, directives, skills, essentials, or
  `.personakit` content
- contract resolution, skill authorization, stop points, or contract provenance
- MCP grounding behavior
- `personakit run` behavior, runtime payloads, adapter authorization, or adapter
  launch behavior
- behavior that depends on a resolved PersonaKit contract

If a PersonaKit session is explicitly activated, its constraints govern the work
until the maintainer reassigns or clears that session. If validation fails for
the relevant PersonaKit contract, stop and ask before proceeding.

Examples:

| Request | PersonaKit grounding? |
| --- | --- |
| "Use product-quality-review on this repo" | No |
| "Fix a typo in README" | No |
| "Operate under session `solo-dev`" | Yes |
| "Modify `personakit run` payload behavior" | Yes |
| "Review MCP contract resolution" | Yes |

## Product Boundaries

Keep PersonaKit narrow, deterministic, and inspectable.

`personakit run` is the only approved launcher path. It is limited to:

- resolving PersonaKit context deterministically
- assembling an inspectable runtime payload
- invoking one configured agent adapter
- returning the adapter exit status

Do not add, without explicit maintainer approval:

- general workflow execution
- arbitrary shell, subprocess, tool, or MCP-driven execution
- long-running autonomous loops
- memory, persistence, or session continuation for `personakit run`
- lead-worker, RPI, multi-agent, or orchestration control flows
- additional supported adapters
- legacy task-management or workflow-platform concepts

Determinism is required. Output must be stable across runs. Sort by id where
ordering matters. Do not add timestamps, UUIDs, or environment-specific data
unless the maintainer explicitly asks for them or the product surface already
requires them.

## MCP Rules

PersonaKit MCP is read-only context and provenance.

MCP resources, prompts, and tools do not authorize:

- writes to the PersonaKit root or repository
- command execution
- workflow orchestration
- autonomous planning or autonomous work

Do not use MCP as a write path, command-execution channel, or substitute for
maintainer approval.

## Git And Closeout

Use Conventional Commits when creating commits:

- `type(scope): summary` when a clear scope exists
- `type: summary` otherwise

Do not create extra branches or worktrees unless the maintainer asks for them.
Treat packets, tasks, and stories as docs/commit scope, not as branch or
worktree requests by default.

## Questions And Approval Gates

Ask before:

- destructive commands or data deletion
- dependency installation
- credential, signing, notarization, or release configuration changes
- public behavior or public API changes
- adding adapters
- broad network work
- commits, pushes, tags, releases, or pull requests
- expanding the requested scope

Stop at explicit review points in an active PersonaKit directive, intent
template, or maintainer instruction.

When requirements are ambiguous, ask a clear, scoped question. Do not guess or
fill in missing product requirements.
