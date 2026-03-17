# RFC-0004: Teams, Squads, and Meeting Coordinator Model

## Status
Draft

## Authors
- AJ Self
- ChatGPT / ProdDoc

## Created
2026-03-08

## Last Updated
2026-03-17

## Related
- RFC-0001 Workspace Persona Contract Resolution and Activation Model
- RFC-0002 Collaboration Runtime and Memory Data Model
- RFC-0003 Workspace and Persona Instance Model
- Docs/RFCs/README.md

---

## 1. Summary

This RFC proposes the model for **teams, squads, and the Meeting Coordinator** in PersonaKit.

PersonaKit is evolving into a workspace-centric command center for AI teams. In that system, the user should not always need to manually select individual personas. Instead, the system should support:

- durable teams
- focused squads
- coordinated meetings
- explicit participant selection
- transparent meeting orchestration

This RFC defines:

- how teams and squads are modeled
- how messages addressed to a team or squad are expanded into participants
- how the Meeting Coordinator selects, invites, sequences, and closes persona participation
- how meeting behavior remains explainable and under human authority

This RFC is a proposal, not a locked implementation.

---

## 2. Motivation

PersonaKit’s product direction is no longer just “ground one persona and ask one question.”

The product is becoming:

- a system for talking to multiple personas as a group
- a place where squads work on products, research, and decisions
- a coordination layer for incubator-style operations

Without a clear model for teams and squads, the system risks:

- ad hoc roster selection everywhere
- inconsistent meeting behavior
- unclear participant inclusion
- fragile routing logic
- user confusion about who is speaking and why

Without a clearly defined Meeting Coordinator, PersonaKit risks becoming a loose collection of persona calls instead of a coherent collaboration system.

This RFC exists to define the operational structure of group interaction.

---

## 3. Problem Statement

PersonaKit needs a deterministic, explainable model for group interaction.

The system must answer:

- How is a team defined?
- How is a squad defined?
- What is the difference between them?
- How does the system decide who participates in a meeting?
- When does a message addressed to a team become a meeting?
- Who is responsible for sequencing and completion?
- How are participant selection decisions recorded?
- How should partial participation, failure, or disagreement be handled?

Without an explicit model, group behavior becomes arbitrary.

That would undermine PersonaKit’s core principles:
- explicit over inferred
- structure over autonomy
- human control over hidden magic

---

## 4. Goals

This RFC aims to establish a model that:

- supports durable teams and focused squads inside workspaces
- allows users to address groups rather than always naming personas individually
- gives the Meeting Coordinator explicit responsibilities
- ensures participant selection is explainable
- supports direct, team, squad, and ad hoc meeting modes
- supports partial participation and visible failure states
- preserves human authority over meeting scope and membership
- scales from small collaborative exchanges to incubator-style multi-persona discussion

---

## 5. Non-Goals

This RFC does not define:

- the final chat UI for meetings
- the final notification design
- the final policy for model-to-model cross-talk
- the exact prompt structure for coordinator summaries
- the final meeting analytics dashboard
- the final schema for all event payloads

Those may follow in later RFCs.

---

## 6. Proposal

PersonaKit should model group collaboration around three concepts:

1. **Teams** — durable organizational groups
2. **Squads** — focused working groups for a specific initiative
3. **Meeting Coordinator** — the orchestration service and visible coordination logic that manages group participation

### Core proposal

- Teams and squads are first-class workspace entities.
- Messages may target:
  - one persona
  - a team
  - a squad
  - an ad hoc roster
- A Meeting Coordinator service expands the target into actual workspace persona participants.
- The Coordinator records why participants were included or excluded.
- The Coordinator manages meeting state, participation, completion, and follow-up artifacts.
- The Coordinator may have both:
  - a **system role** (deterministic orchestration)
  - and optionally a **visible persona presence** in the chat when useful

---

## 7. Definitions

### Team
A **durable organizational grouping** of workspace personas.

Examples:
- Bar Product Team
- Bar Engineering Team
- Architecture Council

