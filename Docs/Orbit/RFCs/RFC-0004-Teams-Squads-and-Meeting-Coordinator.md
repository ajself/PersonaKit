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
- RFC-0001: Workspace Persona Contract Resolution and Activation Model
- RFC-0002: Collaboration Runtime and Memory Data Model
- RFC-0003: Workspace, Group, and Workspace Persona Instance Model
- RFC-0005: Memory Journaling and Gardening Model
- RFC-0006: Orbit Multi-Client Platform Architecture
- Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md
- Docs/Orbit/RFCs/README.md

---

## 1. Summary

This RFC defines Orbit's model for teams, squads, and the Meeting Coordinator.

Orbit should let a user address groups naturally instead of manually naming every
collaborator for every interaction. To do that safely, Orbit needs explicit
rules for:

- group targeting
- target expansion
- participant selection rationale
- participation roles
- response ordering
- completion semantics
- failure handling
- visible coordination state

This RFC treats the Meeting Coordinator as the broad orchestration service for
group interaction. It is not limited to formal meeting posts. It also governs
inline group replies in the current post thread, lightweight meeting mode,
promotion to a meeting post, and follow-up handoff to a linked workstream post.

Persistent teams, squads, and workspace persona instances are owned semantically
by RFC-0003. Runtime entity structure is owned by RFC-0002. Activation and
contract semantics are owned by RFC-0001.

Terminology note:

- `user` initiates interactions in Orbit
- `operator` governs review, approval, and override authority
- in v1, the same person often plays both roles, but the distinction remains
  useful in the model

---

## 2. Motivation

Orbit is a collaboration platform for operator-led AI teams. It is no longer
just a place to ground one collaborator and ask one question.

Users should be able to say things like:

- "Ask the Product Team what they think."
- "Bring in the Onboarding Squad."
- "I want the Product Designer, QA Lead, and Architecture Reviewer."

Without a clear model for group interaction, Orbit risks:

- ad hoc roster selection everywhere
- inconsistent group behavior
- unclear inclusion reasoning
- fragile orchestration logic
- user confusion about who is speaking and why

Without a clearly defined Meeting Coordinator, Orbit risks becoming a loose
collection of collaborator calls instead of a coherent collaboration system.

This RFC exists to define the orchestration structure that makes group
interaction deterministic, explainable, and operator-visible.

---

## 3. Problem Statement

Orbit needs a deterministic, explainable model for group interaction.

The system must answer:

- how is a team target expanded?
- how is a squad target expanded?
- how does an ad hoc roster differ from a persistent group?
- when does group interaction remain inline in a post thread?
- when does it enter lightweight meeting mode or promote to a meeting post?
- when should a linked workstream post be proposed or created?
- how are participant inclusion and exclusion decisions recorded?
- how are participant roles assigned?
- how are partial participation, disagreement, or failure handled?

Without explicit rules, group behavior becomes arbitrary.

That would undermine Orbit's core principles:

- explicit over inferred
- structure over autonomy
- operator control over hidden magic

---

## 4. Goals

This RFC aims to establish a model that:

- supports durable teams and focused squads inside workspaces
- supports direct, team, squad, and ad hoc targeting modes
- allows users to address groups naturally
- provides deterministic expansion from group target to workspace persona
  instances
- records participant selection reasoning
- separates targeting mode from response form
- supports inline group replies, lightweight meeting mode, promoted meeting
  posts, and linked workstream handoff
- supports explicit participation roles
- supports partial participation and visible failure states
- preserves operator authority over meeting scope, membership, and follow-up
- scales from small collaborative exchanges to operator-scale multi-workspace
  collaboration

---

## 5. Non-Goals

This RFC does not define:

- persistent team or squad entity structure in full detail
- the post/thread/message runtime entity model
- activation precedence or contract-resolution rules
- memory retrieval policy or ranking
- the final visual design for meetings or group views
- the final schema for all coordinator event payloads
- workstream execution semantics

Those concerns belong primarily to RFC-0001, RFC-0002, RFC-0003, RFC-0005, and
later implementation docs.

---

## 6. Proposal

Orbit should model group collaboration around three concepts:

1. Teams - durable organizational groups
2. Squads - focused initiative groups
3. Meeting Coordinator - the orchestration service for group interaction

