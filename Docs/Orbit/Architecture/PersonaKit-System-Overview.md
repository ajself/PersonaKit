# Orbit Platform Architecture Overview

This document provides the canonical architecture overview for the Orbit platform.

Orbit is the command center for running persistent AI teams. A human founder operates workspaces representing ventures or projects, and each workspace contains teams and squads of personas that collaborate through conversations and meetings.

PersonaKit is the engine inside Orbit responsible for persona identity, activation, directives, and memory grounding.

This document explains the high‑level system structure so engineers and collaborators can understand how the platform fits together before diving into individual RFCs.

---

# What Orbit Is

Orbit is a platform for running AI teams.

A founder operates one or more workspaces representing products, research efforts, or experiments. Within those workspaces, personas collaborate as members of teams and squads.

Orbit provides:

- persistent conversations
- coordinated meetings
- persona identity and activation
- durable memory
- multi‑device collaboration

PersonaKit powers the identity and reasoning layer within Orbit.

---

# Core Concepts

Orbit organizes collaboration using several key objects:

Workspace  
A venture, project, or research environment.

Team  
A durable group of personas within a workspace.

Squad  
A focused working group for a specific initiative.

Persona Template  
A global definition of a role.

Workspace Persona  
A persona instance operating inside a workspace.

Meeting  
A coordinated interaction between multiple personas.

Memory  
Durable knowledge derived from prior work.

---

# System Overview Diagram

```text
                           AJ (User)
                               │
                               ▼
                       Orbit Client Apps
        ┌─────────────────────┬─────────────────────┬─────────────────────┐
        │ macOS App           │ iOS App             │ iPad App            │
        │ Command Center      │ Notifications       │ Meeting Workspace   │
        │ Persona Editing     │ Quick Chat          │ Team Collaboration  │
        │ Memory Review       │ Memory Approvals    │ Squad Discussions   │
        └─────────────────────┴─────────────────────┴─────────────────────┘
                               │
                               ▼
                         Orbit Gateway
                     (API + Realtime Layer)
                               │
                               ▼
                    Conversation Coordination
                ┌─────────────────────────────────┐
                │ Meeting Coordinator             │
                │ Persona Activation Engine       │
                │ Squad Expansion Logic           │
                │ Run Orchestration               │
                └─────────────────────────────────┘
                               │
                               ▼
                         Persona Runtime
            ┌────────────────────────────────────────┐
            │ Persona Template                       │
            │ Workspace Persona Instance             │
            │ Directive Resolution                   │
            │ Memory Retrieval                       │
            │ Context Assembly                       │
            └────────────────────────────────────────┘
                     │                     │
                     ▼                     ▼
         External Capability Layer      Memory System
    ┌─────────────────────────────┐   ┌─────────────────────────────┐
    │ OpenAI Codex API            │   │ Journals                    │
    │ GitHub APIs / MCP           │   │ Memory Candidates           │
    │ Future tools/services       │   │ Approved Memory             │
    └─────────────────────────────┘   │ Memory Link Graph           │
                                      │ Persona Global Profiles     │
                                      └─────────────────────────────┘
                               │
                               ▼
                       Persistence Layer
           ┌──────────────────────────────────────────┐
           │ Postgres                                 │
           │ Conversations                            │
           │ Messages                                 │
           │ Meetings                                 │
           │ Persona Activations                      │
           │ Agent Runs                               │
           │ Journals                                 │
           │ Memory Entries                           │
           └──────────────────────────────────────────┘
                               │
                               ▼
                      Artifact Storage Layer
                ┌────────────────────────────────┐
                │ Synology NAS                   │
                │ Workspace artifacts            │
                │ Pack repositories              │
                │ Research docs                  │
                │ Snapshots / backups            │
                └────────────────────────────────┘
                               │
                               ▼
                       Hardware Infrastructure
                 ┌─────────────────────────────┐
                 │ Mac mini                    │
                 │ Coordination Services       │
                 │ Persona Runtime             │
                 │ Postgres Database           │
                 └─────────────────────────────┘
```

---

# Runtime Interaction Flow

Example interaction:

```text
AJ sends message
      ↓
Client calls Gateway API
      ↓
ConversationMessage stored
      ↓
ConversationEvent emitted
      ↓
Meeting Coordinator selects participants
      ↓
PersonaActivation records created
      ↓
AgentRun executed
      ↓
Persona responses stored
      ↓
Realtime update pushed to clients
      ↓
Journals generated
      ↓
Memory candidates proposed
      ↓
User approves memory
```

This flow transforms a single user message into a coordinated interaction between AI personas.

---

# Workspace Lifecycle

A workspace represents a venture, project, or research track. Over time a workspace evolves through a predictable lifecycle of collaboration and learning.

Typical lifecycle:

```text
Workspace created
    ↓
Teams and squads defined
    ↓
Initial conversations begin
    ↓
Meetings occur between personas
    ↓
Summaries and journals generated
    ↓
Memory candidates proposed
    ↓
User reviews and approves memory
    ↓
Workspace knowledge grows
```

Workspaces provide the structural boundary for:

- conversations
- teams and squads
- workspace personas
- journals
- memory

Over time a workspace becomes a durable knowledge base for that venture or project.

---

# Architectural Layers

## Human Layer

The human remains the authority.

Responsibilities:

- ask questions
- steer conversations
- approve memory
- define workspaces
- define persona templates

---

## Client Layer

Orbit supports multiple client interfaces.

### macOS App
Primary command center for operations and system management.

### iPhone App
Fast interaction surface for quick chat, notifications, and approvals.

### iPad App
Collaboration workspace optimized for meetings and squad discussions.

---

## Gateway Layer

The gateway manages platform access.

Responsibilities include:

- authentication
- message ingestion
- client synchronization
- realtime updates

---

## Coordination Layer

The Meeting Coordinator orchestrates collaboration.

Responsibilities include:

- selecting participants
- expanding squads
- invoking personas
- determining meeting completion

---

## Persona Runtime Layer

PersonaKit implements the runtime responsible for persona reasoning.

Inputs include:

- persona template
- workspace persona instance
- directive
- kits
- essentials
- memory

Outputs include persona responses and run traces.

---

## Memory Layer

Knowledge evolves through a staged model:

conversation → journal → memory candidate → approved memory

Memory scopes may include:

- workspace
- workspace persona
- persona global
- organization

---

## Persistence Layer

Postgres stores runtime system state including conversations, meetings, activations, journals, and memory.

---

## Artifact Storage

Large files and archives are stored outside the transactional database on NAS storage.

---

## Hardware Layer

Recommended deployment:

Mac mini — compute brain
Synology NAS — artifact vault

---

# System Principles

Orbit follows several architectural principles:

Human‑centered  
The human remains the authority.

Deterministic activation  
Personas activate through explicit context.

Structured collaboration  
Teams and squads organize work.

Durable learning  
Knowledge evolves through journals and reviewed memory.

Explainability  
Every response can be traced to its inputs.

Platform‑first design  
Clients are interfaces; the platform holds truth.

---

# Relationship to the RFC Set

```text
RFC‑0001 Persona Activation
        ↓
RFC‑0003 Workspace Persona Model
        ↓
RFC‑0002 Conversation & Memory Data Model
```

Together these RFCs define identity, interaction, and memory within Orbit.

---

# Why This Document Matters

This overview acts as the north‑star architecture for the Orbit platform. All new features should map clearly to one of the layers described here.

If a new capability does not fit within this model, it should trigger a design discussion before implementation proceeds.