Teams represent persistent collaboration structures.

### Squad
A **focused working group** formed around a problem, initiative, or workstream.

Examples:
- Onboarding Squad
- Memory System Squad
- Design Review Squad

Squads may be:
- temporary
- overlapping
- smaller than teams
- purpose-specific

### Meeting
A structured collaborative interaction in which multiple personas may participate under coordinator control.

### Meeting Coordinator
The orchestration component responsible for:
- selecting or expanding participants
- sequencing activation
- tracking state
- deciding completion
- producing meeting-level events and follow-up triggers

---

## 8. Team Model

Teams should be modeled as durable, named groups inside a workspace.

A team:
- belongs to one workspace
- contains workspace persona members
- has a purpose
- may be referenced in user-facing language

Examples:

```text
Workspace: Bar

Teams:
- Product Team
- Engineering Team
- Research Team
```

Team membership should be explicit and inspectable.

### Team use cases
- stable product discussions
- durable department-like structures
- persistent rosters for repeated conversations

### Design law
> Teams represent organizational continuity.

---

## 9. Squad Model

Squads should be modeled as focused working groups inside a workspace.

A squad:
- belongs to one workspace
- may optionally be associated with a team
- contains workspace persona members
- exists for a more specific objective

Examples:

```text
Workspace: Bar

Squads:
- Onboarding Squad
- Growth Experiments Squad
- Launch Readiness Squad
```

### Squad use cases
- cross-functional project work
- temporary or semi-persistent initiative groups
- direct addressing in chat (“ask the onboarding squad”)

### Design law
> Squads represent focused operational collaboration.

---

## 10. Team vs Squad Distinction

This distinction needs to stay crisp.

### Team
- broad
- durable
- role-based
- organizational

### Squad
- focused
- initiative-based
- often cross-functional
- may change more frequently

### Example
In a workspace:

**Product Team**
- Product Manager
- Product Designer
- Growth Analyst

**Onboarding Squad**
- Product Manager
- Product Designer
- Senior SwiftUI Engineer
- QA Lead

The squad cuts across broader team boundaries.

---

## 11. Meeting Modes

PersonaKit should support four meeting modes.

### 11.1 Direct mode
User addresses one workspace persona.

Example:
> Wear the Product Designer for Bar.

### 11.2 Team mode
User addresses a durable team.

Example:
> Ask the Bar Product Team what they think.

### 11.3 Squad mode
User addresses a focused working group.

Example:
> Bring in the Onboarding Squad.

### 11.4 Ad hoc mode
Coordinator or user defines a custom roster for a meeting.

Example:
> I want the Product Designer, QA Lead, and Architecture Reviewer.

Each mode may produce a conversation, but multi-participant modes should generally create or continue a structured meeting.

---

## 12. Meeting Coordinator Responsibilities

The Meeting Coordinator should be explicitly responsible for:

- workspace resolution
- target expansion
- participant selection
- participant role assignment
- activation creation
- response sequencing policy
- completion determination
- summary trigger decisions
- journaling trigger decisions
- memory candidate trigger decisions

### Important distinction
The Meeting Coordinator is not the same as every responding persona.

The Coordinator is an orchestration system, even if later you give it an optional visible persona voice.

---

## 13. Participant Selection Model

When a user addresses a team or squad, the Coordinator should:

1. resolve the workspace
2. load the target group
3. expand members into workspace persona instances
4. optionally filter or re-rank members based on meeting type
5. record inclusion reasons

### Inclusion reasons may include:
- explicit user target
- squad membership
- required expertise
- review requirement
- observer role
- facilitator role

### Design law
> No participant should appear without an explainable reason.

---

## 14. Participation Roles

Meeting members should support distinct participation roles.

Suggested roles:
- facilitator
- contributor
- observer
- summarizer
- reviewer

### Why this matters
Not every persona in a room should speak equally.

Examples:
- a reviewer may respond only after others
- an observer may receive context but not produce a visible reply
- a facilitator may synthesize disagreement

