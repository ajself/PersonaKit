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
- RFC-0001: Workspace Persona Contract Resolution and Activation Model
- RFC-0002: Collaboration Runtime and Memory Data Model
- RFC-0003: Workspace, Group, and Workspace Persona Instance Model
- RFC-0004: Teams, Squads, and Meeting Coordinator Model
- RFC-0006: Multi-Client Platform Architecture
- Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md
- Docs/Orbit/RFCs/README.md

---

## 1. Summary

This RFC defines Orbit's model for journaling, memory candidates, memory review,
memory gardening, and approved memory.

Orbit is the collaboration platform. PersonaKit is the authored-contract engine.
Raw runtime activity alone is too noisy and too weakly governed to become
trusted memory by default. Orbit therefore needs an explicit learning pipeline
that turns lived activity into durable memory through reviewable stages.

This RFC defines that staged model:

```text
Post / Thread Activity
    -> Journal
    -> Memory Candidate
    -> Review / Gardening
    -> Approved Memory
    -> Future Activation Eligibility
```

The model is intended to support:

- safe memory growth
- workspace-local learning
- workspace persona instance expertise development
- cross-workspace promotion without contamination
- durable institutional knowledge
- operator control over what becomes trusted memory

Terminology note:

- `user` initiates interactions in Orbit
- `operator` governs review, approval, and override authority
- in v1, the same person often plays both roles, but the distinction remains
  useful in the model

---

## 2. Motivation

Orbit's long-term value depends on more than role prompting and orchestration.

The platform needs to support:

- workspace persona instances that improve with experience
- workspaces that accumulate local knowledge
- reviewed cross-workspace transfer without contamination
- memory that is attributable, inspectable, and reversible

Without a structured memory model, Orbit faces two bad outcomes.

### Outcome A: No real learning

The system remains shallow and repetitive because it only has authored
definitions and short-lived context.

### Outcome B: Uncontrolled accumulation

Everything starts acting like memory:

- every post
- every thread
- every message
- every vague summary
- every impression from a run

That creates:

- noisy retrieval
- unreliable expertise
- hidden bias
- contamination between workspaces
- weak operator trust

Orbit needs a middle path:

- lived activity should be preserved
- durable memory should be curated

This RFC defines that curation model.

---

## 3. Problem Statement

Orbit needs a durable and governable system for answering the following:

- What happened that is worth remembering?
- What should remain local to a workspace?
- What should remain local to a workspace persona instance?
- What should be promoted to persona-global expertise?
- What should become organization-level memory?
- How can memories be linked and traversed?
- How do we avoid turning raw runtime activity into low-quality memory?
- How do operators inspect and control memory growth?
- How do collaborators become more expert without uncontrolled drift?

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
- enables explicit memory review and stewardship
- supports memory scopes for:
  - workspace
  - workspace persona
  - persona global
  - organization
- supports cross-workspace knowledge transfer through explicit promotion
- supports explicit memory linkage and traversal
- keeps durable memory attributable and reviewable
- preserves authored persona identity while allowing durable learning
- keeps operator authority over trusted memory

In this RFC, `workspace persona` is shorthand for memory attached to a
workspace persona instance.

---

## 5. Non-Goals

This RFC does not define:

- the final UI for journal browsing or memory review
- the final scheduling engine for journal cadence
- the exact prompt templates used for journal generation
- the exact runtime record schema for journals or memory
- the exact activation retrieval order
- the final search or ranking implementation
- the final analytics model for memory quality scoring
- the final automatic approval policies, if any

Those concerns belong primarily to RFC-0001, RFC-0002, RFC-0003, and later
implementation docs.

---

## 6. Proposal

Orbit should model durable learning in four explicit layers:

1. Lived activity
2. Journals
3. Memory candidates
4. Approved memory

These layers must remain distinct.

### Core proposal

- post, thread, meeting post, workstream post, note, decision, and run activity
  are sources of lived activity
- journals are reflective artifacts produced from that activity
- memory candidates are proposals extracted from journals and other explicit
  structured artifacts
- approved memory is durable, retrievable knowledge
- a memory gardener or steward process may help curate memory, but the operator
  remains the authority for trusted promotion

### Core design law

> Nothing becomes trusted memory just because a model said it.

---

## 7. Ownership Boundary

RFC-0005 owns:

- journaling semantics
- memory-candidate semantics
- review and gardening semantics
- approved memory semantics
- promotion and scope-widening semantics
- stewardship concepts and governance rules
- memory-quality and contamination edge cases

