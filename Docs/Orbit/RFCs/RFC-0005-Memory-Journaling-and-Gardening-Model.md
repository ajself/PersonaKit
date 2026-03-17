# RFC-0005: Memory Journaling and Gardening Model

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
- RFC-0003 Workspace, Group, and Workspace Persona Instance Model
- RFC-0004 Teams, Squads, and Meeting Coordinator Model
- Docs/RFCs/README.md

---

## 1. Summary

This RFC proposes the **journaling, memory candidate, memory review, and memory gardening model** for PersonaKit.

PersonaKit is evolving into a workspace-centric system for persistent AI teams. In such a system, conversations alone are not enough. Raw message history is too noisy, too granular, and too difficult to govern as durable knowledge. PersonaKit therefore needs a structured way to transform lived activity into memory.

This RFC proposes a staged model:

```text
Conversation / Meeting
    ↓
Journal
    ↓
Memory Candidate
    ↓
Review / Gardening
    ↓
Approved Memory
    ↓
Future Retrieval
```

This model is intended to support:
- safe memory growth
- persona expertise development
- cross-workspace learning
- durable institutional knowledge
- human control over what becomes trusted memory

This RFC is directional and open to revision.

---

## 2. Motivation

PersonaKit’s long-term value depends on more than role prompting and orchestration.

The system needs to support:

- personas that improve with experience
- workspaces that accumulate local knowledge
- teams that learn patterns over time
- cross-workspace transfer without contamination
- memory that is reviewable, attributable, and reversible

Without a structured memory model, PersonaKit faces two bad outcomes:

### Outcome A: no real learning
The system remains stateless except for authored definitions and recent context.

This makes personas feel shallow and repetitive.

### Outcome B: uncontrolled accumulation
Everything becomes memory:
- every chat turn
- every summary
- every vague impression

This causes:
- noisy retrieval
- unreliable expertise
- hidden bias
- contamination between projects

PersonaKit needs a **middle path**:
- lived activity should be recorded
- but memory should be curated

This RFC defines that curation model.

---

## 3. Problem Statement

PersonaKit needs a durable and governable system for answering the following:

- What happened that is worth remembering?
- What should remain local to a workspace?
- What should remain local to a workspace persona instance?
- What should be promoted to persona-global expertise?
- What should be treated as organizational memory?
- How can memories be linked and traversed?
- How do we avoid turning raw chat into low-quality memory?
- How do users inspect and control memory growth?
- How do personas become more expert without uncontrolled drift?

Without explicit answers, the system risks:
- memory sprawl
- false confidence
- retrieval contamination
- difficult debugging
- weak trust

---

## 4. Goals

This RFC aims to establish a model that:

- treats journaling as a first-class artifact
- separates journals from memory candidates
- separates memory candidates from approved memory
- enables memory review and stewardship
- supports multiple memory scopes:
  - workspace
  - workspace persona
  - persona global
  - team
  - organization
- supports cross-workspace knowledge transfer through explicit promotion
- supports graph-like traversal through memory links
- keeps all durable memory attributable and reviewable
- preserves authored persona identity while allowing durable learning

---

## 5. Non-Goals

This RFC does not define:

- the final UI for journal browsing or memory review
- the final scheduling engine for journal cadence
- the exact prompt templates used for journal generation
- the final search or retrieval ranking implementation
- the exact automatic approval policies, if any
- the final analytics model for memory quality scoring

These may be defined in future RFCs or implementation documents.

---

## 6. Proposal

PersonaKit should model learning in four layers:

1. **Lived Activity**
2. **Journals**
3. **Memory Candidates**
4. **Approved Memory**

These layers should remain explicitly distinct.

### Core proposal

- Conversations and meetings are the source of lived activity.
- Journals are reflective summaries produced from that activity.
- Memory candidates are proposed learnings extracted from journals and other sources.
- Approved memory is durable, retrievable knowledge.
- A memory steward process or persona may curate candidates, but the human remains the authority for durable promotion.

### Core design law

> Nothing becomes trusted memory just because a model said it.

---

## 7. Architectural Model

### 7.1 Learning pipeline

```text
Conversation / Meeting
    ↓
Journal Entry
    ↓
Memory Candidate
    ↓
Memory Review
    ↓
Approved Memory Entry
    ↓
Memory Retrieval in Future Activations
```

### 7.2 Why this separation matters

Each layer answers a different question:

- **Conversation** — what happened?
- **Journal** — what mattered?
- **Candidate** — what may be worth remembering?
- **Approved Memory** — what should influence future reasoning?

This progression prevents chat history from becoming memory by accident.