### Core proposal

- teams and squads are persistent workspace structures defined by RFC-0003
- users may address one collaborator, a team, a squad, or an ad hoc roster
- the Meeting Coordinator expands that target into concrete workspace persona
  instances
- the Coordinator records why participants were included or excluded
- the Coordinator assigns participation roles and chooses a response form
- group interaction starts inline in the current post thread by default
- the Coordinator may keep interaction inline, enter lightweight meeting mode,
  promote to a meeting post, or propose or trigger a linked workstream post
- the Coordinator tracks state, completion, visible failures, and follow-up
  triggers

---

## 7. Ownership Boundary

RFC-0004 owns:

- group target expansion
- participant selection rationale
- participation-role semantics
- sequencing and completion policies
- visible coordination state
- group-orchestration failure handling
- coordinator-driven workstream handoff proposal or trigger behavior

RFC-0004 does not own:

- persistent team and squad structure semantics in detail (`RFC-0003`)
- activation and contract-resolution semantics (`RFC-0001`)
- post/thread/message runtime entity structure (`RFC-0002`)
- memory lifecycle and promotion logic (`RFC-0005`)
- workstream execution itself (`RFC-0002` and later implementation)

---

## 8. Definitions

### Team

A durable organizational grouping of workspace persona instances.

Teams are persistent coordination targets defined semantically by RFC-0003.

### Squad

A focused working group around a specific objective or initiative.

Squads are also persistent coordination targets defined semantically by RFC-0003,
but they are typically more focused, initiative-bound, and cross-functional than
teams.

### Meeting

A structured collaborative interaction involving multiple participants under
coordinator control.

Meetings may remain lightweight inside the current post thread or be promoted to
a dedicated meeting post.

### Meeting Coordinator

The orchestration service responsible for turning a group target into a visible,
explainable collaboration flow.

The Meeting Coordinator is broader than formal meeting-post orchestration. It is
responsible for group interaction in general.

---

## 9. Targeting Modes

Orbit should support four targeting modes.

### 9.1 Direct mode

The user addresses one collaborator or one workspace persona instance.

Example:

> Ask the Product Designer for Bar what they think.

### 9.2 Team mode

The user addresses a durable team.

Example:

> Ask the Bar Product Team what they think.

### 9.3 Squad mode

The user addresses a focused working group.

Example:

> Bring in the Onboarding Squad.

### 9.4 Ad hoc mode

The user or coordinator defines a custom roster for one interaction.

Example:

> I want the Product Designer, QA Lead, and Architecture Reviewer.

Ad hoc rosters are runtime targeting constructs, not persistent groups by
default.

---

## 10. Coordinator Outcomes

Targeting mode and response form are different decisions.

By default, group targeting begins inline in the current post thread. The
Meeting Coordinator may then choose one of several outcomes.

### 10.1 Inline group reply

The interaction remains in the current post thread.

Use when:

- the scope is small
- no formal meeting state is needed
- a lightweight multi-participant exchange is sufficient

### 10.2 Lightweight meeting mode

The interaction stays in the current post thread, but the Coordinator applies
explicit meeting semantics such as participant roles, sequencing, and completion
tracking.

Use when:

- structured coordination is needed
- a dedicated meeting post would be excessive

In v1, lightweight meeting mode may be represented through post-thread
coordination state, participant metadata, and post events rather than a separate
root entity.

### 10.3 Promoted meeting post

The Coordinator promotes the group interaction into a linked meeting post.

Use when:

- the interaction needs durable independent identity
- a dedicated participant list, summary, or lifecycle is needed
- follow-up coordination should remain clearly separable from the origin post

### 10.4 Linked workstream post handoff

The Coordinator may propose or trigger a linked workstream post as a follow-up
outcome.

Use when:

- the discussion has reached a concrete execution step
- the next action belongs in a workstream rather than continued group debate

Important rule:

- the Meeting Coordinator may propose or trigger linked workstream posts
- it does not own workstream execution itself

---

## 11. Meeting Coordinator Responsibilities

The Meeting Coordinator should be explicitly responsible for:

- workspace and target resolution for group interaction
- team and squad expansion into concrete workspace persona instances
- participant selection and exclusion reasoning
- participation-role assignment
- choice of response form
- activation creation requests through RFC-0001 semantics
- sequencing and ordering policy
- state tracking and visible status updates
- completion determination
- trigger points for summaries, journals, and memory candidates where policy
  allows