RFC-0005 does not own:

- exact runtime record shapes (`RFC-0002`)
- activation retrieval order and activation-time eligibility decisions in full
  detail (`RFC-0001`)
- workspace, group, and structural memory-ownership semantics (`RFC-0003`)
- contract-resolution rules (`RFC-0001`)

---

## 8. Learning Pipeline

### 8.1 Pipeline

```text
Post / Thread Activity
  -> Journal Entry
  -> Memory Candidate
  -> Memory Review / Gardening
  -> Approved Memory Entry
  -> Future Activation Eligibility
```

Typical sources of lived activity include:

- posts
- threads
- messages
- meeting posts
- workstream posts
- notes
- decisions
- run artifacts or execution traces when policy allows

### 8.2 Why this separation matters

Each layer answers a different question:

- lived activity - what happened?
- journal - what mattered?
- candidate - what may be worth remembering?
- approved memory - what should influence future reasoning?

This progression prevents runtime history from becoming memory by accident.

---

## 9. Journaling Model

### 9.1 Definition

A journal is a reflective artifact derived from activity over time.

A journal is not:

- a thread message
- a meeting summary by default
- a memory entry

A journal is closer to:

- reflection
- synthesis
- perspective
- episodic compression

### 9.2 Why journals exist

Journals exist because raw runtime activity is too noisy.

A good journal should help answer:

- what changed?
- what mattered?
- what was learned?
- what should be reconsidered later?
- what should not yet be generalized?

### 9.3 Journal ownership

Journals should belong primarily to:

- a workspace persona instance
- optionally a workspace-level reflection process
- optionally a meeting post or workstream post reflection context

This lets different workspace persona instances reflect differently on the same
activity.

### 9.4 Journal source discipline

Typical journal source material should include:

- post and thread activity
- meeting post activity
- workstream post activity
- notes and decisions
- references and artifacts when they materially shaped the work
- selected run outputs when policy allows

### 9.5 Journal types

Suggested journal types:

- daily
- weekly
- meeting reflection
- milestone summary
- design rationale
- technical notes
- retrospective
- manual reflection

### 9.6 Journal cadence and triggers

The journaling cadence should remain flexible.

Suggested trigger types:

#### Automatic triggers

- meeting completion
- thread-length or activity threshold
- major decision detected
- workstream closeout
- milestone reached
- repeated failure pattern detected

#### Scheduled triggers

- daily
- weekly
- end-of-sprint
- end-of-phase

#### Manual triggers

- "Write a reflection"
- "Summarize this workstream"
- "Record what we learned here"

### 9.7 Design law

> Journals are the first compression layer between lived activity and durable
> memory.

---

## 10. Memory Candidate Model

### 10.1 Definition

A memory candidate is a proposed durable learning extracted from one or more
source artifacts.

### 10.2 Normal source discipline

Memory candidates should normally derive from:

- journals
- notes
- decisions
- explicit operator-entered memory proposals
- steward-generated synthesis artifacts

Direct raw sources such as posts, threads, messages, or run artifacts should not
be first-class candidate sources by default. They should only produce candidates
when explicit policy or operator action allows it.

References and artifacts are usually evidence or context, not normal direct
candidate sources. They should usually shape journals, notes, or decisions
first, unless explicit policy or operator action promotes them directly.

### 10.3 Why candidates exist

Candidates create a buffer between:

- "this seems important"
- and
- "this should affect future reasoning"

This is a governance boundary.

### 10.4 Candidate scopes

A candidate may propose one of several scopes:

- workspace
- workspace persona
- persona global
- organization

Note:

- in scope labels, `workspace persona` is shorthand for memory attached to a
  workspace persona instance
- v1 does not establish first-class team memory
- if team-level relevance matters, it should be represented through tagged or
  linked workspace memory rather than a separate scope

### 10.5 Candidate quality questions

Every candidate should be evaluable against:

- Is this true?
- Is this useful?
- Is this durable?
- Is this local or general?
- Is this preference, fact, or interpretation?
- Should it expire?
- Could it contaminate another workspace if promoted too broadly?

### 10.6 Design law

> Candidates are not memory. They are memory proposals.

---

## 11. Memory Stewardship / Gardening

### 11.1 Definition

Memory gardening is the process of reviewing, pruning, clustering, promoting,
demoting, and archiving memory candidates and memory entries.

