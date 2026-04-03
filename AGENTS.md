AGENTS.md

Purpose: Define how AI agents should interact with PersonaKit (CLI and MCP), and what they are explicitly not allowed to do.

This file is written for both humans and AI agents. It is a binding behavioral contract.

⸻

Role of AI Agents in This Repo

AI agents (Codex, ChatGPT, editor agents, etc.) are assistants, not decision-makers.

They are expected to:
	•	read PersonaKit configuration and packs
	•	follow Personas, Kits, and Directives exactly
	•	propose changes as diffs or patches
	•	stop when constraints or stop points are reached

Agents may interact with PersonaKit via:
• the [Swift CLI](./README.md#using-personakit)
• the [PersonaKit MCP server](./README.md#mcp-server-read-only) (agent-invoked, read-only)

In both cases, PersonaKit is primarily a source of context, not an autonomous execution engine. For V1, the CLI may launch one explicitly requested external agent through `personakit run`. MCP access does not authorize action.

Reference:
• [Using PersonaKit](./README.md#using-personakit)
• [MCP Server (read-only)](./README.md#mcp-server-read-only)

They are not expected to:
	•	invent plans
	•	broaden scope
	•	refactor for taste
	•	execute commands autonomously

⸻

Ground Rules (Hard Constraints)

Agents must follow these rules at all times:
	1.	Execution is narrowly bounded
	•	Outside the V1 `personakit run` path, do not add code that runs shell commands, subprocesses, or tools
	•	The only allowed execution path in V1 is `personakit run`, and it is limited to resolving PersonaKit context deterministically, assembling a runtime payload, invoking one configured agent adapter, and returning the adapter exit status
	•	Do not introduce general workflow execution, long-running agent loops, platform-runtime behavior, or arbitrary tool invocation
	•	Do not introduce `Process`, `NSTask`, `system()`, or equivalents outside the narrow `personakit run` launcher path
	•	Do not attempt to use MCP Tools to perform execution (PersonaKit MCP exposes Resources and Prompts only).
	•	Do not request or simulate command execution via MCP prompts.
	2.	V1 run guardrails
	•	Do not add more than one supported adapter without AJ's explicit approval
	•	Do not add orchestration patterns such as lead-worker, RPI, or multi-agent control flows
	•	Do not add persistence, memory, or session continuation to `personakit run`
	•	Do not redesign Studio as part of V1 run work
	•	Do not reintroduce Orbit or Taskboard concepts
	3.	No autonomous planning
	•	Do not invent steps beyond what is defined in a Directive
	•	If something is unclear, ask for clarification
	4.	No scope expansion
	•	Do not refactor unrelated code
	•	Do not introduce new abstractions unless explicitly requested
	5.	One approved lane/worktree per milestone by default
	•	Default to one approved execution lane and one worktree per milestone or explicitly approved slice
	•	Do not create packet-, task-, or story-specific branches or worktrees unless AJ explicitly approves extra isolation
	•	Treat packets, tasks, and stories as scope tracked in docs and commits, not as branch or worktree requests by default
	6.	Determinism is required
	•	Output must be stable across runs
	•	Sort by id where ordering matters
	•	Do not add timestamps, UUIDs, or environment-specific data
	7.	Persona activation is explicit
	•	Do not operate as multiple active personas at the same time
	•	When persona assignment changes, reload PersonaKit grounding before continuing
	•	PersonaKit grounding must happen before external skill selection
	•	Only skills authorized by the resolved PersonaKit contract may be used
	•	Undeclared host-local or external skills are unauthorized by default
	•	On skill mismatch, stop and re-ground rather than improvising
	•	Delegated agents must receive one authoritative persona assignment for their lane
	•	Review personas are not the same thing as active execution identity
	8.	Use Conventional Commits
	•	When creating a git commit, use Conventional Commit format: `type(scope): summary` when a clear scope exists, otherwise `type: summary`
	•	Do not invent repo-specific commit formats or rely on memory for commit style
	9.	Human review is mandatory at stop points
	•	If a Directive or IntentTemplate indicates a stop point or review requirement, stop and wait
	10. MCP usage is read-only
	   • Treat all MCP Resources as immutable context
	   • Prompts return assembled context only; they do not imply permission to act
	   • Never attempt to write back to the PersonaKit root via MCP

⸻

How Agents Should Use PersonaKit

Agents should treat PersonaKit as the source of truth for context.

When working on this repo, agents should:
	1.	Identify the active Persona
	2.	Identify the active Kit(s)
	3.	Identify the active Directive
	4.	Use only the skills allowed by the Persona
	5.	Treat the resolved persona as the single active operating contract until explicitly reassigned
	•	Runtime grounding includes PersonaKit’s built-in persona-activation contract even when no authored override file exists
	•	Runtime grounding also includes PersonaKit’s built-in `skill-authorization-contract` unless a project-local override replaces it
	6.	Follow all constraints and non-goals verbatim

When using the MCP server specifically:
• Prefer reading [Resources](./README.md#mcp-server-read-only) for raw context (personas, kits, directives, essentials)
• Prefer [Prompts](./README.md#mcp-server-read-only) for resolved session views (export, graph)
• Do not mix MCP-derived context with ad-hoc assumptions

If PersonaKit validation fails, agents should not proceed.

When implementing or reviewing `personakit run` specifically:
• Treat it as a narrow launcher, not a general automation surface
• Keep execution-light behavior everywhere outside that one command
• Preserve the boundary between context resolution and external agent execution

⸻

Expected Agent Outputs

Agents should prefer:
	•	small, reviewable diffs
	•	explicit explanations of changes
	•	clear mapping between changes and Directive steps
	•	explicit persona reassignment rather than blended multi-persona behavior
	•	Conventional Commit messages for any authorized commit

Agents should avoid:
	•	rewriting large sections of code
	•	introducing speculative improvements
	•	silently changing behavior
	•	treating MCP prompts as authorization to act without review

⸻

Interaction Model

Agents should assume a human-in-the-loop workflow:
	•	Propose changes
	•	Wait for review or confirmation
	•	Iterate based on feedback

Agents should never assume they are operating autonomously.

⸻

Local-Only Closeout Protocol (complete worktree)

When the user requests `complete worktree`, agents must use the repository
workflow command:

• `make complete-worktree`

Hard rule:
	•	Never delete a lane branch or worktree before verifying that `main`
	contains the lane commits (ancestor verification is mandatory).

⸻

Questions & Uncertainty

If an agent encounters ambiguity:
	•	Ask a clear, scoped question
	•	Do not guess
	•	Do not “fill in” missing requirements

Example:

“The Directive does not specify whether API behavior may change. Should this change be behavior-preserving only?”

⸻

Why This File Exists

Without explicit guardrails, AI agents tend to:
	•	over-generalize
	•	over-refactor
	•	optimize prematurely

[AGENTS.md](./AGENTS.md) exists to prevent that.

PersonaKit is designed to keep humans in control while still benefiting from AI assistance.

⸻

Summary (for agents)
	•	PersonaKit defines the role, constraints, and directive — not you
	•	Use CLI outputs and MCP [Resources](./README.md#mcp-server-read-only) / [Prompts](./README.md#mcp-server-read-only) as authoritative context
	•	MCP is read-only; it never authorizes execution or writes
	•	The only V1 execution exception is the narrow `personakit run` launcher path
	•	Do not expand scope or invent steps
	•	Stop at explicit review points

If you are unsure, ask.
