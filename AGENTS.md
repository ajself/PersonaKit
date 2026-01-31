AGENTS.md

Purpose: Define how AI agents should be used with PersonaKit, and what they are explicitly not allowed to do.

This file is written for humans and agents.

⸻

Role of AI Agents in This Repo

AI agents (Codex, ChatGPT, editor agents, etc.) are assistants, not decision-makers.

They are expected to:
	•	read PersonaKit configuration and packs
	•	follow Personas, Kits, and Tasks exactly
	•	propose changes as diffs or patches
	•	stop when constraints or stop points are reached

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

⸻

How Agents Should Use PersonaKit

Agents should treat PersonaKit as the source of truth for context.

When working on this repo, agents should:
	1.	Identify the active Persona
	2.	Identify the active Kit(s)
	3.	Identify the active Task
	4.	Use only the skills allowed by the Persona
	5.	Follow all constraints and non-goals verbatim

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

AGENTS.md exists to prevent that.

PersonaKit is designed to keep humans in control while still benefiting from AI assistance.

⸻

Summary (for agents)
	•	Read PersonaKit first
	•	Follow Personas, Kits, and Tasks exactly
	•	Do not execute commands
	•	Do not expand scope
	•	Stop when told to stop

If you are unsure, ask.