This may be performed by:

- the operator
- a stewardship workflow
- a dedicated memory gardener or steward service

### 11.2 Memory Gardener

This RFC treats `memory gardener` or `memory steward` as the normative concept.

Responsibilities may include:

- reading journals
- clustering recurring themes
- identifying patterns
- reducing duplication
- proposing memory candidates
- recommending promotion or archival
- suggesting link relationships between memories
- surfacing contradictions, staleness, or overscoped candidates

### 11.3 Rosie the Gardener

"Rosie the Gardener" may remain a useful internal or optional product metaphor.

Important rule:

- Rosie is not the normative system term in this RFC
- Rosie is not the final authority on trusted memory

### 11.4 Why the gardening metaphor works

A garden is:

- cultivated
- pruned
- seasonal
- structured
- alive

That maps better to memory than metaphors like database sync or autolearn.

### 11.5 Design law

> Memory should be cultivated, not accumulated.

---

## 12. Approved Memory Model

### 12.1 Definition

Approved memory is a durable memory entry that may influence future reasoning.

It is the only class of memory that should influence future reasoning by default.

### 12.2 Scope model

Approved memory may exist at several scopes.

#### Workspace memory

Knowledge that belongs only to one workspace.

Examples:

- this workspace uses staged rollout language
- this workspace avoids full-screen onboarding modals
- this workspace uses a specific terminology set

#### Workspace persona memory

Knowledge local to a workspace persona instance in one workspace.

Examples:

- the Product Designer in this workspace learned the operator prefers iterative
  option sets
- the SwiftUI Engineer in this workspace learned specific code review
  expectations in this codebase

Important rule:

- workspace persona memory belongs to the workspace persona instance, not to the
  persona template directly

#### Persona global memory

Cross-workspace expertise for a persona template.

Examples:

- the Product Designer has learned the operator prefers option framing over
  single-solution pitching
- the Senior SwiftUI Engineer has learned the operator consistently prefers
  small diffs and explicit verification

#### Organization memory

Higher-level cross-workspace knowledge.

Examples:

- a certain class of product experiments repeatedly fails
- specific growth heuristics work across multiple ventures

Organization memory is optional and may be absent in smaller self-hosted
deployments.

### 12.3 Scope note

In v1, team-level lessons should be represented as tagged or linked workspace
memory rather than a first-class team scope.

### 12.4 Design law

> Memory scope should be as narrow as possible, and only widen when justified.

---

## 13. Global Persona Memory Profile

### 13.1 Definition

A persona template may have a global memory profile that stores durable
cross-workspace learnings.

This is distinct from the template itself.

Orbit therefore distinguishes between:

- Persona Template - authored identity
- Persona Global Memory Profile - curated learned expertise

### 13.2 Why this separation matters

Without separation:

- authored identity gets polluted by runtime noise
- version control becomes confusing
- persona drift becomes hard to reason about

With separation:

- identity stays authored
- growth stays attributable
- promotion stays governable

### 13.3 Promotion rule

Promotion into persona-global memory should require stronger review than
workspace-local memory, because the blast radius is larger.

---

## 14. Memory Links and Traversal

### 14.1 Definition

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

### 14.2 Why links matter

Links allow Orbit to support contextual recall such as:

> "I remember a similar issue from another workspace around the same topic."

This makes memory retrieval richer without requiring a separate graph database
from day one.

### 14.3 Traversal model

Memory traversal may begin from:

- current workspace
- current workspace persona
- current directive or topic
- known linked patterns

Then expand outward in a controlled way.

### 14.4 Design law

> Memory should be traversable through explicit relationships, not vague
> similarity alone.

---

## 15. Memory Eligibility for Activation

RFC-0005 defines which classes of memory are eligible for activation, but not
the final activation retrieval order.

### 15.1 Default eligible memory

Approved memory is the default eligible memory for activation.

### 15.2 Conditionally eligible memory

Finalized journals may be included only when explicit policy enables reflective
context for a special mode.

### 15.3 Default ineligible memory

The following are not default activation inputs:

- memory candidates
- journal candidates
- raw post, thread, or message activity
- raw run artifacts

### 15.4 Ownership note

Exact activation retrieval order and activation-time retrieval behavior belong to
RFC-0001.

---

## 16. Memory Lifecycle

### 16.1 Candidate lifecycle

Candidate lifecycle states should include:

- `candidate`
- `approved`
- `rejected`
- `archived`
- `deferred`

