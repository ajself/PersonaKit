# RFC-0001: Workspace Persona Contract Resolution and Activation Model

## Status
Draft

## Authors
- AJ Self

## Created
2026-03-08

## Last Updated
2026-03-17

## Related
- RFC-0002 - Collaboration Runtime and Memory Data Model
- RFC-0003 - Workspace, Group, and Workspace Persona Instance Model
- RFC-0004 - Teams, Squads, and Meeting Coordinator Model
- RFC-0005 - Memory Journaling and Gardening Model
- RFC-0006 - Multi-Client Platform Architecture
- Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md
- Docs/Orbit/RFCs/README.md

---

## 1. Summary

This RFC defines how Orbit resolves a workspace persona operating contract before
an AI collaborator responds.

Persona activation is not just directive selection. In Orbit, activation must
deterministically resolve:

- which workspace and collaboration context are active
- which workspace persona instance should respond
- whether the response stays in a post thread or promotes into a linked post
- which directive, kits, and authorized skills apply
- which memory scopes and memory sources are available
- which stop points and review gates constrain execution
- which records must be persisted for traceability and operator control

This RFC treats activation as a contract-resolution step that joins PersonaKit
authored truth with Orbit runtime truth.

It does not define the full post/thread data model, final SQL schema, or final
prompt assembly format. Those belong to later RFCs and implementation docs.

Terminology note:

- `user` initiates interactions in Orbit
- `operator` governs review, approval, and control
- in v1, the same person often plays both roles, but the distinction remains
  important in the model

---

## 2. Motivation

Orbit treats AI collaborators as durable teammates rather than disposable
prompts.

That only works if the system can always explain why a collaborator responded,
under what rules, and with which memory context.

As Orbit evolves toward a command center built around:

- workspaces
- teams and squads
- message posts and message threads
- meeting posts
- workstream posts
- journaling and reviewed memory

the old framing of activation as "pick a directive and run" becomes too narrow.

Without an explicit contract-resolution model:

- collaborator behavior becomes ambiguous
- team and squad addressing becomes unsafe
- meetings and workstreams lose deterministic grounding
- memory retrieval becomes inconsistent
- operator trust degrades because traceability is incomplete

This RFC exists to define the activation model before that ambiguity spreads into
runtime behavior, storage, and client UX.

---

## 3. Problem Statement

When a user creates or replies in a message post thread, Orbit must answer all
of the following deterministically:

- which workspace and channel are active
- which post, thread, and message triggered the response
- whether the target is a specific collaborator, a team, or a squad
- which workspace persona instances should be activated
- whether the response stays in-thread, enters meeting mode, promotes to a
  meeting post, or creates a workstream post
- which directive governs reasoning
- which kits and skills are authorized
- which stop points or review gates apply
- which memory sources may be loaded
- what trace records must be written so the operator can inspect the result

Example:

> The user posts in `#engineering`, asks `@Samwise` and the Product Team for
> feedback, then starts a linked workstream post from the same discussion.

Orbit must resolve not just "who should answer," but the full contract under
which each response and follow-on action occurs.

Without a formal model for those rules, Orbit risks:

- ambiguous collaborator identity
- inconsistent directive or kit selection
- unauthorized skill use
- cross-workspace memory leakage
- opaque meeting and workstream promotion behavior
- weak operator control at exactly the moments when Orbit must be explainable

---

## 4. Goals

This RFC aims to establish an activation model that:

- resolves workspace persona identity deterministically
- uses Orbit runtime context such as workspace, channel, post, thread, and
  target type during activation
- treats directive resolution as one part of a larger contract-resolution step
- supports collaborator, team, and squad targeting
- supports post-thread replies, meeting promotion, and workstream creation
- resolves kits, skill authorization, memory scope, and review constraints
- records enough trace data for operator inspection and debugging
- supports degraded execution when memory or context retrieval partially fails
- preserves PersonaKit's core principles:
  - explicit over inferred
  - structure over autonomy
  - operators remain in control

---

## 5. Non-Goals

This RFC does not define:

- the full post/thread/message schema
- the exact SQL tables or migrations
- the final client UI behavior
- the final sync or subscription protocol
- the final prompt template format
- provider-specific execution payloads
- the final memory ranking algorithm
- the exact data model for teams, squads, channels, or journaling

Those belong primarily to RFC-0002, RFC-0003, RFC-0004, RFC-0005, and later
implementation docs.

---

## 6. Proposal

Orbit should treat activation as **workspace persona contract resolution in
runtime context**.

The proposal has five major parts:

1. Separate PersonaKit authored truth from Orbit runtime truth
2. Resolve workspace persona instances, not persona templates, at runtime
3. Resolve a full operating contract, not just a directive
4. Persist an activation trace that explains why the response happened
5. Make high-consequence follow-on actions visible and operator-controlled