This makes meeting behavior legible and flexible.

---

## 15. Selection Policies

This RFC proposes that the Coordinator support explicit selection policies.

### Examples
- **full roster** — all members participate
- **required expertise only** — only personas with relevant role coverage
- **minimal viable set** — smallest useful group
- **review chain** — one persona drafts, others review
- **deliberation mode** — parallel perspectives, later synthesis

This does not require all policies to exist in V1, but the model should leave room for them.

---

## 16. Response Ordering

The Coordinator may also control how persona responses are ordered.

Possible strategies:
- arrival order
- facilitator first
- specialists first
- sequential review chain
- silent parallel runs + summary

### Recommendation
For early versions:
- allow independent execution
- display as responses arrive
- record ordering metadata for future analysis

Later versions may support richer orchestration.

---

## 17. Meeting Completion Model

A meeting needs a clear notion of “done.”

Suggested completion triggers:
- all required contributors have responded
- all active runs completed or failed
- timeout threshold reached
- user explicitly ends meeting
- coordinator declares sufficient coverage

Meeting status should remain visible:
- created
- active
- summarizing
- completed
- failed

### Design law
> A meeting may complete successfully even if some participants failed, as long as that state is visible.

---

## 18. Coordinator as Service vs Persona

This RFC proposes a distinction between:

### System Coordinator
The deterministic orchestration layer.
Responsibilities:
- routing
- selection
- state transitions
- completion

### Optional visible coordinator persona
A chat-visible persona that may:
- explain who was invited
- summarize why
- provide facilitation language
- offer synthesis

This distinction is important.

The orchestration system should not depend on the visible chat persona existing.

---

## 19. Failure Handling

The Meeting Coordinator should explicitly handle:

### 19.1 Missing or ambiguous target
- request clarification
- do not guess

### 19.2 Empty team/squad
- persist event
- surface configuration issue
- do not create activations

### 19.3 One participant fails
- record failure
- continue other runs
- preserve partial meeting

### 19.4 All participants fail
- mark meeting failed
- preserve message and roster
- allow retry

### 19.5 Late-arriving responses
- preserve attribution
- coordinator may decide whether to include in final summary or treat as post-meeting follow-up

### 19.6 Overly broad roster
- coordinator may warn or recommend narrowing
- future policy may auto-trim based on expertise, but should remain explainable

---

## 20. UX / Product Implications

This RFC implies several UX requirements.

### 20.1 Users should be able to target groups naturally
Examples:
- “Ask the Bar Product Team”
- “Bring in the Onboarding Squad”
- “I want a design review squad here”

### 20.2 Users should be able to inspect roster composition
The app should show:
- who is participating
- why they were selected
- their role in the meeting
- their status

### 20.3 Users should understand the difference between teams and squads
The UI may need explanatory affordances, especially early on.

### 20.4 The coordinator should be visible enough to build trust
Even if not always personified, the system must show:
- selection rationale
- status changes
- completion reasoning

### 20.5 iPad becomes especially important
This model strongly suggests:
- roster sidebars
- meeting timelines
- per-persona panels
- facilitator/summary panels

---

## 21. Data Model Implications

This RFC assumes the data model proposed in RFC-0002, especially:
- `team`
- `squad`
- `workspace_persona_membership`
- `meeting`
- `meeting_member`
- `conversation_participant`
- `conversation_event`
- `persona_activation`

Specifically, `meeting_member.selected_reason` becomes important because it supports coordinator explainability. fileciteturn16file2

This RFC also depends on RFC-0003’s distinction between persona templates and workspace persona instances, because teams and squads should contain **workspace personas**, not global templates. fileciteturn16file3

---

## 22. Alternatives Considered

### Alternative A: No teams or squads, only direct personas
Rejected because:
- user overhead becomes too high
- doesn’t support incubator-scale operation
- prevents group semantics

### Alternative B: Teams only, no squads
Rejected because:
- teams are too broad for focused work
- cross-functional initiative groups become awkward