These states describe governance and review state, not default activation
eligibility.

### 16.2 Approved-memory lifecycle

Approved-memory lifecycle states should include:

- `active`
- `archived`
- `superseded`
- `expired`

Approved memory may remain historically attributable even when it is no longer
eligible for default activation.

### 16.3 Why lifecycle states matter

Memory is not static.

Some knowledge:

- becomes obsolete
- is replaced
- turns out to be wrong
- should be retired after a project phase ends

The system must support that without losing history.

---

## 17. Review and Governance

### 17.1 Operator authority

The operator should remain the primary authority over:

- promotion to approved memory
- promotion to persona-global memory
- conflict resolution between candidates
- archival of stale memory
- widening or narrowing memory scope

### 17.2 Review actions

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

### 17.3 Steward-assisted workflow

A memory gardener may recommend:

- merging duplicate candidates
- widening or narrowing scope
- archiving stale entries
- surfacing conflicts
- creating memory links

But those recommendations should remain visible and attributable.

---

## 18. Failure Modes and Edge Cases

### 18.1 Every post or thread becomes a candidate

This creates memory spam.

Mitigation:

- journaling as intermediate compression
- thresholds and stewardship
- operator review

### 18.2 No one maintains the garden

Memory degrades over time.

Mitigation:

- scheduled gardening reviews
- stale-memory audits
- aging and archival policies

### 18.3 Workspace-local lesson promoted globally too early

This causes cross-workspace contamination.

Mitigation:

- require stronger evidence and review for global promotion
- preserve source lineage

### 18.4 Two memories conflict

This may happen when:

- workspaces diverge
- older memory becomes wrong
- two groups discover incompatible truths

Mitigation:

- explicit contradiction links
- review required before broad promotion
- expiration and supersession states

### 18.5 Journals are too generic

If journal prompts or journal forms are weak, they produce low-value
reflections.

Mitigation:

- persona-specific journal forms later
- meeting-type-sensitive reflection prompts
- stewardship curation

### 18.6 Raw runtime artifacts bypass journaling too often

This weakens the compression and governance boundary.

Mitigation:

- make journals the normal candidate source
- allow raw sources only by explicit policy or operator action

### 18.7 Memory becomes hidden magic

If operators cannot see why memory influenced a response, trust collapses.

Mitigation:

- trace memory sources for each run
- show scope and provenance in review tooling
- keep retrieval explainable

### 18.8 Stale memory remains active too long

Outdated memory may continue to influence activations.

Mitigation:

- lifecycle states
- staleness review workflows
- archival and supersession policies

---

## 19. UX / Product Implications

### 19.1 Journals are product artifacts

Journals may later appear as:

- timeline entries
- weekly collaborator reflections
- workspace retrospectives
- meeting or workstream follow-ups

### 19.2 Memory review must be first-class

The operator should be able to:

- inspect candidate memory
- approve, reject, or defer
- inspect provenance
- inspect linked memory
- see scope clearly

### 19.3 Memory Gardener may become a visible product feature

The memory gardener concept could appear as:

- a steward inbox
- a memory review assistant
- a gardener dashboard
- a weekly memory digest

Rosie may remain an optional product-facing nickname later, but the stewardship
role is the normative concept here.

### 19.4 Cross-workspace learning should feel earned

The UI should reinforce when something moved from:

- workspace-local insight
- to persona-global expertise

That should feel like a meaningful reviewed event.

---

## 20. Data Model Implications

This RFC depends on RFC-0002's runtime records and assigns lifecycle and
governance semantics to them, especially:

- `journal_entry`
- `journal_source`
- `memory_candidate`
- `memory_review`
- `memory_entry`
- `memory_link`
- `persona_global_memory_profile`
- `activation_memory_source`

It also depends on RFC-0003's workspace persona model, because journals and
workspace persona memory should attach to a workspace persona instance, not to a
persona template directly.

Source contexts referenced by RFC-0002 may include:

- `post`
- `thread`
- `message`
- `post_event`
- `note`
- `decision`
- `reference`
- `artifact`
- `workstream_state`
- `agent_run`

Important boundary:

- RFC-0002 owns runtime record shapes
- RFC-0005 owns the lifecycle and governance semantics applied to those records
- RFC-0001 owns activation retrieval behavior

---

## 21. Alternatives Considered

### Alternative A: Treat summaries as the only memory source

Rejected because:

- summaries are useful but too coarse
- they are not persona-specific enough
- they are not a sufficient reflection layer

### Alternative B: Let every collaborator mutate memory directly

Rejected because:

- memory growth becomes opaque
- noise accumulates easily
- operator governance weakens

### Alternative C: No journals, only candidates from raw runtime activity

Rejected because:

- candidate quality becomes too noisy
- episodic reflection is lost
- there is less opportunity for stewardship

### Alternative D: Global-only memory

Rejected because:

- it contaminates unrelated workspaces
- it weakens local context quality

### Alternative E: Workspace-only memory

Rejected because:

- it prevents durable persona expertise across workspaces
- it weakens the long-term learning loop

### Alternative F: First-class team memory in v1

Rejected because:

- team-level lessons can be represented through tagged or linked workspace memory
- a separate first-class team scope is not currently required

### Alternative G: Full autonomous stewardship

Rejected for now because:

- too much trust is transferred to automation
- it conflicts with Orbit's operator-centered control model

---

## 22. Risks and Tradeoffs

### Risk: More product surface area

Journals, candidates, gardening, and review add visible complexity.

Tradeoff:

- Orbit's differentiator is responsible memory, not just chat

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

### Risk: Governance fatigue

If every candidate demands equal attention, operators may disengage.

Tradeoff:

- a staged model with stewardship and prioritization is still preferable to
  unguided accumulation

---

## 23. Open Questions

- Should some journal types be persona-specific from day one?
- Should there be automatic staleness review for older memory?
- Should global persona memory promotion require more than one workspace source?
- Should Rosie remain only an optional product nickname, or later become a named
  visible feature?
- Should meeting or workstream closeout notes always seed candidate generation,
  or only some types?
- Should users be able to manually author memory candidates directly?
- Should team-level relevance remain represented only through tagged workspace
  memory, or ever become a first-class scope later?

---

## 24. Recommendation

Adopt the journaling -> candidate -> review -> approved memory model as Orbit's
durable learning architecture.

Specifically:

- journals should be first-class reflective artifacts
- memory candidates should remain a required staging layer
- approved memory should be the only default trusted memory for future
  reasoning
- persona-global memory should remain separate from authored templates
- memory links should support explicit traversal and lineage
- memory gardeners should be treated as stewardship, not authority

This is the strongest path for letting collaborators become more expert without
losing Orbit's core values of explicitness, operator control, and explainability.

---

## 25. Rollout / Adoption Plan

### Phase 1

Introduce:

- `journal_entry`
- `journal_source`
- `memory_candidate`
- `memory_review`
- manual review workflow

Goal:

- establish structured memory staging

### Phase 2

Introduce:

- approved memory scopes:
  - workspace
  - workspace persona
  - persona global
  - organization where enabled
- durable approved memory eligibility for activation
- activation-memory-source linkage
- memory lineage inspection

Goal:

- support useful memory in activations without weakening governance

### Phase 3

Introduce:

- memory gardener workflows
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

- support multi-workspace learning and institutional memory

---

## 26. Self-Review

- Does this model preserve operator authority over durable memory?
  Yes.

- Does it create a meaningful boundary between lived activity and trusted
  memory?
  Yes.

- Does it support both local and cross-workspace learning?
  Yes.

- Does it prevent authored persona identity from being mutated by runtime noise?
  Yes.

- Does it leave room for an optional Rosie nickname later without requiring that
  on day one?
  Yes.

- Does it keep retrieval-order ownership out of this RFC?
  Yes.

- Does it define lifecycle semantics without taking over runtime record schema?
  Yes.

---

## 27. Decision Log

- 2026-03-08 - Initial draft created
- 2026-03-17 - Reframed RFC around Orbit as the platform and PersonaKit as the
  authored-contract engine
- 2026-03-17 - Removed first-class team memory from v1 and aligned memory scopes
  to workspace, workspace persona, persona global, and organization
- 2026-03-17 - Replaced retrieval-order ownership with activation-eligibility
  guidance and deferred exact retrieval behavior to RFC-0001
- 2026-03-17 - Clarified that journals are the normal first compression layer,
  while raw runtime artifacts become candidate sources only by explicit policy
- 2026-03-17 - Removed duplicate appended draft and filecite artifacts
- 2026-03-17 - Added explicit lifecycle semantics, clarified workspace persona
  scope labels, treated references and artifacts as indirect candidate sources
  by default, and marked organization memory as optional in smaller deployments