### Core design law

> PersonaKit defines who may act and under what rules.
> Orbit provides the runtime context in which that contract is resolved.

### RFC ownership boundary

This RFC owns:

- activation semantics
- contract resolution
- activation trace requirements
- failure and degradation behavior

This RFC does not own the full durable shape of posts, threads, meetings,
workstreams, or memory records.

---

## 7. Authored Truth Vs Runtime Truth

Activation joins two categories of truth.

### 7.1 PersonaKit authored truth

PersonaKit remains the source of authored operating contract data:

- personas
- directives
- kits
- sessions
- skill authorization
- operating constraints

### 7.2 Orbit runtime truth

Orbit supplies the collaboration context in which activation happens:

- workspace
- channel
- team or squad target
- workspace persona instance
- post
- thread
- message
- participants
- post relationships

### 7.3 Important rule

PersonaKit does not infer live collaboration state from runtime history.
Orbit does not author or override persona contracts ad hoc.

Workspace persona overrides are valid only when they are explicit persisted
records in Orbit or PersonaKit-backed runtime state. Ad hoc per-thread runtime
mutation is not part of this model.

Activation depends on both layers, and the resolved trace must show what came
from each.

---

## 8. Persona Templates, Workspace Personas, And Collaborators

Orbit separates collaborator identity into three layers.

### 8.1 Persona template

A persona template is the authored archetype.

Examples:

- Product Designer
- Senior SwiftUI Engineer
- Product Manager

Templates define global role expectations and contain no workspace-specific
memory.

### 8.2 Workspace persona instance

A workspace persona instance is the local runtime identity anchored in one
workspace.

It carries the local context needed for activation:

- workspace affiliation
- local memory scope
- local history and journals
- directive override state if present
- participation in posts, meetings, and workstreams

Activation always resolves to workspace persona instances, not templates.

### 8.3 Collaborator

A collaborator is the user-facing AI teammate produced when execution runtime
operates under a workspace persona contract.

This distinction matters because Orbit surfaces collaborators, while PersonaKit
resolves the authored contract behind them.

---

## 9. Contract Resolution

Activation should resolve a full operating contract in a deterministic order.

### 9.1 Resolution inputs

The resolver may receive inputs from:

- explicit collaborator mentions
- explicit team or squad addressing
- active workspace and channel context
- the origin post, thread, and message
- linked post relationships
- active session defaults
- authored workspace persona overrides represented as explicit persisted records

### 9.2 Workspace and collaboration context resolution

Before resolving any collaborator, Orbit must resolve:

- `workspace_id`
- `channel_id` when applicable
- `origin_post_id`
- `origin_thread_id`
- `trigger_message_id`

If workspace resolution is ambiguous, activation must not proceed silently.

### 9.3 Target resolution

Activation targets may be:

- a specific collaborator
- a team
- a squad

If the target is a team or squad, Orbit expands that target into concrete
participants before activation continues.

Expansion results must be recorded so the operator can inspect why a given
workspace persona instance was included.

Team or squad expansion yields one `persona_activation` record per resolved
workspace persona instance.

### 9.4 Workspace persona instance resolution

For each concrete target, Orbit resolves a workspace persona instance inside the
active workspace.

If no matching workspace persona instance exists, Orbit must block, degrade, or
ask the operator for clarification depending on the failure mode.

### 9.5 Response mode resolution

Before execution, Orbit must determine the collaboration mode:

- inline reply in the current post thread
- lightweight meeting mode in the current thread
- promotion into a linked meeting post
- creation of a linked workstream post

This decision belongs in the activation trace because it changes both user
experience and governance expectations.

### 9.6 Directive resolution

Directive resolution follows this priority:

1. Explicit directive in the user request
2. Directive defined by the active session
3. Workspace persona directive override
4. Persona template default directive

If no directive can be resolved, activation must block with traceable
operator-facing explanation.

### 9.7 Kit resolution

Kits are resolved as part of the workspace persona contract.

The exact authored precedence remains owned by PersonaKit contract resolution,
but Orbit must persist the final resolved kit set in the activation trace.

### 9.8 Skill authorization resolution

Authorized skills are determined by the resolved PersonaKit contract.

Orbit must not allow runtime context to grant capabilities that PersonaKit did
not authorize.

### 9.9 Stop point and review gate resolution

Before execution begins, Orbit must resolve whether the contract imposes:

- mandatory stop points
- operator review gates
- prohibited follow-on actions

Those constraints must be available to the operator in trace views.

### 9.10 Memory scope resolution

Activation must resolve the set of memory scopes available for retrieval, such
as:

