# Orbit Architecture Index

Start here:

Platform Overview
-> RFC-0006 Orbit Platform Architecture
-> RFC-0001 Contract Resolution
-> RFC-0003 Workspace Model
-> RFC-0002 Collaboration Runtime
-> RFC-0004 Teams & Squads
-> RFC-0005 Memory Gardening

This page provides the recommended reading order for understanding the Orbit system architecture.

The documents below build on each other. Reading them in order will give you a complete picture of how Orbit works.

---

## 1. Platform Overview

Start with the high-level architecture in `RFC-0006`.

It explains the major layers of the system:

- clients
- gateway and realtime
- collaboration services
- PersonaKit resolver
- execution runners
- persistence and artifact storage
- infrastructure

---

## 2. Contract Resolution Model

**RFC‑0001 – Workspace Persona Contract Resolution and Activation Model**

Explains how a workspace persona contract is resolved in runtime context, including:

- persona templates
- workspace persona instances
- contract resolution
- activation context
- attribution and traceability

---

## 3. Workspace and Persona Model

**RFC‑0003 – Workspace, Group, and Workspace Persona Instance Model**

Defines how Orbit organizes work across multiple ventures and projects.

Covers:

- workspaces
- persona templates
- workspace personas
- teams and squads
- persona membership and scope

---

## 4. Collaboration Runtime and Memory Model

**RFC‑0002 – Collaboration Runtime and Memory Data Model**

Defines the durable runtime data model.

Includes:

- channels
- posts
- threads
- messages
- meeting and workstream state
- activations
- agent runs
- journals
- memory entries

---

## 5. Teams, Squads, and Meeting Coordination

**RFC‑0004 – Teams, Squads, and Meeting Coordinator Model**

Explains how group collaboration works in Orbit.

Topics include:

- teams
- squads
- meeting coordination
- participant selection
- meeting lifecycle

---

## 6. Memory Journaling and Gardening

**RFC‑0005 – Memory Journaling and Gardening Model**

Describes how Orbit turns activity into durable knowledge.

Covers:

- journals
- memory candidates
- memory review
- approved memory
- cross‑workspace learning

---

## 7. Multi‑Client Platform Architecture

**RFC‑0006 – Orbit Multi‑Client Platform Architecture**

Describes how Orbit Server and native clients operate together across devices.

Includes:

- macOS command center
- iPhone quick interaction client
- iPad collaboration surface
- gateway and realtime layers
- Orbit Server logical service domains
- infrastructure and deployment

---

## Reading Strategy

If you are new to the system:

1. Read **RFC-0006** first for the highest-level platform view.
2. Continue through the RFCs in the order above.
3. Refer back to earlier sections as needed.

Together these documents define the architectural foundation of Orbit.
