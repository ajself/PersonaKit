# RFC-0003: Workspace, Group, and Workspace Persona Instance Model

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
- RFC-0004: Teams, Squads, and Meeting Coordinator Model
- RFC-0005: Memory Journaling and Gardening Model
- RFC-0006: Multi-Client Platform Architecture
- Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md
- Docs/Orbit/RFCs/README.md

---

## 1. Summary

This RFC defines the persistent structure model for Orbit workspaces, groups,
and workspace persona instances.

Orbit is the collaboration platform. PersonaKit is the authored-contract engine
that defines personas, directives, kits, sessions, and operating constraints.

This RFC focuses on the persistent structure that Orbit must preserve so that
collaboration remains legible and grounded:

- workspaces as durable operating boundaries
- channels as workspace-scoped organizational surfaces
- teams and squads as persistent group structures
- workspace persona instances as local identity anchors
- persistent membership relationships between workspace persona instances and
  groups
- memory ownership boundaries that prevent cross-workspace contamination

This RFC also adopts a three-layer identity model:

1. Persona template
2. Workspace persona instance
3. Collaborator

The collaborator is the user-facing AI teammate surfaced by Orbit. The
workspace persona instance is the local runtime identity under which that
collaborator operates. The persona template remains the authored global source.

This RFC is the semantic owner of workspace, group, and workspace persona
instance structure. RFC-0002 should reference these structures when modeling
runtime collaboration records, including the concrete `channel` entity shape.

---

## 2. Motivation

Orbit is designed for operators who work across multiple ventures, products,
research efforts, and internal initiatives with a persistent roster of AI
collaborators.

That product direction only works if Orbit can answer questions like:

- which workspace persona instances exist in a given workspace?
- which groups are durable and which are runtime-only?
- what separates local expertise from cross-workspace learning?
- how does a collaborator remain stable inside one workspace while still being
  derived from a reusable authored template?

Without a clear structure model:

- identity becomes ambiguous
- group semantics drift across workspaces
- memory contamination becomes likely
- activation loses reliable structural inputs
- runtime collaboration records in RFC-0002 lose a stable semantic anchor

This RFC exists to define those persistent structural boundaries before more
runtime behavior is added on top.

---

## 3. Problem Statement

Orbit must answer the following questions deterministically:

- which workspace persona instances exist in a workspace?
- which persona template is each workspace persona instance derived from?
- which groups are persistent teams versus focused squads?
- which workspace persona instances belong to which teams and squads?
- how are channels scoped within a workspace?
- how do local workspace persona memories stay isolated from other workspaces?
- how can cross-workspace learning happen without mutating local identity or
  contaminating project context?

Without a formal model for these questions, Orbit risks:

- identity ambiguity
- memory leakage across workspaces
- fragile activation inputs
- inconsistent group semantics
- unclear ownership between RFC-0001, RFC-0002, and RFC-0005

---

## 4. Goals

This RFC aims to establish a model that:

- supports multiple workspaces under one operator or small-team deployment
- clearly separates persona templates, workspace persona instances, and
  collaborators
- allows persona templates to be reused safely across workspaces
- isolates workspace-specific experience and memory ownership boundaries
- defines teams and squads as persistent structures inside a workspace
- defines persistent membership separately from runtime participation
- provides stable structural inputs for deterministic activation
- supports controlled cross-workspace learning through explicit promotion
- preserves explainability for how a collaborator behaves within a workspace
- gives RFC-0002 a stable semantic foundation for runtime collaboration records

---

## 5. Non-Goals

This RFC does not define:

- the UI for workspace management
- the exact API surface for workspace creation
- authentication and multi-user tenancy models
- post, thread, message, or runtime participation records
- activation flow or contract-resolution precedence
- memory retrieval order or ranking
- exact journaling or memory candidate lifecycle behavior

Those concerns belong primarily to RFC-0001, RFC-0002, RFC-0005, and later
implementation docs.

---

## 6. Proposal

Orbit should model persistent structure through four main concepts:

1. Workspaces
2. Channels
3. Groups (teams and squads)
4. Workspace persona instances

These structures provide the stable operating surface on which activation,
runtime collaboration, journaling, and memory later depend.

### Core design law