- workspace memory
- workspace persona memory
- global persona profile memory
- explicitly promoted cross-workspace memory
- organization memory where applicable

Candidate memory is not automatically part of activation input.

---

## 10. Activation Flow

### 10.1 Activation sequence

```text
User creates a message post or replies in an existing post thread
  -> Orbit resolves workspace, channel, post, thread, and trigger message
  -> Orbit resolves target kind (collaborator, team, or squad)
  -> Team or squad expansion produces concrete participants when needed
  -> Orbit resolves workspace persona instances
  -> PersonaKit resolves directive, kits, skill authorization, and constraints
  -> Memory retrieval runs against approved scopes
  -> Context is assembled for execution
  -> Execution runner performs one or more turns
  -> Response persists in-thread or promotes into a linked post
  -> Events and activation trace records are persisted
```

### 10.2 Important separation

This RFC makes a hard distinction between:

- runtime collaboration context
- contract resolution
- execution
- trace recording

Those steps are linked, but they should not collapse into one opaque provider
call.

---

## 11. Required Activation Records

This section defines the conceptual records RFC-0001 requires. It does not lock
the final SQL schema.

### 11.1 `persona_activation`

Represents one resolved activation of a workspace persona instance.

When a team or squad target expands into multiple concrete recipients, Orbit
creates one `persona_activation` record per resolved workspace persona instance.

Conceptual fields:

- `id`
- `initiated_by_participant_id`
- `workspace_id`
- `channel_id` nullable
- `origin_post_id`
- `origin_thread_id`
- `trigger_message_id`
- `addressed_target_kind` (`collaborator`, `team`, `squad`)
- `addressed_target_reference_id`
- `resolved_workspace_persona_instance_id`
- `response_mode`
- `directive_id`
- `session_id` nullable
- `activation_reason`
- `degraded_context_reason` nullable
- `created_at`

### 11.2 `activation_contract_snapshot`

Represents the resolved contract data used for execution.

Conceptual fields:

- `persona_activation_id`
- `kit_ids`
- `directive_source`
- `kit_source`
- `skill_authorization_source`
- `authorized_skill_snapshot`
- `stop_point_snapshot`
- `review_gate_snapshot`
- `memory_scope_snapshot`
- `contract_version_refs`

### 11.3 `activation_memory_source`

Represents the approved memory sources loaded for a specific activation.

Conceptual fields:

- `persona_activation_id`
- `memory_source_kind`
- `memory_source_id`
- `scope`
- `retrieval_reason`

### 11.4 `agent_run`

Represents the execution run that occurs after activation resolves.

Conceptual fields:

- `id`
- `persona_activation_id`
- `runner_kind`
- `status`
- `started_at`
- `completed_at` nullable
- `failure_reason` nullable

### 11.5 Inspectability requirement

At minimum, Orbit must make the following activation fields operator-visible:

- resolved workspace persona instance
- addressed target and resolved recipient relationship
- why this collaborator was selected, including direct mention, team expansion,
  or squad expansion
- directive and kits
- authorized skills
- stop points and review gates
- memory sources used
- degraded-context flags
- origin post, thread, and message

### 11.6 Example activation trace

```text
persona_activation
  initiated_by_participant_id: user-123
  workspace_id: foobar
  channel_id: engineering
  origin_post_id: post-001
  origin_thread_id: thread-001
  trigger_message_id: msg-004
  addressed_target_kind: team
  addressed_target_reference_id: product-team
  resolved_workspace_persona_instance_id: foobar-product-manager
  response_mode: inline-reply
  directive_id: product-evaluation
  session_id: orbit-default
  activation_reason: team-expanded-from-message-post
  degraded_context_reason: null

activation_contract_snapshot
  directive_source: active-session
  kit_source: workspace-persona-override
  skill_authorization_source: resolved-contract
  kit_ids: [product-core]
  authorized_skill_snapshot: [research-read, summary-write]
  stop_point_snapshot: [requires-review-for-external-actions]
  review_gate_snapshot: [memory-promotion]
  memory_scope_snapshot: [workspace, workspace-persona]

activation_memory_source
  memory_source_kind: workspace-memory
  memory_source_id: wm-12
```

---

## 12. Memory Retrieval

Memory retrieval happens after workspace persona resolution and before execution.

### Retrieval order

1. Workspace memory
2. Finalized workspace persona journals and approved workspace persona memory
3. Global persona profile memory
4. Explicitly promoted cross-workspace memory
5. Organization memory

### Important rules

- approved memory may influence activation
- finalized journals may influence activation when policy allows
- journal candidates do not influence activation
- candidate memory does not influence activation by default
- retrieval should prefer local context before global patterns
- retrieval failure may degrade the run, but must be recorded explicitly

