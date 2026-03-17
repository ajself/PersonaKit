# Orbit RFCs

This directory contains **Requests for Comments (RFCs)** for major architectural, platform, and product decisions in Orbit.

RFCs exist to ensure that important decisions are:

- explicit  
- documented  
- reviewable  
- historically traceable

Rather than making architectural changes directly in code, proposals should first be described and evaluated through an RFC.

This process helps keep the Orbit architecture coherent as the platform evolves.

---

# When to Write an RFC

Create an RFC when proposing changes that affect:

- system architecture  
- data models  
- platform behavior  
- runtime orchestration  
- memory systems  
- workspace or persona semantics  
- cross‑client platform behavior

Small implementation details, refactors, and bug fixes do **not** require RFCs.

---

# RFC Status Lifecycle

Each RFC must include a status indicating where it sits in the decision process.

| Status    | Meaning                         |
|-----------|--------------------------------|
| Draft     | Initial proposal open for discussion |
| In Review | Actively being evaluated        |
| Accepted  | Agreed architectural direction  |
| Rejected  | Proposal considered but declined |
| Superseded| Replaced by a later RFC          |

RFCs should begin as **Draft** and move through review before being considered accepted.

---

# RFC Structure

A well‑formed RFC should include the following sections:

- Summary  
- Motivation  
- Problem Statement  
- Goals  
- Non‑Goals  
- Proposal  
- Architecture / System Design  
- Data Model (if applicable)  
- Edge Cases and Failure Modes  
- Alternatives Considered  
- Risks and Tradeoffs  
- Recommendation  
- Rollout / Adoption Plan  
- Self‑Review

The goal is not to predict every implementation detail, but to clearly explain the reasoning behind the proposed design.

---

# Current RFC Set

The initial RFCs establish the architectural foundation for Orbit.

1. **RFC‑0001 – Workspace Persona Contract Resolution and Activation Model**  
   Defines how workspace persona contracts are resolved, activated, and traced during interactions.

2. **RFC‑0002 – Collaboration Runtime and Memory Data Model**  
   Defines the durable runtime model for channels, posts, threads, structured objects, journals, and memory.

3. **RFC‑0003 – Workspace, Group, and Workspace Persona Instance Model**  
   Defines workspace boundaries, persistent groups, and how persona templates become workspace persona instances.

4. **RFC‑0004 – Teams, Squads, and Meeting Coordinator Model**  
   Defines structured collaboration groups and the orchestration role of the Meeting Coordinator.

5. **RFC‑0005 – Memory Journaling and Gardening Model**  
   Defines the lifecycle from activity → journals → memory candidates → approved memory.

6. **RFC‑0006 – Multi‑Client Platform Architecture**  
   Defines how Orbit operates across macOS, iPhone, and iPad clients with a unified backend platform.

---

# Reading Order

If you are new to the Orbit architecture, the recommended reading order is:

1. RFC‑0001 – Workspace Persona Contract Resolution  
2. RFC‑0003 – Workspace, Groups, & Persona Model  
3. RFC‑0002 – Collaboration Runtime & Memory Model  
4. RFC‑0004 – Teams, Squads, Coordinator  
5. RFC‑0005 – Memory System  
6. RFC‑0006 – Platform Architecture

Together these RFCs define the core behavior of the Orbit system.

---

# Relationship to the Platform

Orbit is the **platform for running AI teams**.

PersonaKit is the **engine within Orbit** responsible for:

- persona templates  
- workspace persona contract resolution  
- skill authorization and operating constraints  
- memory grounding

These RFCs primarily describe how the Orbit platform and PersonaKit engine work together.

---

# Guiding Philosophy

Orbit follows several guiding principles:

- **Operator-centered control** — the user remains the authority.  
- **Deterministic activation** — persona behavior is grounded explicitly.  
- **Structured collaboration** — teams and squads organize work.  
- **Durable learning** — knowledge evolves through journals and reviewed memory.  
- **Explainability** — system decisions should always be traceable.

These principles should guide future RFCs and platform evolution.

---