- follow-up handoff into linked workstream posts when appropriate

### Important distinction

The Meeting Coordinator is not the same as the responding collaborators.

It is an orchestration layer, even if later Orbit gives it an optional visible
facilitation presence.

---

## 12. Participant Selection Model

When a post or post-thread action addresses a team or squad, the Meeting
Coordinator should:

1. resolve the workspace
2. load the target group membership
3. expand members into workspace persona instances
4. optionally filter or re-rank members based on selection policy
5. assign participation roles
6. record inclusion and exclusion reasons
7. persist or emit visible coordination metadata

For each selected workspace persona instance, Orbit later resolves a separate
`persona_activation` under RFC-0001.

### Inclusion reasons may include

- explicit user target
- team membership
- squad membership
- required expertise
- review requirement
- facilitator role
- summarizer role
- operator override

### Exclusion reasons may include

- duplicate role coverage
- irrelevant expertise for the current request
- explicit narrowing by operator instruction
- policy-based minimal viable roster selection

### Design law

> No participant should appear without an explainable reason.

Selection rationale should remain inspectable whether the interaction stays
inline in the post thread or is promoted into a meeting post. For promoted
meetings, `meeting_member.selected_reason` is especially important. For inline
group interaction, the rationale should remain visible through post events or
equivalent participant-layer metadata.

---

## 13. Participation Roles

Group interactions should support distinct participation roles.

Suggested roles:

- facilitator
- contributor
- observer
- summarizer
- reviewer

### Why this matters

Not every participant in a room should speak equally.

Examples:

- a reviewer may respond only after others
- an observer may receive context but not produce a visible reply
- a summarizer may focus on synthesis rather than point-by-point debate
- a facilitator may guide the interaction without owning the underlying contract

This makes collaboration behavior legible and flexible.

---

## 14. Selection Policies

The Meeting Coordinator should support explicit selection policies.

Examples:

- `full_roster` - all members participate
- `required_expertise_only` - only participants with relevant role coverage
- `minimal_viable_set` - the smallest useful group
- `review_chain` - one participant drafts, others review
- `deliberation_mode` - multiple perspectives, later synthesis

This does not require all policies to exist in v1, but the model should leave
room for them.

---

## 15. Response Ordering

The Meeting Coordinator may influence how collaborator responses are ordered.

Possible strategies:

- arrival order
- facilitator first
- specialists first
- sequential review chain
- silent parallel runs followed by synthesis

### Recommendation

For early versions:

- allow independent execution by default
- display responses as they arrive
- record ordering metadata for future analysis

Ordering choices should remain inspectable through meeting state metadata,
post events, or equivalent coordination traces.

Later versions may support richer orchestration policies.

---

## 16. Meeting Completion

A coordinated group interaction needs a clear notion of done.

Suggested completion triggers:

- all required contributors have responded
- all active runs completed or failed
- timeout threshold reached
- operator explicitly ends the interaction
- the Coordinator determines sufficient coverage has been reached

### Visible completion state

When the interaction has a dedicated meeting post, RFC-0002 meeting state should
remain visible:

- `created`
- `active`
- `summarizing`
- `completed`
- `failed`

When the interaction remains inline, completion should still be visible through
post events or equivalent coordination trace.

If the Coordinator proposes or triggers a linked workstream post, that handoff is
a follow-up outcome. It does not by itself keep the coordinated interaction open
unless policy explicitly requires it.

### Design law

> A coordinated interaction may complete successfully even if some participants
> failed, as long as that state remains visible.

---

## 17. Coordinator as Service vs Optional Visible Presence

This RFC proposes a distinction between two layers.

### 17.1 System coordinator

The deterministic orchestration layer.

Responsibilities include:

- routing
- selection
- role assignment
- state transitions
- completion
- follow-up handoff

### 17.2 Optional visible coordinator presence

An optional visible explanatory or facilitative presence that may:

- explain who was invited
- explain why
- announce status changes
- summarize disagreement
- propose follow-up or workstream handoff

Important rule:

- the orchestration system must not depend on the visible presence existing
- visible coordination, if present, should increase trust rather than add magic
- if a visible presence exists, it should act as explanatory facilitation rather
  than as a hidden second authority

---

## 18. Failure Handling

The Meeting Coordinator should explicitly handle the following cases.

### 18.1 Ambiguous workspace target

- request clarification
- do not guess

### 18.2 Missing or ambiguous team or squad target

- request clarification
- do not create participant activations blindly

### 18.3 Empty team or squad

- persist a visible configuration or routing failure event
- do not create activations

### 18.4 Partial group expansion failure

- record which participants resolved and which did not
- surface the partial result to the operator
- allow remaining participants to continue when policy allows

### 18.5 One participant fails

- record failure visibly
- continue other runs when allowed
- preserve partial meeting or group interaction state

### 18.6 All participants fail

- mark the coordinated interaction failed
- preserve the origin post, roster decision, and trace state
- allow retry

### 18.7 Late-arriving responses

- preserve attribution
- decide whether they belong in the active outcome, the final summary, or a
  post-meeting follow-up

### 18.8 Meeting promotion failure

- preserve the originating post and thread
- record the promotion failure visibly
- allow retry or fallback to inline coordination

### 18.9 Linked workstream handoff creation failure

- preserve the source group interaction
- record the failure visibly
- do not imply that execution work started successfully when it did not

### 18.10 Stop point or review gate interruption

- surface the blocked state
- preserve partial progress and rationale
- wait for operator review where required by RFC-0001

### 18.11 Overly broad roster

- coordinator may warn or recommend narrowing
- future policy may auto-trim based on expertise, but must remain explainable

---

## 19. UX / Product Implications

This RFC implies several product requirements.

### 19.1 Users should target groups naturally in posts and threads

Examples:

- "Ask the Product Team"
- "Bring in the Onboarding Squad"
- "I want a design review squad here"

### 19.2 Users should inspect roster composition

The app should show:

- who is participating
- why they were selected
- their role in the interaction
- their current status

### 19.3 Users should understand the difference between teams and squads

The product should reinforce that:

- teams are durable organizational groups
- squads are focused initiative groups

### 19.4 The coordinator should be visible enough to build trust

Even when not personified, the system should surface:

- selection rationale
- status transitions
- completion reasoning
- follow-up handoff reasoning

### 19.5 iPad is especially promising for meeting surfaces

This model suggests interfaces such as:

- roster sidebars
- meeting timelines
- per-collaborator panels
- facilitator and summary panels

---

## 20. Data Model Implications

This RFC builds on RFC-0002's collaboration runtime model and RFC-0003's
persistent structure model.

Relevant persistent-structure dependencies from RFC-0003 include:

- `team`
- `squad`
- `workspace_persona`
- `workspace_persona_membership`

Relevant runtime-collaboration records from RFC-0002 include:

- `post`
- `thread`
- `message`
- `post_participant`
- `post_event`
- `post_link`
- `meeting_state`
- `meeting_member`
- `workstream_state`
- `workstream_assignment`
- `persona_activation`
- `agent_run`

Important implications:

- teams and squads always reference workspace persona instances, not persona
  templates directly
- group interaction begins in a post thread by default, even when later promoted
  into a meeting post or handed off to a linked workstream post
- lightweight meeting mode may be implemented as coordinator behavior layered on
  `post`, `thread`, `post_participant`, and `post_event` rather than as a
  separate root entity
- promoted meetings should use meeting-state and meeting-member records rather
  than a separate outdated meeting root entity
- inline group interactions may still need visible coordination rationale through
  post events and related metadata
- linked workstream posts should preserve continuity through post links

The current runtime model already makes `meeting_member.selected_reason`
important for explainability. Future revisions may also formalize broader
selection rationale on participant-layer records for inline group interaction.

---

## 21. Alternatives Considered

### Alternative A: No teams or squads, only direct collaborators

Rejected because:

- user overhead becomes too high
- the model does not scale to multi-group collaboration
- group semantics disappear

### Alternative B: Teams only, no squads

Rejected because:

- teams are too broad for focused initiative work
- cross-functional targeting becomes awkward

### Alternative C: Squads only, no teams

Rejected because:

- durable organizational grouping disappears
- broader team identity becomes unstable

### Alternative D: Hidden coordination only

Rejected because:

- routing feels magical
- explainability weakens
- operator trust and debugging suffer

### Alternative E: Immediate meeting-post creation for every group target

Rejected because:

- some group interactions should remain lightweight and inline
- immediate promotion would add unnecessary ceremony

---

## 22. Risks And Tradeoffs

### Risk: More conceptual overhead

Teams, squads, participation roles, and coordination policies add complexity.

Tradeoff:

- the product vision requires explicit collaboration structure
- hiding that structure would create more confusion later

### Risk: Users may not understand team vs squad initially

Tradeoff:

- product copy and UI must reinforce the distinction
- the underlying model should still remain correct

### Risk: Coordinator may feel too controlling

Tradeoff:

- selection rationale and override controls are essential
- the operator must remain able to steer or override scope

### Risk: Premature policy complexity

Tradeoff:

- early implementation can support only a few selection and ordering policies
- the model should still leave room for richer behavior later

### Risk: Boundary overlap with RFC-0003 and RFC-0002

Tradeoff:

- RFC-0003 owns persistent structure semantics
- RFC-0002 owns runtime records
- RFC-0004 should stay focused on orchestration behavior

---

## 23. Open Questions

- Should the user be able to save ad hoc rosters as squads?
- Should squads be able to span multiple workspaces in the future?
- Should observers receive full activation and memory retrieval, or only meeting
  context?
- Should some team or squad invocations always promote to meeting posts?
- Should some team or squad invocations default to lightweight meeting mode even
  when they do not promote to meeting posts?
- Should some squads have a designated default facilitator?
- How much should users be able to override selection policies per interaction?
- Should selection rationale eventually be formalized on participant-layer
  records beyond `meeting_member.selected_reason`?

---

## 24. Recommendation

Adopt the team, squad, and Meeting Coordinator model as the group-collaboration
architecture for Orbit.

Specifically:

- teams should remain durable organizational groups
- squads should remain focused working groups
- group addressing should expand into workspace persona instances
- the Meeting Coordinator should remain the explicit orchestration layer
- group interaction should begin inline by default, with promotion and handoff
  available when needed
- participant selection and completion should always remain explainable
- the operator should remain able to inspect and override scope

This is the strongest orchestration model for Orbit's current collaboration
direction.

---

## 25. Rollout / Adoption Plan

### Phase 1

Introduce:

- team and squad addressing
- coordinator target expansion
- inline group coordination in post threads

Goal:

- enable basic group interaction with visible orchestration

### Phase 2

Introduce:

- participant reasoning
- participation roles
- meeting-state tracking for promoted meeting posts
- explicit completion rules

Goal:

- make group behavior legible and reliable

### Phase 3

Introduce:

- linked workstream handoff
- richer sequencing policies
- saved ad hoc roster flows if they remain valuable

Goal:

- improve follow-through and collaboration quality

### Phase 4

Introduce:

- more advanced deliberation patterns
- richer facilitator behaviors
- analytics and quality scoring

Goal:

- evolve the system from basic routing into structured collaboration

---

## 26. Self-Review

- Does this model reduce user friction for group interaction?
  Yes.

- Does it preserve explicitness and explainability?
  Yes.

- Does it align with RFC-0003's persistent group and workspace persona instance
  model?
  Yes.

- Does it align with RFC-0002's post/thread runtime model?
  Yes.

- Does it keep targeting mode separate from response form?
  Yes.

- Does it avoid turning the coordinator into hidden magic?
  Yes, provided rationale and state remain visible.

---

## 27. Decision Log

- 2026-03-08 - Initial draft created
- 2026-03-17 - Reframed RFC around Orbit as the platform and PersonaKit as the
  authored-contract engine
- 2026-03-17 - Distinguished targeting modes from coordinator outcomes and made
  inline group interaction the default starting point
- 2026-03-17 - Defined the Meeting Coordinator as a broad orchestration layer
  with optional visible facilitation presence and linked workstream handoff
- 2026-03-17 - Clarified user vs operator terminology, lightweight meeting mode
  representation, and runtime alignment with `agent_run` and post-based
  coordination records
- 2026-03-17 - Clarified user vs operator terminology, activation-per-participant
  expansion, inline rationale visibility, and workstream handoff as a follow-up
  outcome rather than implicit execution ownership
