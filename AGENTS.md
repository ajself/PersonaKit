AGENTS.md

Purpose: Define how AI agents should interact with PersonaKit (CLI and MCP), and what they are explicitly not allowed to do.

This file is written for both humans and AI agents. It is a binding behavioral contract.

⸻

Role of AI Agents in This Repo

AI agents (Codex, ChatGPT, editor agents, etc.) are assistants, not decision-makers.

They are expected to:
	•	read PersonaKit configuration and packs
	•	follow Personas, Kits, and Tasks exactly
	•	propose changes as diffs or patches
	•	stop when constraints or stop points are reached

Agents may interact with PersonaKit via:
• the [Swift CLI](./README.md#using-personakit)
• the [PersonaKit MCP server](./README.md#mcp-server-read-only) (agent-invoked, read-only)

In both cases, PersonaKit is a source of context, not an execution engine.

They are not expected to:
	•	invent plans
	•	broaden scope
	•	refactor for taste
	•	execute commands autonomously

⸻

Ground Rules (Hard Constraints)

Agents must follow these rules at all times:
	1.	No execution inside PersonaKit
	•	Do not add code that runs shell commands, subprocesses, or tools
	•	Do not introduce Process, NSTask, system(), or equivalents
	•	Do not attempt to use MCP Tools to perform execution (PersonaKit MCP exposes Resources and Prompts only).
	•	Do not request or simulate command execution via MCP prompts.
	2.	No autonomous planning
	•	Do not invent steps beyond what is defined in a Task
	•	If something is unclear, ask for clarification
	3.	No scope expansion
	•	Do not refactor unrelated code
	•	Do not introduce new abstractions unless explicitly requested
	4.	Determinism is required
	•	Output must be stable across runs
	•	Sort by id where ordering matters
	•	Do not add timestamps, UUIDs, or environment-specific data
	5.	Human review is mandatory at stop points
	•	If a Task or IntentTemplate indicates a stop point or review requirement, stop and wait
	6. MCP usage is read-only
	   • Treat all MCP Resources as immutable context
	   • Prompts return assembled context only; they do not imply permission to act
	   • Never attempt to write back to the PersonaKit root via MCP

⸻

How Agents Should Use PersonaKit

Agents should treat PersonaKit as the source of truth for context.

When working on this repo, agents should:
	1.	Identify the active Persona
	2.	Identify the active Kit(s)
	3.	Identify the active Task
	4.	Use only the skills allowed by the Persona
	5.	Follow all constraints and non-goals verbatim

When using the MCP server specifically:
• Prefer reading [Resources](./README.md#mcp-server-read-only) for raw context (personas, kits, tasks, essentials)
• Prefer [Prompts](./README.md#mcp-server-read-only) for resolved session views (export, graph)
• Do not mix MCP-derived context with ad-hoc assumptions

If PersonaKit validation fails, agents should not proceed.

⸻

Expected Agent Outputs

Agents should prefer:
	•	small, reviewable diffs
	•	explicit explanations of changes
	•	clear mapping between changes and Task steps

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

Questions & Uncertainty

If an agent encounters ambiguity:
	•	Ask a clear, scoped question
	•	Do not guess
	•	Do not “fill in” missing requirements

Example:

“The Task does not specify whether API behavior may change. Should this change be behavior-preserving only?”

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
	•	PersonaKit defines the role, constraints, and task — not you
	•	Use CLI outputs and MCP [Resources](./README.md#mcp-server-read-only) / [Prompts](./README.md#mcp-server-read-only) as authoritative context
	•	MCP is read-only; no execution or writes are permitted
	•	Do not expand scope or invent steps
	•	Stop at explicit review points

If you are unsure, ask.