---

## 8. Journaling Model

### 8.1 Definition

A journal is a **reflective artifact** derived from activity over time.

A journal is not:
- a chat message
- a meeting summary
- a memory entry

A journal is closer to:
- reflection
- synthesis
- perspective
- episodic compression

### 8.2 Why journals exist

Journals exist because raw activity is too noisy.

A good journal should help answer:
- what changed?
- what mattered?
- what was learned?
- what should be reconsidered later?
- what should not yet be generalized?

### 8.3 Journal ownership

Journals should belong primarily to:
- a workspace persona instance
- optionally a meeting
- optionally a workspace-wide reflection process

This lets different personas reflect differently on the same activity.

### 8.4 Journal types

Suggested journal types:
- daily
- weekly
- meeting reflection
- milestone summary
- design rationale
- technical notes
- retrospective
- manual reflection

### 8.5 Journal cadence

The journaling cadence should remain flexible.

Suggested trigger types:

#### Automatic triggers
- meeting completion
- conversation length threshold
- major decision detected
- project milestone reached
- repeated failure pattern detected

#### Scheduled triggers
- daily
- weekly
- end-of-sprint
- end-of-phase

#### Manual triggers
- “Write a reflection”
- “Summarize this workstream”
- “Record what we learned here”

### 8.6 Design law

> Journals are the first compression layer between lived activity and durable memory.

---

## 9. Memory Candidate Model

### 9.1 Definition

A memory candidate is a **proposed durable learning** extracted from one or more source artifacts.

Source artifacts may include:
- journals
- summaries
- meetings
- conversations
- manually entered notes
- analysis passes

### 9.2 Why candidates exist

Candidates create a buffer between:
- “this seems important”
and
- “this should affect future reasoning”

This is a governance boundary.

### 9.3 Candidate scopes

A candidate may propose one of several scopes:

- workspace
- workspace persona
- persona global
- team
- organization

### 9.4 Candidate quality questions

Every candidate should be evaluable against:
- Is this true?
- Is this useful?
- Is this durable?
- Is this local or general?
- Is this preference, fact, or interpretation?
- Should it expire?
- Could it contaminate another workspace if promoted too broadly?

### 9.5 Design law

> Candidates are not memory. They are memory proposals.

---

## 10. Memory Gardening Model

### 10.1 Definition

Memory gardening is the process of reviewing, pruning, clustering, promoting, and archiving memory candidates and memory entries.

This may be performed by:
- the user
- a stewardship workflow
- a dedicated steward persona/service

### 10.2 Rosie the Gardener

This RFC proposes the concept of a memory steward role, informally called:

> Rosie the Gardener

Rosie is not the final authority. Rosie is a steward.

Her responsibilities may include:
- reading journals
- clustering recurring themes
- identifying patterns
- reducing duplication
- proposing memory candidates
- recommending promotion or archival
- suggesting link relationships between memories

Rosie does **not** have the final say on trusted memory unless future policy defines a narrow automatic path.

### 10.3 Why the gardening metaphor works

A garden is:
- cultivated
- pruned
- seasonal
- structured
- alive

That maps better to memory than metaphors like “database sync” or “autolearn.”

### 10.4 Design law

> Memory should be cultivated, not accumulated.

---

## 11. Approved Memory Model

### 11.1 Definition

Approved memory is a durable memory entry that may be retrieved during persona activation.

It is the only class of memory that should influence future reasoning by default.

### 11.2 Scope model

Approved memory may exist at several scopes:

#### Workspace memory
Knowledge that belongs only to a workspace.

Examples:
- Bar uses staged rollout language
- Bar’s onboarding strategy avoids full-screen modals
- This project uses a specific terminology

#### Workspace persona memory
Knowledge local to a persona instance in a workspace.

Examples:
- Bar Product Designer learned AJ prefers iterative option sets
- Bar SwiftUI Engineer learned specific code review expectations in this codebase

#### Persona global memory
Cross-workspace expertise for a persona template.

Examples:
- Product Designer has learned AJ prefers option framing over single-solution pitching
- Senior SwiftUI Engineer has learned AJ consistently prefers small diffs and explicit verification

#### Team memory
Shared lessons for a group inside a workspace.

Examples:
- The Bar Product Team prefers weekly decision summaries
- The Onboarding Squad found a specific experiment pattern unhelpful

#### Organization memory
Higher-level incubator knowledge.

Examples:
- Product experiments of a certain type repeatedly fail
- Specific growth heuristics work across multiple ventures

### 11.3 Design law

> Memory scope should be as narrow as possible, and only widen when justified.