### Alternative C: Squads only, no teams
Rejected because:
- no durable organizational grouping
- no stable broader team identity

### Alternative D: Implicit coordinator behavior only
Rejected because:
- makes routing feel magical
- weakens explainability
- harder to debug and trust

### Alternative E: Users always pick every participant manually
Rejected because:
- too much friction
- doesn’t scale to “startup of startups” usage

---

## 23. Risks and Tradeoffs

### Risk: More conceptual overhead
Introducing teams, squads, participation roles, and coordination policies adds complexity.

Tradeoff:
- the product vision itself requires collaboration structure
- hiding it would produce more confusion later

### Risk: Users may not understand team vs squad initially
Tradeoff:
- product copy and UI need to reinforce the distinction
- the underlying model should still be correct

### Risk: Coordinator may feel too controlling
Tradeoff:
- selection rationale and override controls are essential
- the human must remain able to steer or override

### Risk: Premature policy complexity
Tradeoff:
- early implementation can support only a few selection/ordering policies
- the model should still leave room for richer behavior later

---

## 24. Open Questions

- Should the user be able to save ad hoc rosters as squads?
- Should squads be able to span multiple workspaces in the future?
- Should observers receive memory retrieval and activation, or only meeting context?
- Should the visible coordinator persona always appear in team/squad meetings, or only when asked?
- Should some squads have a designated default facilitator?
- How much should users be able to override selection policies per meeting?

---

## 25. Recommendation

Adopt the team + squad + Meeting Coordinator model as the group collaboration architecture for PersonaKit.

Specifically:

- teams should represent durable organizational groups
- squads should represent focused working groups
- group addressing should expand into workspace persona instances
- the Meeting Coordinator should be the explicit orchestration layer
- participant selection and meeting completion should always be explainable
- the human should remain able to inspect and override scope

This is the strongest operational model for the incubator direction PersonaKit is taking.

---

## 26. Rollout / Adoption Plan

### Phase 1
Introduce:
- team
- squad
- workspace_persona_membership
- explicit meeting creation for group chat

Goal:
- enable basic group targeting

### Phase 2
Introduce:
- selected_reason
- participation roles
- visible roster state
- meeting completion rules

Goal:
- make group behavior legible and reliable

### Phase 3
Introduce:
- coordinator summary hooks
- richer sequencing policies
- saved ad hoc rosters

Goal:
- improve meeting quality and usability

### Phase 4
Introduce:
- more advanced deliberation patterns
- facilitator semantics
- meeting analytics and quality scoring

Goal:
- evolve the system from chat routing to structured collaboration

---

## 27. Self-Review

- Does this model reduce user friction for group interactions?  
  Yes.

- Does it preserve explicitness and explainability?  
  Yes.

- Does it align with the workspace/persona instance model?  
  Yes.

- Does it support future incubator-scale coordination?  
  Yes.

- Does it avoid turning the coordinator into hidden magic?  
  Yes, provided rationale and state remain visible.

---

## 28. Decision Log

- 2026-03-08 — Initial draft created
# RFC-0004: Teams, Squads, and Meeting Coordinator Model

## Status
Draft

## Authors
- AJ Self
- ChatGPT / ProdDoc

## Created
2026-03-08

## Last Updated
2026-03-08

## Related
- RFC-0001 Workspace Persona Contract Resolution and Activation Model
- RFC-0002 Collaboration Runtime and Memory Data Model
- RFC-0003 Workspace and Persona Instance Model
- Docs/RFCs/README.md

---

## 1. Summary

This RFC defines how **teams, squads, and coordinated meetings** operate within the Orbit platform.

Orbit is designed around persistent AI collaborators that work together as structured teams rather than isolated prompt responses. The system must therefore provide a clear model for:

- durable teams
- focused squads
- multi‑persona collaboration
- meeting orchestration
- explainable participant selection

Instead of manually selecting personas for every interaction, Orbit allows users to address **groups**. The Meeting Coordinator expands those groups into concrete persona activations and manages the lifecycle of the meeting.

