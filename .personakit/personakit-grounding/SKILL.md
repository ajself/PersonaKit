---
name: personakit-grounding
description: Resolve PersonaKit or PK sessions before acting. Use when the user asks to operate under, resolve, inspect, recommend, trace, activate, export, or use a PersonaKit session or PK session; route through PersonaKit MCP or CLI contract resolution before reading raw .personakit or ~/.personakit files.
---

# PersonaKit Grounding

## Purpose

Use PersonaKit as the source of resolved contract truth. Do not crawl raw `.personakit` or `~/.personakit` JSON as the first step when a user asks to use, resolve, inspect, recommend, trace, activate, export, or operate under a PersonaKit session.

This is a host-local skill. It helps an agent invoke PersonaKit correctly from a familiar skill, autocomplete, or command-palette surface. PersonaKit remains the authority for the operating contract.

## Trigger Phrases

Treat these as PersonaKit-session intent:

- "PersonaKit session" or "PK session"
- "operate under ..."
- "use the ... session"
- "resolve contract"
- "recommend a session"
- "trace session"
- "activate session"
- "work from session"

## Required Workflow

1. Identify the intended PersonaKit root and session id if the user supplied them.
2. Prefer PersonaKit MCP resources and tools:
   - Read `personakit://catalog/start` if the client or scope is unfamiliar.
   - Read session catalog resources when listing or selecting sessions.
   - Call `personakit_recommend_session` when no session id is supplied.
   - Call `personakit_resolve_contract` for the selected session.
   - Call `personakit_trace_session` when provenance, source files, or dependency reasons matter.
   - Call `personakit_export` only when a human-readable grounding payload is needed.
3. If MCP tools are unavailable, use the installed `personakit` executable for CLI fallback:
   - `personakit guidance`
   - `personakit list sessions`
   - `personakit recommend --goal "<task>"`
   - `personakit contract --session <id>`
   - `personakit contract --root <root> --session <id>` for repo-local session grounding
   - `personakit export --session <id>`
   - `personakit validate`
4. Treat the resolved contract as authoritative for persona, directive, kits, skills, skill authorization, stop points, and provenance.
5. Continue the user's requested work only after the contract resolves cleanly.

## Host Skill vs PersonaKit Skill

- This skill is a host skill: it tells the agent how to ground itself in PersonaKit.
- PersonaKit skill declarations are contract metadata: they describe capabilities that a resolved session may allow, require, or forbid.
- A host-local skill being available does not mean the PersonaKit contract authorizes its use.
- If the resolved contract forbids or omits a needed capability, stop and ask for re-grounding, reassignment, or operator approval.

## Root Selection

- Prefer an explicit root from the user.
- If the user says global, personal, or does not specify a project-local root, use the configured/global PersonaKit root.
- For repo-local PersonaKit grounding, use the project `.personakit` root only when the user asks for repo-local grounding or the task clearly depends on repo-local PersonaKit content.
- If global and repo-local roots conflict, stop and ask which root should govern.

Examples:

- Explicit project root: resolve with `personakit contract --root <path> --session <id>`.
- Repo-local request: use the current project's `.personakit` root when present and relevant.
- Global/personal request: use the configured global root.
- Ambiguous request with both project and global candidates: stop and ask which root governs.

## Raw File Access

Read raw PersonaKit files only when:

- The user asks to create, edit, or review PersonaKit content.
- MCP or CLI resolution fails and file-level diagnostics are needed.
- The task is explicitly pack authoring or schema/content maintenance.

Even then, use MCP or CLI resolution first when possible so file reads are grounded by a failing or resolved contract.

## Stop Conditions

Stop and report clearly when:

- The requested session cannot be resolved.
- PersonaKit MCP and CLI fallback are both unavailable.
- The root is ambiguous and choosing one would change authority.
- The task would mutate public behavior, adapters, runtime execution, memory, persistence, or orchestration without explicit approval.

## What This Skill Is Not

- It does not execute PersonaKit-authored work.
- It does not authorize a forbidden host skill, tool, write, command, deployment, or handoff.
- It does not turn PersonaKit into an agent launcher, workflow engine, memory system, or orchestration layer.
- It does not replace operator approval when the resolved contract requires a stop.

## Examples

User: "Operate under the global staff-code-quality-review session and review Sources/Shared."

Expected routing: resolve `staff-code-quality-review` from the global PersonaKit root through MCP or CLI, then perform the review under that contract. Do not inspect raw JSON first.

User: "Use the pack-authoring session to draft a new PersonaKit session."

Expected routing: resolve `pack-authoring`, then inspect or edit raw PersonaKit files only as part of the requested authoring work.

User: "Recommend a PersonaKit session for Staff-level code review."

Expected routing: call `personakit_recommend_session` or `personakit recommend --goal ...`; do not browse sessions by reading files first.