---

## 12. Global Persona Memory Profile

### 12.1 Definition

A persona template may have a **global memory profile** that stores durable cross-workspace learnings.

This is distinct from the template itself.

That means PersonaKit distinguishes between:

- **Persona Template** — authored identity
- **Persona Global Memory Profile** — curated learned expertise

### 12.2 Why this separation matters

Without separation:
- authored identity gets polluted by runtime noise
- version control becomes confusing
- persona drift becomes hard to reason about

With separation:
- identity stays authored
- growth stays attributable
- promotion stays governable

### 12.3 Promotion rule

Promotion into global persona memory should require stronger review than workspace-local memory, because the blast radius is larger.

---

## 13. Memory Links and Traversal

### 13.1 Definition

Approved memories may be connected through explicit links.

Examples of link types:
- derived_from
- reinforces
- contradicts
- supersedes
- same_pattern_as
- related_workspace
- triggered_by
- topic_link

### 13.2 Why links matter

Links allow PersonaKit to support contextual recall such as:

> “I remember a similar issue from Foo workspace around Bar time.”

This makes memory retrieval richer without requiring a separate graph database at the start.

### 13.3 Traversal model

Memory retrieval may begin from:
- current workspace
- current workspace persona
- current directive/topic
- known linked patterns

Then expand outward in a controlled way.

### 13.4 Design law

> Memory should be traversable through explicit relationships, not vague similarity alone.

---

## 14. Retrieval Order

This RFC proposes the following retrieval order for future activations:

1. workspace memory
2. workspace persona journals and recent summaries
3. workspace persona approved memory
4. persona global memory profile
5. linked cross-workspace memories
6. organization memory

This ordering prioritizes:
- local relevance
- role-local learning
- durable cross-workspace expertise
- broader organizational knowledge only when necessary

### Important note
Journals and summaries may influence candidate generation, but only approved memory should be default retrieval for reasoning unless the runtime intentionally includes reflective context for a special mode.

---

## 15. Memory Lifecycle

### 15.1 Candidate lifecycle
- candidate
- approved
- rejected
- archived
- deferred

### 15.2 Approved memory lifecycle
- active
- archived
- superseded
- expired

### 15.3 Why lifecycle states matter

Memory is not static.

Some knowledge:
- becomes obsolete
- is replaced
- turns out to be wrong
- should be retired after a project phase ends

The system must support that without losing history.

---

## 16. Review and Governance

### 16.1 Human authority

The human should remain the primary authority over:
- promotion to approved memory
- promotion to global persona memory
- conflict resolution between candidates
- archival of stale memory

### 16.2 Review actions

Suggested review actions:
- approve
- reject
- archive
- defer
- promote to wider scope
- demote to narrower scope
- link to existing memory
- mark as contradiction
- mark as superseded

### 16.3 Steward-assisted workflow

Rosie or another steward may recommend:
- merging duplicate candidates
- widening or narrowing scope
- archiving stale entries
- surfacing conflicts
- creating memory links

But these should remain visible and attributable.

---

## 17. Failure Modes and Edge Cases

### 17.1 Every conversation becomes a candidate
This creates memory spam.

Mitigation:
- journaling as intermediate compression
- thresholds and stewardship
- human review

### 17.2 No one maintains the garden
Memory degrades over time.

Mitigation:
- scheduled gardening reviews
- stale memory audits
- aging and archival policies

### 17.3 Workspace-local lesson promoted globally too early
This causes cross-workspace contamination.

Mitigation:
- require stronger evidence and review for global promotion
- preserve source lineage

### 17.4 Two memories conflict
This may happen when:
- workspaces diverge
- older memory becomes wrong
- two teams discovered incompatible truths

Mitigation:
- explicit contradiction links
- review required before broad promotion
- expiration and supersession states

### 17.5 Journals are too generic
If journal prompts are weak, they produce low-value reflections.

Mitigation:
- persona-specific journal forms later
- meeting-type-sensitive reflection prompts
- stewardship curation

### 17.6 Memory becomes hidden magic
If users can’t see why memory influenced a response, trust collapses.

Mitigation:
- trace memory sources for each run
- show scope and provenance in review tooling
- keep retrieval explainable

---

## 18. UX / Product Implications

### 18.1 Journals are product artifacts
Journals may later appear as:
- timeline entries
- weekly persona reflections
- workspace retrospectives
- meeting follow-ups

### 18.2 Memory review must be first-class
The user should be able to:
- inspect candidate memory
- approve/reject/defer
- inspect provenance
- inspect linked memory
- see scope clearly

