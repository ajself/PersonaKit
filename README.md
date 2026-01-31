PersonaKit

PersonaKit is an execution-free system for structuring AI work around real professional roles.

It helps you work with AI agents the same way you work with people on a strong team: clear roles, explicit constraints, shared standards, and well-defined tasks — without automation magic or hidden behavior.

If you’ve ever thought “this agent is smart, but it doesn’t work the way we do”, PersonaKit is for you.

⸻

What PersonaKit is

PersonaKit lets you define:
	•	Personas — who the agent is supposed to be (a role you would actually hire)
	•	Kits — how that role works (standards, constraints, style, guardrails)
	•	Tasks — what work is being done right now

PersonaKit then:
	•	validates everything deterministically
	•	resolves relationships by ID
	•	exports a single, predictable session prompt

PersonaKit never executes code, runs tools, or makes decisions for you.

⸻

What PersonaKit is not

PersonaKit is deliberately not:
	•	an agent framework
	•	a planner or workflow engine
	•	a skills runtime
	•	an automation system
	•	a replacement for Codex, ChatGPT, or editor agents

PersonaKit prepares context. Agents execute elsewhere.

⸻

The core model (in one minute)

Persona (role)
   ↓ brings
Kit(s) (standards + constraints)
   ↓ applied to
Task (work to do now)
   ↓ exported as
Session prompt → pasted into an agent

This mirrors how strong engineering teams actually work.

⸻

Personas: real roles, not vibes

A Persona represents a role you would hire for.

Examples:
	•	Senior SwiftUI Engineer
	•	Pragmatic Product Manager
	•	Code Review Physician

A Persona defines:
	•	responsibilities
	•	values and judgment
	•	blind spots and non-goals
	•	default Kits it brings to the job

PersonaKit requires a persona for any export. There is no omniscient “do everything” agent.

⸻

Kits: how work gets done

A Kit is a reusable bundle of professional context.

Kits typically include:
	•	style guides
	•	tools & constraints
	•	environment assumptions
	•	non-goals / anti-patterns
	•	approved intent templates
	•	skill awareness

Kits are composable and reusable across personas.

A Persona defines the role. A Kit defines how that role works.

⸻

Tasks: explicit work, no improvisation

A Task defines the work being done right now.

Tasks include:
	•	a concrete goal
	•	ordered steps
	•	acceptance criteria
	•	verification instructions
	•	explicit stop points for review

Tasks prevent scope creep and invented plans.

⸻

Intent Templates: repeatable judgment

An Intent Template encodes how a class of work should be approached.

Examples:
	•	Safe Swift refactor
	•	Add tests without behavior changes
	•	Accessibility review

Intent Templates:
	•	are reusable
	•	may be parameterized
	•	reference required standards and skills
	•	never execute anything

They are PersonaKit’s alternative to executable “skills”.

⸻

Skills: descriptive only

PersonaKit acknowledges that agents have capabilities.

A Skill describes:
	•	what a capability is
	•	who provides it
	•	its risk level

Skills:
	•	are metadata only
	•	contain no commands
	•	are never invoked by PersonaKit

PersonaKit describes skills so intent can be explicit and bounded.

⸻

Essentials: ground truth

Essentials are foundational context that is always included.

Typically:
	•	Swift / SwiftUI style guides
	•	tools & constraints
	•	environment assumptions
	•	non-goals

Essentials are included verbatim in exports.

⸻

What you can do today

PersonaKit provides a small, intentional CLI:

personakit init <path>
personakit validate --root <path>
personakit export --root <path> --persona <id> --task <id>
personakit list personas|kits|tasks|intents|skills|essentials
personakit graph --root <path> --persona <id> --task <id>

Everything is deterministic and testable.

⸻

Determinism & safety

PersonaKit guarantees:
	•	no execution (no subprocesses, no shell calls)
	•	deterministic output
	•	stable ordering
	•	explicit errors
	•	no hidden state

If it validates, it will export. If it doesn’t validate, it won’t.

⸻

Why this exists

AI tools are powerful, but most fail in the same ways:
	•	style drift
	•	constraint erosion
	•	hallucinated confidence
	•	forgotten decisions

PersonaKit doesn’t try to make agents smarter.

It makes expectations explicit.

⸻

Who this is for

PersonaKit is designed for:
	•	senior and staff-level engineers
	•	people used to working with PMs and designers
	•	teams that care about standards and correctness
	•	anyone new to AI who wants predictability first

⸻

Philosophy
	•	boring over clever
	•	explicit over inferred
	•	structure over autonomy
	•	humans in control

If a feature violates these principles, it’s out of scope.

⸻

Status

PersonaKit is an MVP that is already useful.

The next step is real-world use, not more abstraction.

⸻

PersonaKit helps AI agents behave like disciplined teammates — without giving up control.