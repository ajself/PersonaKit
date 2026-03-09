

# RFC-0001: Persona Activation and Default Directive Model

## Status
Draft

## Authors
AJ Self

## Created
2026-03-08

## Last Updated
2026-03-08

## Related
RFC-0002 – Conversation and Memory Data Model
RFC-0003 – Workspace and Persona Instance Model

---

# Summary

This RFC defines how personas are activated within Orbit conversations and meetings.

Persona activation is the mechanism that determines:

- which persona is speaking
- which workspace context applies
- which directive governs reasoning
- which memory sources are available
- how responses are attributed and traceable

The goal is to ensure that persona behavior remains **deterministic, explainable, and consistent across clients and sessions**.

---

# Motivation

Orbit treats AI collaborators as persistent roles rather than disposable prompts. In order for this to work reliably, the system must always know exactly how a persona enters a conversation.

Without an explicit activation model:

- persona behavior becomes unpredictable
- memory retrieval becomes inconsistent
- attribution becomes impossible to audit
- conversations lose structural meaning

Persona activation therefore becomes a **core system primitive**.

---

# Problem Statement

When a user sends a message such as:

> "Wear the Product Designer for the Bar project."

The system must resolve the following questions deterministically:

1. Which workspace is being referenced?
2. Which persona instance belongs to that workspace?
3. Which directive should guide the response?
4. Which memory scope should be loaded?
5. How should the activation be recorded for traceability?

This RFC defines the rules that answer those questions.

---

# Goals

The activation model must:

- ensure persona identity is explicit
- resolve workspace context deterministically
- apply directives consistently
- enable memory retrieval with proper scope
- provide traceability for every persona response
- support multi‑persona meetings

---

# Non‑Goals

This RFC does not define:

- the final prompt templates used during activation
- the specific AI provider APIs
- UI behavior in Orbit clients

Those are implementation details outside the scope of this document.

---

# Persona Templates vs Workspace Personas

Orbit separates persona identity into two layers.

## Persona Template

A global definition of a role.

Examples:

- Product Designer
- Senior SwiftUI Engineer
- Product Manager

Templates define:

- role description
- values and constraints
- default directive
- allowed capabilities

Templates contain **no workspace‑specific memory**.

## Workspace Persona

A workspace persona is an instance of a template within a workspace.

Example:

Workspace: Bar  
Persona Template: Product Designer  
Workspace Persona: bar-product-designer

Workspace personas accumulate:

- conversation history
- journals
- workspace memory
- meeting participation

Activation always targets **workspace personas**, not templates.

---

# Directive Resolution

Each persona enters a conversation through a directive that determines its reasoning mode.

Examples:

- design-advisory
- technical-analysis
- product-evaluation

Directive resolution follows this priority:

1. Explicit directive in the user request
2. Directive defined by the session
3. Workspace persona directive override
4. Persona template default directive

If no directive can be resolved, activation must fail.

---

# Activation Record

Every persona activation produces a durable record.

Example structure:

persona_activation

- workspace_id
- persona_instance_id
- directive_id
- trigger_message_id
- activation_reason
- template_version
- created_at

This record allows Orbit to explain why a persona responded.

---

# Activation Pipeline

The activation pipeline follows this sequence:

User message
↓
Workspace resolution
↓
Persona instance resolution
↓
Directive resolution
↓
Memory retrieval
↓
Context assembly
↓
Agent run execution
↓
Response persistence

Each stage must be observable through system events.

---

# Memory Retrieval

Memory is retrieved in a layered order:

1. Workspace memory
2. Workspace persona journals
3. Persona global memory profile
4. Linked cross‑workspace memory
5. Organization memory

This ordering prioritizes **local context before global patterns**.

---

# Traceability

Every persona response must reference:

- the persona activation
- the directive used
- the agent run id
- the memory sources used

This ensures that Orbit conversations remain inspectable and debuggable.

---

# Edge Cases

### Ambiguous persona

If multiple personas match the request, Orbit must request clarification.

### Missing directive

Activation fails and suggests possible directives.

### Template update mid‑conversation

Activation records must reference the template version used.

### Memory retrieval failure

The run may proceed without memory but must record degraded context.

---

# Recommendation

Adopt the persona activation model described in this RFC as the canonical mechanism for introducing personas into conversations and meetings.

This model ensures that Orbit maintains deterministic behavior while allowing personas to evolve through workspace‑scoped experience.

---

# Decision Log

2026‑03‑08 — Initial draft created