### 18.3 Rosie may become a visible product feature
Rosie could appear as:
- a steward inbox
- a memory review assistant
- a gardener dashboard
- a weekly memory digest

### 18.4 Cross-workspace learning should feel earned
The UI should reinforce when something moved from:
- workspace-local insight
to
- persona-global expertise

That is a meaningful event.

---

## 19. Data Model Implications

This RFC assumes and extends RFC-0002’s entities, especially:
- `journal_entry`
- `memory_candidate`
- `memory_review`
- `memory_entry`
- `memory_link`
- `persona_global_memory_profile` fileciteturn17file2

It also depends on RFC-0003’s workspace persona model, because journals and workspace persona memory should attach to a workspace persona instance, not directly to the global persona template. fileciteturn17file3

It also aligns with RFC-0001’s separation between persona template, workspace persona, directive, and memory retrieval order. fileciteturn17file1

---

## 20. Alternatives Considered

### Alternative A: Treat summaries as the only memory source
Rejected because:
- summaries are useful but too coarse
- they are not persona-specific enough
- they are not a sufficient reflection layer

### Alternative B: Let every persona mutate its own memory directly
Rejected because:
- memory growth becomes opaque
- easy to accumulate noise
- weak human governance

### Alternative C: No journals, only memory candidates from chat
Rejected because:
- candidate quality will be too noisy
- episodic reflection is lost
- less opportunity for stewardship

### Alternative D: Global-only memory
Rejected because:
- contaminates unrelated workspaces
- weakens local context quality

### Alternative E: Workspace-only memory
Rejected because:
- prevents durable persona expertise across ventures
- weakens the incubator learning loop

### Alternative F: Full autonomous stewardship
Rejected for now because:
- too much trust transferred to automation
- conflicts with PersonaKit’s human-centered control model

---

## 21. Risks and Tradeoffs

### Risk: More product surface area
Journals, memory candidates, gardening, and review add visible complexity.

Tradeoff:
- PersonaKit’s differentiator is responsible memory, not just chat

### Risk: Operational burden
Memory review takes time.

Tradeoff:
- low-quality memory is worse than no memory
- stewardship tooling can reduce burden later

### Risk: Retrieval quality becomes hard to tune
Scoped and linked memory retrieval is more complex than plain history lookup.

Tradeoff:
- it produces safer, more explainable behavior

### Risk: Journals may feel artificial if poorly designed
Tradeoff:
- persona-specific reflection patterns can improve quality later

---

## 22. Open Questions

- Should some journal types be persona-specific from day one?
- Should there be automatic “staleness review” for older memory?
- Should global persona memory promotion require more than one workspace source?
- Should Rosie exist as a named persona in the product, or primarily as a system concept first?
- Should meeting summaries always seed candidate generation, or only some types?
- Should users be able to manually author memory candidates directly?

---

## 23. Recommendation

Adopt the journaling → candidate → review → approved memory model as the durable learning architecture for PersonaKit.

Specifically:

- journals should be first-class reflective artifacts
- memory candidates should be a required staging layer
- approved memory should be the only default retrievable durable memory
- global persona memory should remain separate from authored templates
- memory links should support explicit traversal and lineage
- Rosie / gardening should be treated as stewardship, not authority

This is the strongest path for letting personas become more expert without losing the product’s core values of explicitness, human control, and explainability.

---

## 24. Rollout / Adoption Plan

### Phase 1
Introduce:
- journal_entry
- memory_candidate
- memory_review
- manual review workflow

Goal:
- establish structured memory staging

### Phase 2
Introduce:
- persona/global/workspace memory scopes
- durable approved memory retrieval
- memory lineage inspection

Goal:
- support useful memory in activations

### Phase 3
Introduce:
- Rosie-style stewardship workflows
- duplicate clustering
- contradiction/supersession review
- scheduled gardening cadence

Goal:
- improve memory quality and long-term maintainability

### Phase 4
Introduce:
- richer cross-workspace promotion
- quality metrics
- memory audits
- historical expertise growth analysis

Goal:
- support incubator-scale learning and institutional memory

---

## 25. Self-Review

- Does this model preserve human authority over durable memory?  
  Yes.

- Does it create a meaningful boundary between lived activity and trusted memory?  
  Yes.

- Does it support both local and cross-workspace learning?  
  Yes.

- Does it prevent authored persona identity from being mutated by runtime noise?  
  Yes.

- Does it leave room for productizing Rosie later without requiring that on day one?  
  Yes.

---

## 26. Decision Log

