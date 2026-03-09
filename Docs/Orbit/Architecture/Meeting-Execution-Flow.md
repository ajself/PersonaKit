# Meeting Execution Flow

This document describes how a conversation becomes a coordinated meeting between AI personas.

## Flow

1. User sends a message.
2. The message is stored in the conversation database.
3. A conversation event is emitted.
4. The Meeting Coordinator determines which personas should participate.
5. Persona activations are created.
6. Agent runs are started.
7. Personas respond.
8. Responses are stored as conversation messages.
9. Clients receive realtime updates.
10. The meeting is completed.
11. Summaries and journals may be generated.
12. Memory candidates may be proposed.

## Key principles

- the user message must be persisted before orchestration
- persona participation must be explainable
- partial failures must not invalidate the meeting
- memory generation should be staged and reviewable

This flow connects persona activation, conversation state, journaling, and memory promotion.
# Meeting Execution Flow

This document describes how a user message becomes a coordinated interaction between AI personas in Orbit.

It complements the system architecture and RFCs by explaining the **runtime behavior** of the platform.

Specifically it describes:

- how a message becomes a meeting
- how personas are selected and activated
- how responses are executed
- how results propagate back to clients
- how summaries, journals, and memory candidates are created

This is a behavioral description of the system, not a strict implementation spec.

---

# High-Level Execution Model

A meeting begins when the user sends a message that requires one or more personas to respond.

The system transforms that message into a structured execution pipeline.

```
User Message
    ↓
Conversation Message Persisted
    ↓
Conversation Event Emitted
    ↓
Meeting Coordinator Evaluates Context
    ↓
Participant Personas Selected
    ↓
Persona Activations Created
    ↓
Agent Runs Executed
    ↓
Responses Persisted
    ↓
Realtime Updates Broadcast
    ↓
Meeting Completion Determined
    ↓
Summary Generated
    ↓
Journal Entries Created
    ↓
Memory Candidates Proposed
```

---

# Step-by-Step Lifecycle

## 1. User Message

A meeting begins when the user sends a message from any Orbit client.

Possible clients:

- macOS command center
- iPhone quick interaction surface
- iPad collaboration workspace

Example message:

> Wear the Bar product team. What should our onboarding strategy be?

The message may target:

- a specific persona
- a squad
- a team
- an ad‑hoc set of personas

---

## 2. Message Persistence

Before any orchestration occurs, the system must persist the user message.

This creates a durable record:

```
ConversationMessage
```

This record includes:

- conversation id
- workspace id
- author (user)
- message body
- timestamp

### Design Rule

No orchestration should occur before the message is successfully persisted.

This guarantees:

- replayability
- consistency across clients
- deterministic state reconstruction

---

## 3. Conversation Event

After persistence, the system emits a new event:

```
conversation_event(message.created)
```

This event is consumed by coordination services.

Events allow the system to remain event-driven and observable.

---

## 4. Meeting Coordinator Evaluation

The Meeting Coordinator inspects the event and determines whether the message should start or continue a meeting.

The coordinator resolves:

- workspace
- conversation
- addressed persona/team/squad

The coordinator then determines the intended participants.

Possible sources of participants:

- direct persona mention
- team membership
- squad membership
- coordinator-selected experts

---

## 5. Meeting Creation

If the interaction involves multiple personas, the system creates a meeting record.

```
Meeting
```

Meeting metadata may include:

- meeting type
- workspace
- start time
- initiating user

Participants are recorded as:

```
MeetingMembers
```

Each participant records:

- persona id
- participation role
- reason for selection

### Example Roles

- contributor
- reviewer
- observer
- facilitator

---

## 6. Persona Activation

Each selected persona receives a persona activation.

```
PersonaActivation
```

Activation resolves the persona runtime context:

- persona template
- workspace persona instance
- directive
- kits
- essentials
- memory scope

Directive resolution follows this priority:

1. explicit directive in message
2. session directive
3. workspace persona override
4. persona template default

The activation record captures:

- workspace
- persona instance
- directive
- trigger message
- timestamp

This record provides traceability for every response.

---

## 7. Agent Run Execution

Each activation triggers an agent run.

```
AgentRun
```

The run performs the following steps:

1. retrieve persona template
2. retrieve workspace persona instance
3. resolve directive
4. retrieve memory
5. assemble context
6. call external AI provider

External providers may include:

- OpenAI models
- GitHub tools
- other integrations

Run metadata records:

- provider
- model
- start time
- completion status

Optional run steps may record internal stages for debugging.

---

## 8. Persona Responses

When a persona produces a response, it is persisted as a new conversation message.

```
ConversationMessage
```

Author:

```
workspace_persona
```

These messages appear in the conversation thread as chat bubbles.

The system also emits events such as:

- response.started
- response.completed

These drive realtime updates for clients.

---

## 9. Realtime Updates

Clients subscribed to the conversation receive updates.

Examples:

- persona is responding
- new message created
- participant joined
- meeting completed

This allows all devices to stay synchronized.

Clients may include:

- macOS command center
- iPhone notification view
- iPad meeting interface

---

## 10. Meeting Completion

The Meeting Coordinator determines when a meeting is complete.

Completion conditions may include:

- all required personas responded
- timeout reached
- user ended the meeting
- coordinator determines sufficient coverage

Meeting state transitions:

```
created → active → summarizing → completed
```

Failures are also recorded.

---

## 11. Summary Generation

After completion the system may generate a meeting summary.

```
ConversationSummary
```

Summary types may include:

- brief summary
- detailed recap
- decision log
- retrospective

Summaries help users quickly understand outcomes and serve as inputs to journaling.

---

## 12. Journal Generation

Personas or the system may create journal entries reflecting on the meeting.

```
JournalEntry
```

Journals summarize what happened over a time window.

Journal types may include:

- meeting reflection
- milestone summary
- design rationale
- technical notes

Journals compress activity into reflective knowledge.

---

## 13. Memory Candidate Creation

From journals or summaries the system may generate memory candidates.

```
MemoryCandidate
```

These represent proposed durable knowledge.

Examples:

- user preferences
- project conventions
- architecture decisions

Candidates require review before becoming durable memory.

---

## 14. Memory Review

The user reviews candidates and may:

- approve
- reject
- archive
- defer

Approved entries become:

```
MemoryEntry
```

These can influence future persona activations.

---

# Design Principles

The meeting execution model follows several principles.

### Durable First

Messages must be persisted before orchestration begins.

### Explainability

Every persona response must trace to:

- activation
- directive
- memory sources

### Graceful Failure

One persona failure should not invalidate the meeting.

### Structured Learning

Learning progresses through:

conversation → journal → memory candidate → approved memory

### Human Authority

The user remains the final authority over durable memory.

---

# Relationship to Other Architecture Documents

This document ties together several RFCs.

- Persona Activation Model
- Conversation and Memory Data Model
- Workspace and Persona Instance Model
- Teams, Squads, and Meeting Coordinator Model
- Memory Journaling and Gardening Model

Together these documents define the Orbit collaboration system.

---

# Summary

Meeting execution transforms a user message into a structured collaboration between AI personas.

The system:

- persists conversation state
- coordinates participants
- activates personas
- executes agent runs
- streams responses to clients
- summarizes outcomes
- produces journals
- proposes memory

This flow enables Orbit to function as a persistent AI team environment rather than a simple chat interface.

---