> PersonaKit defines the authored contract source.
> Orbit defines the persistent runtime structure in which that contract is used.

### Ownership boundary

This RFC owns the semantic meaning of:

- `workspace`
- `channel` as a workspace-scoped structure
- `team`
- `squad`
- `workspace_persona`
- `workspace_persona_membership`

This RFC does not own the post/thread/message runtime model or activation
semantics. Those belong to RFC-0002 and RFC-0001 respectively.

---

## 7. Authored Truth Vs Runtime Structure

Orbit's structure model only makes sense when separated from PersonaKit authored
truth.

### 7.1 PersonaKit authored truth

PersonaKit remains the source of:

- persona templates
- directives
- kits
- sessions
- skill authorization
- operating constraints

### 7.2 Orbit runtime structure

Orbit stores the persistent structural layer in which those contracts are used:

- workspaces
- channels
- teams
- squads
- workspace persona instances
- persistent memberships

### 7.3 Important boundary

RFC-0003 defines the structural meaning of those concepts.
RFC-0002 defines how collaboration runtime records attach to them.
RFC-0001 defines how activation resolves against them.

---

## 8. Identity Layers

Orbit should use a three-layer identity model.

### 8.1 Persona template

A persona template is the authored global archetype.

Examples:

- Product Designer
- Senior SwiftUI Engineer
- Product Manager
- Research Lead

Persona templates define:

- role expectations
- values and blind spots
- default directive
- default kits
- skill boundaries

Templates do not contain workspace-local history or workspace-local memory.

### 8.2 Workspace persona instance

A workspace persona instance is the local runtime identity anchored in one
workspace.

It carries the local context needed for collaboration and activation:

- workspace affiliation
- local memory ownership boundary
- local history and journals
- explicit persisted overrides when allowed
- persistent group memberships

Activation always resolves to workspace persona instances, not templates.

### 8.3 Collaborator

A collaborator is the user-facing AI teammate surfaced by Orbit when execution
runtime operates under a workspace persona contract.

Important note:

- `collaborator` is a semantic and product-facing layer in this RFC
- it is not introduced here as a separate stored entity

This distinction matters because users interact with collaborators, while Orbit
and PersonaKit reason about workspace persona instances and authored templates.

---

## 9. Workspace, Channel, and Group Structure

```text
Operator
  -> Workspaces
       -> Channels
       -> Teams / Squads
       -> Workspace Persona Instances
            -> derived from Persona Templates
            -> surfaced as Collaborators
```

### 9.1 Workspace

A workspace is the durable operating boundary for a venture, product, research
stream, or internal initiative.

Workspaces scope:

- channels
- teams and squads
- workspace persona instances
- workspace-local memory ownership
- runtime collaboration context attached by RFC-0002

### 9.2 Channel scope

Channels are workspace-scoped organizational surfaces.

RFC-0003 acknowledges them because they are part of workspace structure, but it
does not own their full runtime entity definition. RFC-0002 defines how posts
and threads attach to channels.

Important channel rules:

- a channel belongs to exactly one workspace
- a channel never spans workspace boundaries
- channels organize runtime collaboration, but do not weaken workspace memory or
  identity boundaries
- channels are organizational surfaces, not independent identity or memory
  scopes

### 9.3 Team

A team is a durable organizational group inside a workspace.

Teams provide continuity and broad functional grouping, such as:

- Product Team
- Engineering Team
- Research Team

### 9.4 Squad

A squad is a focused working group inside a workspace.

Squads may be temporary, initiative-bound, and cross-team. They exist to define
persistent coordination targets before runtime participation begins.

---

## 10. Persistent Membership Vs Runtime Participation

RFC-0003 owns persistent membership semantics only.

Persistent membership includes:

- which workspace persona instances belong to a team
- which workspace persona instances belong to a squad
- what role a workspace persona instance holds in that persistent group

RFC-0003 does not own ad-hoc runtime participation such as:

- meeting participant selection
- workstream contributor assignment
- temporary discussion participation in a post thread

Those belong to RFC-0002 and RFC-0004.

This separation is important because persistent group structure is not the same
thing as runtime participation.

---

## 11. Conceptual Records

This section defines conceptual structural records. It does not lock the final
SQL schema.

### 11.1 `workspace`

Fields:

- `id`
- `slug`
- `name`
- `status`
- `created_at`
- `archived_at` nullable

Purpose:

- durable operating boundary
- local scope for channels, groups, workspace persona instances, and workspace
  memory

### 11.2 `team`

Fields:

- `id`
- `workspace_id`
- `slug`
- `name`
- `purpose`
- `created_at`

Purpose:

- long-lived organizational grouping inside a workspace

### 11.3 `squad`

Fields:

- `id`
- `workspace_id`
- `team_id` nullable
- `slug`
- `name`
- `purpose`
- `created_at`

Purpose:

- focused initiative grouping inside a workspace

### 11.4 `workspace_persona`

In schema shorthand, this record aligns with the `workspace_persona` entity used
in RFC-0002, while the fuller term in product and contract language remains
`workspace persona instance`.

Fields:

- `id`
- `workspace_id`
- `persona_template_id`
- `display_name`
- `default_directive_override_id` nullable
- `status`
- `created_at`
- `archived_at` nullable

Purpose:

- local runtime identity anchor derived from a persona template
- durable workspace-specific home for local expertise and membership

### 11.5 `workspace_persona_membership`

Fields:

- `id`
- `workspace_persona_id`
- `team_id` nullable
- `squad_id` nullable
- `role_in_group`
- `created_at`

Purpose:

- persistent membership relationship between a workspace persona instance and
  group structures

---

## 12. Activation Dependencies

RFC-0003 does not define activation flow, but it does define the structural
inputs activation depends on.

Activation under RFC-0001 depends on:

- active workspace
- relevant channel, post, and thread context supplied by RFC-0002
- persistent team and squad targets defined here
- resolved workspace persona instances defined here
- explicit persisted overrides attached to workspace persona instances when
  allowed

RFC-0004 owns how persistent teams and squads expand into runtime participant
sets during coordination.

This means RFC-0003 is a prerequisite for deterministic contract resolution, but
it is not the owner of that resolution logic.

---

## 13. Memory Ownership Boundaries

RFC-0003 defines memory ownership boundaries, not retrieval order.

The relevant memory ownership layers are:

- workspace memory
- workspace persona memory
- persona global memory
- organization memory

Workspace persona memory belongs to a workspace persona instance, not to the
persona template directly.

Important rule:

- local workspace persona experience belongs first to the workspace persona and
  workspace that produced it
- cross-workspace learning must be promoted explicitly
- retrieval order belongs to RFC-0001
- journaling and memory lifecycle belong to RFC-0005

---

## 14. Cross-Workspace Promotion

Workspace persona instances may contribute to persona-global learning, but that
promotion is never automatic.

Global learning should happen only through explicit reviewed promotion flows.

This preserves two important truths:

- workspace-local identity remains stable and uncontaminated
- reusable cross-workspace insight is still possible when deliberately promoted

Example:

```text
Persona Template
  Product Designer

Workspace Persona Instances
  Bar / Product Designer
  Baz / Product Designer
  InternalTools / Product Designer

Promoted Learning
  Product Designer global profile
```

---

## 15. Edge Cases And Failure Modes

### 15.1 Persona template archived or deleted

Workspace persona instances should retain historical identity and attribution.
Past collaboration should not become anonymous because the authored source later
changes.

### 15.2 Workspace archived

Workspace-local structure and memory should become read-only while preserving
historical attribution and traceability.

### 15.3 Workspace renamed

Historical records should rely on stable identifiers rather than mutable display
names or slugs alone.

### 15.4 Workspace persona instance archived

The instance should remain available for historical attribution, but should not
be selected for new activation unless explicitly restored.

### 15.5 Workspace persona instance renamed

Historical records should continue to reference stable identifiers, not only the
current display name.

### 15.6 Workspace persona membership changes mid-project

Future target expansion may use the new membership state, but past activation
and participation traces must remain attributable to the prior structure.

### 15.7 Persisted override removed

Future activations may stop using the override, but historical runs must remain
traceable to the version of structure and override state that existed at the
time.

### 15.8 Workspace persona instance moved between workspaces

This should not be treated as an in-place move. A workspace persona instance is
anchored to one workspace. If similar identity is needed elsewhere, Orbit should
create a new workspace persona instance and rely on explicit promotion for any
cross-workspace learning.