- 2026-03-08 — Initial draft created
# RFC-0005: Memory Journaling and Gardening Model

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
- RFC-0001 – Workspace Persona Contract Resolution and Activation Model
- RFC-0002 – Collaboration Runtime and Memory Data Model
- RFC-0003 – Workspace, Group, and Workspace Persona Instance Model
- RFC-0004 – Teams, Squads, and Meeting Coordinator Model
- Docs/RFCs/README.md

---

## 1. Summary

This RFC defines the **journaling, memory candidate, memory review, and memory gardening model** for the Orbit platform.

Orbit is a workspace-centric system for persistent AI teams. In such a system, conversations alone are not enough. Raw message history is too noisy, too granular, and too difficult to govern as durable knowledge. Orbit therefore needs a structured way to transform lived activity into memory.

This RFC proposes a staged model:

```text
Conversation / Meeting
    ↓
Journal
    ↓
Memory Candidate
    ↓
Review / Gardening
    ↓
Approved Memory
    ↓
Future Retrieval
```

This model is intended to support:

- safe memory growth
- persona expertise development
- cross-workspace learning
- durable institutional knowledge
- human control over what becomes trusted memory

This RFC is directional and open to revision.

---

## 2. Motivation

Orbit’s long-term value depends on more than role prompting and orchestration.

The system needs to support:

- personas that improve with experience
- workspaces that accumulate local knowledge
- teams that learn patterns over time
- cross-workspace transfer without contamination
- memory that is reviewable, attributable, and reversible

Without a structured memory model, Orbit faces two bad outcomes.

### Outcome A: No real learning

The system remains stateless except for authored definitions and recent context.

This makes personas feel shallow and repetitive.

### Outcome B: Uncontrolled accumulation

Everything becomes memory:

- every chat turn
- every summary
- every vague impression

This causes:

- noisy retrieval
- unreliable expertise
- hidden bias
- contamination between projects

Orbit needs a middle path:

- lived activity should be recorded
- durable memory should be curated

This RFC defines that curation model.

---

## 3. Problem Statement

Orbit needs a durable and governable system for answering the following:

- What happened that is worth remembering?
- What should remain local to a workspace?
- What should remain local to a workspace persona instance?
- What should be promoted to persona-global expertise?
- What should be treated as organizational memory?
- How can memories be linked and traversed?
- How do we avoid turning raw chat into low-quality memory?
- How do users inspect and control memory growth?
- How do personas become more expert without uncontrolled drift?

Without explicit answers, the system risks:

- memory sprawl
- false confidence
- retrieval contamination
- difficult debugging
- weak trust

---

## 4. Goals

This RFC aims to establish a model that:

- treats journaling as a first-class artifact
- separates journals from memory candidates
- separates memory candidates from approved memory
- enables memory review and stewardship
- supports multiple memory scopes:
  - workspace
  - workspace persona
  - persona global
  - team
  - organization
- supports cross-workspace knowledge transfer through explicit promotion
- supports graph-like traversal through memory links
- keeps all durable memory attributable and reviewable
- preserves authored persona identity while allowing durable learning
- keeps the human as the final authority over trusted memory

---

## 5. Non-Goals

This RFC does not define:

- the final UI for journal browsing or memory review
- the final scheduling engine for journal cadence
- the exact prompt templates used for journal generation
- the final search or retrieval ranking implementation
- the exact automatic approval policies, if any
- the final analytics model for memory quality scoring

These may be defined in future RFCs or implementation documents.

---

## 6. Proposal

Orbit should model learning in four layers:

1. **Lived Activity**
2. **Journals**
3. **Memory Candidates**
4. **Approved Memory**

These layers should remain explicitly distinct.

### Core proposal

- Conversations and meetings are the source of lived activity.
- Journals are reflective summaries produced from that activity.
- Memory candidates are proposed learnings extracted from journals and other sources.
- Approved memory is durable, retrievable knowledge.
- A memory steward process or persona may curate candidates, but the human remains the authority for durable promotion.

### Core design law

> Nothing becomes trusted memory just because a model said it.

---

## 7. Architectural Model

### 7.1 Learning pipeline

```text
Conversation / Meeting
    ↓
Journal Entry
    ↓
Memory Candidate
    ↓
Memory Review
    ↓
Approved Memory Entry
    ↓
Memory Retrieval in Future Activations
```

### 7.2 Why this separation matters

Each layer answers a different question:

- **Conversation** — what happened?
- **Journal** — what mattered?
- **Candidate** — what may be worth remembering?
- **Approved Memory** — what should influence future reasoning?

This progression prevents chat history from becoming memory by accident.

---

## 8. Journaling Model