---

## 2. Motivation

Orbit is evolving from simple persona prompting into a **workspace‑centric collaboration environment**.

Users should be able to say things like:

> “Ask the Bar Product Team what they think.”

or

> “Bring in the onboarding squad.”

Without a formal structure for teams and squads, the system risks:

- ad‑hoc persona selection
- inconsistent meeting behavior
- unclear participant reasoning
- fragile routing logic

The Meeting Coordinator provides a deterministic orchestration layer that keeps collaboration structured and explainable.

---

## 3. Problem Statement

Orbit must answer several questions deterministically:

- How are teams and squads defined?
- How does a group reference become concrete meeting participants?
- How does the system explain why a persona was invited?
- How does a meeting progress and conclude?
- How are partial responses or failures handled?

Without explicit rules, group collaboration becomes unpredictable and difficult to debug.

This RFC establishes the structure that ensures multi‑persona collaboration remains transparent and reliable.

---

## 4. Goals

This RFC aims to establish a collaboration model that:

- supports durable teams and focused squads within workspaces
- allows users to address groups naturally
- provides deterministic expansion from group → persona instances
- records participant selection reasoning
- supports structured meeting lifecycles
- allows partial participation and graceful failure handling
- preserves human authority over team composition and meeting scope
- scales from solo builders to incubator‑style multi‑team environments

---

## 5. Non‑Goals

This RFC does **not** define:

- the final user interface for meetings
- notification strategies
- exact summarization prompts
- analytics dashboards
- final schema for all coordinator event payloads

Those concerns are addressed in other RFCs or later implementation stages.

---

## 6. Proposal

Orbit organizes collaborative interaction around three concepts:

1. **Teams** — durable organizational groups
2. **Squads** — focused initiative groups
3. **Meeting Coordinator** — orchestration service for collaboration

High‑level hierarchy:

```text
User
  ↓
Workspace
  ↓
Teams / Squads
  ↓
Workspace Personas
  ↓
Persona Activations
```

Teams and squads reference **workspace personas**, not persona templates directly.

---

## 7. Definitions

### Team
A durable organizational grouping of workspace personas.

Example:

```
Workspace: Bar

Teams:
- Product Team
- Engineering Team
- Research Team
```

Teams represent stable collaboration structures.

---

### Squad
A focused working group around a specific initiative.

Example:

```
Workspace: Bar

Squads:
- Onboarding Squad
- Growth Experiments Squad
- Launch Readiness Squad
```

Squads may overlap and evolve more frequently than teams.

---

### Meeting
A structured collaborative interaction between personas triggered by a user message.

---

### Meeting Coordinator
The system component responsible for orchestrating collaboration.

Responsibilities include:

- resolving target groups
- expanding squads and teams
- selecting participants
- triggering persona activations
- tracking meeting state
- determining completion

---

## 8. Team Model

Teams are persistent workspace structures.

Characteristics:

- defined inside a workspace
- composed of workspace personas
- long‑lived
- represent organizational roles

Example:

```
Bar Product Team
- Product Manager
- Product Designer
- Growth Analyst
```

Design principle:

> Teams represent organizational continuity.

---

## 9. Squad Model

Squads represent **initiative‑specific collaboration groups**.

Characteristics:

- scoped to a specific objective
- may span multiple teams
- smaller and more focused

Example:

```
Onboarding Squad
- Product Manager
- Product Designer
- Senior SwiftUI Engineer
```

Design principle:

> Squads represent focused operational collaboration.

---

## 10. Team vs Squad Distinction

| Team | Squad |
|-----|------|
| broad scope | narrow initiative |
| durable | temporary or evolving |
| role‑based | task‑based |
| organizational structure | operational execution |

---

## 11. Meeting Modes

Orbit supports several collaboration modes.

### Direct Mode
User addresses a single persona.

Example:

> Wear the Product Designer for Bar.

### Team Mode
User addresses a durable team.