---

## 16. Alternatives Considered

### Alternative A: Template-only identity

Rejected because it collapses local identity, local history, and local memory
into a global role definition.

### Alternative B: No workspace persona instance layer

Rejected because Orbit needs a local structural identity anchor for memory,
membership, and activation.

### Alternative C: Groups defined only at runtime

Rejected because teams and squads need persistent semantics beyond a single
meeting or thread.

### Alternative D: Automatic cross-workspace learning

Rejected because it invites contamination and weakens operator control.

---

## 17. Risks And Tradeoffs

### Risk: Increased conceptual complexity

Introducing workspace persona instances adds a layer beyond persona templates.

Tradeoff:

- the extra layer reflects real collaboration structure
- it prevents identity drift and unsafe memory sharing

### Risk: Overlap with RFC-0002

Workspace, team, squad, and workspace persona structures are referenced in both
RFC-0002 and RFC-0003.

Tradeoff:

- RFC-0003 should remain the semantic owner of those structures
- RFC-0002 may reference them for runtime collaboration modeling

### Risk: Over-modeling collaborator language

The collaborator layer may later need more formalization.

Tradeoff:

- for now, keeping collaborator semantic instead of structural prevents premature
  schema growth

### Risk: Memory duplication across workspaces

Tradeoff:

- explicit promotion pipelines allow meaningful insight to move into global
  profiles without contaminating local workspace state

---

## 18. Recommendation

Adopt the persona template, workspace persona instance, and collaborator model
as the core identity architecture for Orbit.

Specifically:

- keep persona templates authored in PersonaKit
- treat workspace persona instances as the local runtime identity anchors inside
  Orbit
- treat collaborators as the user-facing AI teammates surfaced from those local
  identities
- keep teams and squads as persistent structures
- keep runtime participation out of this RFC
- enforce explicit promotion for cross-workspace learning

This structure should anchor later collaboration, activation, and memory RFCs.

---

## 19. Rollout / Adoption Plan

### Phase 1

Introduce foundational structure:

- workspace
- workspace-scoped channel semantics
- workspace_persona
- team
- squad
- workspace_persona_membership

Goal:

- stable persistent structure for local identity and group organization

### Phase 2

Integrate with RFC-0001 activation:

- workspace persona instance resolution
- target expansion inputs
- explicit persisted override handling

Goal:

- deterministic contract resolution grounded in persistent structure

### Phase 3

Integrate with RFC-0002 runtime collaboration:

- posts and threads attach to workspace and channel structure
- runtime participation attaches to persistent structures

Goal:

- collaboration runtime records inherit stable semantic meaning

### Phase 4

Integrate with RFC-0005 memory promotion:

- workspace-local memory boundaries
- persona-global promotion rules
- reviewed cross-workspace learning

Goal:

- safe local learning with explicit global promotion

---

## 20. Open Questions

- Should a workspace persona instance always derive from exactly one persona
  template, or should later compositions ever be allowed?
- How much channel metadata belongs in RFC-0003 versus RFC-0002?
- Should group roles become more formally typed in a later revision?
- Should collaborator ever become a first-class stored entity, or remain a
  semantic layer over workspace persona instances?
- How should organization-scoped memory behave in smaller self-hosted
  deployments that effectively have one operator?

---

## 21. Self-Review

- Does this model prevent persona identity drift?
  Yes.

- Does it support multi-workspace operator environments?
  Yes.

- Does it preserve explicit memory ownership boundaries?
  Yes.

- Does it defer activation semantics appropriately to RFC-0001?
  Yes.

- Does it defer runtime participation and post/thread modeling appropriately to
  RFC-0002?
  Yes.

- Does it avoid becoming a second copy of the runtime data-model RFC?
  Yes.

---

## 22. Decision Log

- 2026-03-08 - Initial draft created
- 2026-03-17 - Reframed RFC around Orbit as the platform and PersonaKit as the
  authored-contract engine
- 2026-03-17 - Adopted the three-layer identity model: persona template,
  workspace persona instance, collaborator
- 2026-03-17 - Made RFC-0003 the semantic owner of workspace, group, and
  workspace persona instance structure while deferring activation, runtime
  participation, and memory lifecycle details to companion RFCs