### 8.1 Definition

A journal is a reflective artifact derived from activity over time.

A journal is not:

- a chat message
- a meeting summary
- a memory entry

A journal is closer to:

- reflection
- synthesis
- perspective
- episodic compression

### 8.2 Why journals exist

Journals exist because raw activity is too noisy.

A good journal should help answer:

- what changed?
- what mattered?
- what was learned?
- what should be reconsidered later?
- what should not yet be generalized?

### 8.3 Journal ownership

Journals should belong primarily to:

- a workspace persona instance
- optionally a meeting
- optionally a workspace-wide reflection process

This allows different personas to reflect differently on the same activity.

### 8.4 Journal types

Suggested journal types:

- daily
- weekly
- meeting reflection
- milestone summary
- design rationale
- technical notes
- retrospective
- manual reflection

### 8.5 Journal cadence

The journaling cadence should remain flexible.

Suggested trigger types:

#### Automatic triggers
- meeting completion
- conversation length threshold
- major decision detected
- project milestone reached
- repeated failure pattern detected

#### Scheduled triggers
- daily
- weekly
- end-of-sprint
- end-of-phase

#### Manual triggers
- “Write a reflection”
- “Summarize this workstream”
- “Record what we learned here”

### 8.6 Design law

> Journals are the first compression layer between lived activity and durable memory.

---

## 9. Memory Candidate Model

### 9.1 Definition

A memory candidate is a proposed durable learning extracted from one or more source artifacts.

Source artifacts may include:

- journals
- summaries
- meetings
- conversations
- manually entered notes
- analysis passes

### 9.2 Why candidates exist

Candidates create a buffer between:

- “this seems important”
and
- “this should affect future reasoning”

This is a governance boundary.

### 9.3 Candidate scopes

A candidate may propose one of several scopes:

- workspace
- workspace persona
- persona global
- team
- organization

### 9.4 Candidate quality questions

Every candidate should be evaluable against:

- Is this true?
- Is this useful?
- Is this durable?
- Is this local or general?
- Is this preference, fact, or interpretation?
- Should it expire?
- Could it contaminate another workspace if promoted too broadly?

### 9.5 Design law

> Candidates are not memory. They are memory proposals.

---

## 10. Memory Gardening Model

### 10.1 Definition

Memory gardening is the process of reviewing, pruning, clustering, promoting, and archiving memory candidates and memory entries.

This may be performed by:

- the user
- a stewardship workflow
- a dedicated steward persona or service

### 10.2 Rosie the Gardener

This RFC proposes the concept of a memory steward role, informally called:

> Rosie the Gardener

Rosie is not the final authority. Rosie is a steward.

Responsibilities may include:

- reading journals
- clustering recurring themes
- identifying patterns
- reducing duplication
- proposing memory candidates
- recommending promotion or archival
- suggesting link relationships between memories
- surfacing contradictions or staleness

Rosie does **not** have the final say on trusted memory unless a future RFC defines a narrow automatic path.

### 10.3 Why the gardening metaphor works

A garden is:

- cultivated
- pruned
- seasonal
- structured
- alive

That maps better to memory than metaphors like “database sync” or “autolearn.”

### 10.4 Design law

> Memory should be cultivated, not accumulated.

---

## 11. Approved Memory Model

### 11.1 Definition

Approved memory is a durable memory entry that may be retrieved during persona activation.

It is the only class of memory that should influence future reasoning by default.

### 11.2 Scope model

Approved memory may exist at several scopes.

#### Workspace memory
Knowledge that belongs only to a workspace.

Examples:
- Bar uses staged rollout language
- Bar’s onboarding strategy avoids full-screen modals
- This project uses a specific terminology

#### Workspace persona memory
Knowledge local to a persona instance in a workspace.

Examples:
- Bar Product Designer learned AJ prefers iterative option sets
- Bar SwiftUI Engineer learned specific code review expectations in this codebase

#### Persona global memory
Cross-workspace expertise for a persona template.

Examples:
- Product Designer has learned AJ prefers option framing over single-solution pitching
- Senior SwiftUI Engineer has learned AJ consistently prefers small diffs and explicit verification

#### Team memory
Shared lessons for a group inside a workspace.

Examples:
- The Bar Product Team prefers weekly decision summaries
- The Onboarding Squad found a specific experiment pattern unhelpful

#### Organization memory
Higher-level incubator knowledge.

Examples:
- Product experiments of a certain type repeatedly fail
- Specific growth heuristics work across multiple ventures

### 11.3 Design law

> Memory scope should be as narrow as possible, and only widen when justified.