This RFC does not define ranking or indexing strategy. It defines when retrieval
happens and what scopes are eligible.

---

## 13. Traceability And Operator Control

Every collaborator response must be inspectable.

Orbit should be able to explain:

- which workspace persona instance responded
- which addressed target led to that resolved recipient
- why that collaborator was selected
- which directive and kits were active
- which skills or tools were authorized
- which memory sources were loaded
- which stop points or review gates applied
- which post, thread, and message triggered the response
- whether the run proceeded with degraded context
- whether the response stayed in-thread or created a linked post

### High-consequence rule

Activation alone does not authorize every follow-on action.

If a resolved contract or runtime state indicates a high-consequence action,
Orbit must require explicit operator review before proceeding.

Examples:

- memory promotion
- cross-workspace knowledge promotion
- consequential external actions
- workstream closeout when review gates are not satisfied

---

## 14. Edge Cases And Failure Modes

### 14.1 Ambiguous workspace

Behavior: block and request operator clarification.

### 14.2 Ambiguous collaborator

Behavior: block and request operator clarification.

### 14.3 Team or squad expansion partial failure

Behavior: continue only if Orbit records which targets resolved and which failed,
then surfaces the partial result to the operator.

### 14.4 Missing workspace persona instance

Behavior: block or request clarification. Orbit must not silently fall back to a
persona template as if it were a workspace persona instance.

### 14.5 Missing directive

Behavior: block activation and present a traceable operator-facing error.

### 14.6 Unauthorized directive, kit, or skill

Behavior: block the unauthorized action and record the reason in the activation
trace.

### 14.7 Stop point triggered before execution

Behavior: pause and wait for operator review.

### 14.8 Memory retrieval failure

Behavior: the run may continue in degraded mode if allowed, but Orbit must
record the missing memory context and surface it to the operator.

### 14.9 Template or directive revision mid-thread

Behavior: activation trace must record the version references used for the run.
Future runs may use newer versions, but past runs remain attributable.

### 14.10 Meeting promotion from a message post thread

Behavior: Orbit records the relationship between the origin post and the linked
meeting post so continuity remains inspectable.

### 14.11 Workstream post creation from a message post thread

Behavior: Orbit records the relationship between the origin post and the linked
workstream post, including which activation triggered the creation.

---

## 15. Alternatives Considered

### 15.1 Directive-only activation

Rejected because it does not capture kits, skill authorization, stop points,
runtime context, or operator-visible trace requirements.

### 15.2 Implicit activation from chat history alone

Rejected because Orbit aims for explicit, explainable behavior rather than
inferred identity shifts.

### 15.3 Provider-owned activation

Rejected because contract resolution belongs to PersonaKit and Orbit, not to an
opaque provider runtime.

---

## 16. Risks And Tradeoffs

- The model is more explicit than a casual chat product, which increases upfront
  design complexity.
- Operators may experience more review friction in exchange for stronger trust.
- Some details are intentionally deferred to later RFCs, which requires careful
  boundary discipline to avoid overlap.
- If Orbit overfits this vocabulary too early, later product evolution may need
  careful renaming or migration.

These tradeoffs are acceptable because Orbit's product promise depends on
explainability, stable identity, and deliberate control.

---

## 17. Recommendation

Adopt the contract-resolution and activation model described in this RFC as the
canonical mechanism for introducing collaborators into Orbit runtime context.

This keeps PersonaKit in charge of authored operating contracts while making
Orbit responsible for runtime collaboration context, activation traceability,
and operator-visible control.

---

## 18. Rollout / Adoption Plan

1. Accept the terminology and title shift in RFC-0001
2. Align RFC-0002 with the post/thread runtime model and authored/runtime split
3. Align RFC-0003 and RFC-0004 with workspace persona instance and target
   expansion terminology
4. Align RFC-0005 with the memory retrieval and approved-memory assumptions used
   here
5. Implement activation trace persistence and operator-visible trace inspection
6. Treat this RFC as a prerequisite for Orbit execution and collaboration UX

---

## 19. Self-Review

This RFC intentionally leaves several details open:

- final SQL schema
- final API and event shapes
- exact prompt assembly details
- final memory ranking strategy
- final execution runner implementation

That is deliberate. The goal here is to lock the activation semantics and system
boundaries before lower-level runtime implementation begins.

---

## 20. Decision Log

- 2026-03-08 - Initial draft created
- 2026-03-17 - Reframed RFC around workspace persona contract resolution,
  post/thread runtime context, traceability, and operator control
- 2026-03-17 - Clarified group-target tracing, directive failure behavior,
  journal eligibility, explicit override persistence, and renamed the RFC file