Example:

> Ask the Bar Product Team what they think.

### Squad Mode
User addresses a focused initiative group.

Example:

> Bring in the Onboarding Squad.

### Ad‑hoc Mode
User specifies a custom set of personas.

Example:

> I want the Product Designer, QA Lead, and Architecture Reviewer.

Multi‑participant modes generally create a structured meeting.

---

## 12. Participant Selection

When a team or squad is addressed, the Meeting Coordinator performs the following steps:

1. resolve the workspace
2. load the group membership
3. expand members into workspace persona instances
4. optionally filter participants
5. record the reason each participant was selected

Possible inclusion reasons:

- explicit user reference
- team membership
- squad membership
- required expertise
- review responsibility

Design principle:

> No participant should appear without an explainable reason.

---

## 13. Participation Roles

Participants may have different roles in a meeting.

Possible roles include:

- facilitator
- contributor
- observer
- reviewer
- summarizer

This allows the system to support richer collaboration patterns.

---

## 14. Response Ordering

The coordinator may influence response ordering.

Possible strategies:

- arrival order
- facilitator first
- specialist first
- review chain
- parallel responses followed by synthesis

Early versions may simply allow independent execution.

---

## 15. Meeting Completion

A meeting is considered complete when one of the following occurs:

- all required participants have responded
- all runs have completed or failed
- a timeout threshold is reached
- the user explicitly ends the meeting

Meeting states:

```
created → active → summarizing → completed
```

Design principle:

> A meeting may complete successfully even if some participants fail.

---

## 16. Coordinator as System vs Persona

The Meeting Coordinator exists in two possible forms:

### System Coordinator

A deterministic orchestration service responsible for system behavior.

### Optional Visible Persona

A chat‑visible persona that may explain decisions, summarize discussion, or facilitate collaboration.

The orchestration system must not depend on the visible persona.

---

## 17. Failure Handling

Coordinator behavior must explicitly handle failure scenarios.

Examples include:

- ambiguous persona reference
- empty team or squad
- participant execution failure
- late responses
- overly large participant sets

All failures should remain visible through events and state transitions.

---

## 18. UX Implications

This model implies several product requirements:

- users must be able to address teams and squads naturally
- roster composition should be inspectable
- participation reasoning should be visible
- meeting progress should be observable

Particularly on iPad, the system may expose richer meeting views such as:

- roster panels
- persona response columns
- timeline views

---

## 19. Data Model Implications

This RFC builds on RFC‑0002’s runtime data model.

Relevant entities include:

- `team`
- `squad`
- `workspace_persona_membership`
- `meeting`
- `meeting_member`
- `conversation_participant`
- `persona_activation`

Teams and squads always reference **workspace personas**, not persona templates.

---

## 20. Alternatives Considered

### Direct Persona Only

Rejected because manual selection does not scale.

### Teams Without Squads

Rejected because teams are too broad for initiative‑level collaboration.

### Squads Without Teams

Rejected because durable organizational structure disappears.

### Hidden Coordination

Rejected because implicit behavior reduces explainability.

---

## 21. Risks and Tradeoffs

Key risks include:

- conceptual complexity
- user confusion between teams and squads
- overly rigid coordinator behavior

Tradeoff:

Structured collaboration is necessary for Orbit’s long‑term goals.

---

## 22. Open Questions

Open questions include:

- should ad‑hoc rosters be convertible into squads?
- should squads span multiple workspaces in the future?
- should some squads have default facilitators?

---

## 23. Recommendation

Adopt the team + squad + Meeting Coordinator model as the core collaboration architecture for Orbit.

This structure supports natural group interaction while maintaining explainability and human control.

---

## 24. Rollout / Adoption Plan

Phase 1:

- introduce team and squad structures
- enable group addressing

Phase 2:

- add participant reasoning
- add meeting lifecycle tracking

Phase 3:

- introduce richer coordination policies

---

## 25. Decision Log

- 2026‑03‑08 — Initial draft created