---

## 12. Global Persona Memory Profile

### 12.1 Definition

A persona template may have a global memory profile that stores durable cross-workspace learnings.

This is distinct from the template itself.

That means Orbit distinguishes between:

- **Persona Template** — authored identity
- **Persona Global Memory Profile** — curated learned expertise

### 12.2 Why this separation matters

Without separation:

- authored identity gets polluted by runtime noise
- version control becomes confusing
- persona drift becomes hard to reason about

With separation:

- identity stays authored
- growth stays attributable
- promotion stays governable

### 12.3 Promotion rule

Promotion into global persona memory should require stronger review than workspace-local memory, because the blast radius is larger.

---

## 13. Memory Links and Traversal

### 13.1 Definition

Approved memories may be connected through explicit links.

Examples of link types:

- `derived_from`
- `reinforces`
- `contradicts`
- `supersedes`
- `same_pattern_as`
- `related_workspace`
- `triggered_by`
- `topic_link`

### 13.2 Why links matter

Links allow Orbit to support contextual recall such as:

> “I remember a similar issue from Foo workspace around Bar time.”

This makes memory retrieval richer without requiring a separate graph database at the start.

### 13.3 Traversal model

Memory retrieval may begin from:

- current workspace
- current workspace persona
- current directive or topic
- known linked patterns

Then expand outward in a controlled way.

### 13.4 Design law

> Memory should be traversable through explicit relationships, not vague similarity alone.

---

## 14. Retrieval Order

This RFC proposes the following retrieval order for future activations:

1. workspace memory
2. workspace persona journals and recent summaries
3. workspace persona approved memory
4. persona global memory profile
5. linked cross-workspace memories
6. organization memory

This ordering prioritizes:

- local relevance
- role-local learning
- durable cross-workspace expertise
- broader organizational knowledge only when necessary

### Important note

Journals and summaries may influence candidate generation, but only approved memory should be default retrieval for reasoning unless the runtime intentionally includes reflective context for a special mode.

---

## 15. Memory Lifecycle

### 15.1 Candidate lifecycle
- candidate
- approved
- rejected
- archived
- deferred

### 15.2 Approved memory lifecycle
- active
- archived
- superseded
- expired

### 15.3 Why lifecycle states matter

Memory is not static.

Some knowledge:

- becomes obsolete
- is replaced
- turns out to be wrong
- should be retired after a project phase ends

The system must support that without losing history.

---

## 16. Review and Governance

### 16.1 Human authority

The human should remain the primary authority over:

- promotion to approved memory
- promotion to global persona memory
- conflict resolution between candidates
- archival of stale memory

### 16.2 Review actions

Suggested review actions:

- approve
- reject
- archive
- defer
- promote to wider scope
- demote to narrower scope
- link to existing memory
- mark as contradiction
- mark as superseded

### 16.3 Steward-assisted workflow

Rosie or another steward may recommend:

- merging duplicate candidates
- widening or narrowing scope
- archiving stale entries
- surfacing conflicts
- creating memory links

But these should remain visible and attributable.

---

## 17. Failure Modes and Edge Cases

### 17.1 Every conversation becomes a candidate
This creates memory spam.

Mitigation:
- journaling as intermediate compression
- thresholds and stewardship
- human review

### 17.2 No one maintains the garden
Memory degrades over time.

Mitigation:
- scheduled gardening reviews
- stale memory audits
- aging and archival policies

### 17.3 Workspace-local lesson promoted globally too early
This causes cross-workspace contamination.

Mitigation:
- require stronger evidence and review for global promotion
- preserve source lineage

### 17.4 Two memories conflict
This may happen when:
- workspaces diverge
- older memory becomes wrong
- two teams discovered incompatible truths

Mitigation:
- explicit contradiction links
- review required before broad promotion
- expiration and supersession states

### 17.5 Journals are too generic
If journal prompts are weak, they produce low-value reflections.

Mitigation:
- persona-specific journal forms later
- meeting-type-sensitive reflection prompts
- stewardship curation

### 17.6 Memory becomes hidden magic
If users can’t see why memory influenced a response, trust collapses.

Mitigation:
- trace memory sources for each run
- show scope and provenance in review tooling
- keep retrieval explainable

---

## 18. UX / Product Implications

### 18.1 Journals are product artifacts
Journals may later appear as:
- timeline entries
- weekly persona reflections
- workspace retrospectives
- meeting follow-ups

### 18.2 Memory review must be first-class
The user should be able to:
- inspect candidate memory
- approve, reject, or defer
- inspect provenance
- inspect linked memory
- see scope clearly

### 18.3 Rosie may become a visible product feature
Rosie could appear as:
- a steward inbox
- a memory review assistant
- a gardener dashboard
- a weekly memory digest

### 18.4 Cross-workspace learning should feel earned
The UI should reinforce when something moved from:
- workspace-local insight
- persona-global expertise

That is a meaningful event.

---

## 19. Data Model Implications

This RFC assumes and extends RFC-0002’s entities, especially:

- `journal_entry`
- `memory_candidate`
- `memory_review`
- `memory_entry`
- `memory_link`
- `persona_global_memory_profile`

It also depends on RFC-0003’s workspace persona model, because journals and workspace persona memory should attach to a workspace persona instance, not directly to the global persona template.

It also aligns with RFC-0001’s separation between persona template, workspace persona, directive, and memory retrieval order.

---

## 20. Alternatives Considered

### Alternative A: Treat summaries as the only memory source
Rejected because:
- summaries are useful but too coarse
- they are not persona-specific enough
- they are not a sufficient reflection layer

### Alternative B: Let every persona mutate its own memory directly
Rejected because:
- memory growth becomes opaque
- easy to accumulate noise
- weak human governance

### Alternative C: No journals, only memory candidates from chat
Rejected because:
- candidate quality will be too noisy
- episodic reflection is lost
- less opportunity for stewardship

### Alternative D: Global-only memory
Rejected because:
- contaminates unrelated workspaces
- weakens local context quality

### Alternative E: Workspace-only memory
Rejected because:
- prevents durable persona expertise across ventures
- weakens the incubator learning loop

### Alternative F: Full autonomous stewardship
Rejected for now because:
- too much trust is transferred to automation
- it conflicts with Orbit’s human-centered control model

---

## 21. Risks and Tradeoffs

### Risk: More product surface area
Journals, memory candidates, gardening, and review add visible complexity.

Tradeoff:
- Orbit’s differentiator is responsible memory, not just chat

### Risk: Operational burden
Memory review takes time.

Tradeoff:
- low-quality memory is worse than no memory
- stewardship tooling can reduce burden later

### Risk: Retrieval quality becomes hard to tune
Scoped and linked memory retrieval is more complex than plain history lookup.

Tradeoff:
- it produces safer, more explainable behavior

### Risk: Journals may feel artificial if poorly designed
Tradeoff:
- persona-specific reflection patterns can improve quality later

---

## 22. Open Questions

- Should some journal types be persona-specific from day one?
- Should there be automatic staleness review for older memory?
- Should global persona memory promotion require more than one workspace source?
- Should Rosie exist as a named persona in the product, or primarily as a system concept first?
- Should meeting summaries always seed candidate generation, or only some types?
- Should users be able to manually author memory candidates directly?

---

## 23. Recommendation

Adopt the journaling → candidate → review → approved memory model as the durable learning architecture for Orbit.

Specifically:

- journals should be first-class reflective artifacts
- memory candidates should be a required staging layer
- approved memory should be the only default retrievable durable memory
- global persona memory should remain separate from authored templates
- memory links should support explicit traversal and lineage
- Rosie and gardening should be treated as stewardship, not authority

This is the strongest path for letting personas become more expert without losing Orbit’s core values of explicitness, human control, and explainability.

---

## 24. Rollout / Adoption Plan

### Phase 1
Introduce:
- `journal_entry`
- `memory_candidate`
- `memory_review`
- manual review workflow

Goal:
- establish structured memory staging

### Phase 2
Introduce:
- persona/global/workspace memory scopes
- durable approved memory retrieval
- memory lineage inspection

Goal:
- support useful memory in activations

### Phase 3
Introduce:
- Rosie-style stewardship workflows
- duplicate clustering
- contradiction and supersession review
- scheduled gardening cadence

Goal:
- improve memory quality and long-term maintainability

### Phase 4
Introduce:
- richer cross-workspace promotion
- quality metrics
- memory audits
- historical expertise growth analysis

Goal:
- support incubator-scale learning and institutional memory

---

## 25. Self-Review

- Does this model preserve human authority over durable memory?  
  Yes.

- Does it create a meaningful boundary between lived activity and trusted memory?  
  Yes.

- Does it support both local and cross-workspace learning?  
  Yes.

- Does it prevent authored persona identity from being mutated by runtime noise?  
  Yes.

- Does it leave room for productizing Rosie later without requiring that on day one?  
  Yes.

---

## 26. Decision Log

- 2026-03-08 — Initial draft created
- 2026-03-08 — Revised for Orbit platform terminology and governance clarity
