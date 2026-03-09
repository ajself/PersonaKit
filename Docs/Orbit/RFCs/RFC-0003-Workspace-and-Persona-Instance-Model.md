# RFC-0003: Workspace and Persona Instance Model (Orbit Platform)

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
- RFC-0001 Persona Activation and Default Directive Model  
- RFC-0002 Conversation and Memory Data Model  
- Docs/RFCs/README.md  

---

# 1. Summary

This RFC proposes the **workspace and persona instance model** for the Orbit platform.

PersonaKit is evolving into a **workspace-centric command center for AI teams**, where a single human coordinates multiple ventures, research streams, and internal initiatives.

The workspace model defines:

- how personas exist across multiple projects
- how squads and teams are organized
- how conversations are partitioned
- how memory scopes are enforced
- how persona instances grow expertise without contaminating other workspaces

This RFC introduces a **two-layer persona identity model**:

1. Persona Templates (global archetypes)
2. Workspace Personas (local instances)

This separation allows personas to remain reusable while accumulating workspace-specific experience.

---

# 2. Motivation

Orbit’s long-term direction is to support an **incubator-style workflow**:

- multiple ventures
- multiple research tracks
- multiple AI teams
- shared institutional learning

In this model, a single persona template may appear in many contexts.

Example:

``` id="js1491"
Persona Template
  Senior SwiftUI Engineer

Workspace Instances
  Bar / Senior SwiftUI Engineer
  Baz / Senior SwiftUI Engineer
  InternalTools / Senior SwiftUI Engineer
```

Without a clear separation between template and instance:

- persona memory contaminates unrelated projects
- team composition becomes ambiguous
- activation resolution becomes unsafe
- long-term expertise becomes difficult to manage

This RFC defines the model needed to support PersonaKit’s incubator vision.

---

# 3. Problem Statement

Orbit must answer the following questions deterministically:

- Which personas exist in a given workspace?
- How do personas accumulate workspace-specific experience?
- How can personas share global expertise without contaminating projects?
- How are squads and teams defined?
- How does activation resolve a persona instance?
- How are conversations scoped to a workspace?

Without a formal model for these questions, PersonaKit risks:

- identity ambiguity
- memory leakage across projects
- fragile activation logic
- inconsistent collaboration semantics

---

# 4. Goals

This RFC aims to establish a model that:

- supports multiple workspaces under a single user
- clearly separates **persona templates** (global role definitions) from **workspace personas** (local instances)
- allows persona templates to be reused safely across workspaces
- isolates workspace-specific persona memory and experience
- enables teams and squads to organize collaboration within a workspace
- provides deterministic resolution for persona activation
- prevents memory contamination across projects
- supports controlled cross-workspace learning through explicit promotion
- preserves explainability for how a persona behaves within a workspace
- scales cleanly to incubator-style environments where one user operates many ventures

---

# 5. Non-Goals

This RFC does not define:

- the UI for workspace management
- the exact API surface for workspace creation
- authentication and multi-user models
- workspace billing or tenancy structures

Those may appear in later RFCs.

---

# 6. Proposal

PersonaKit introduces **three structural layers**:

```text
User
  ↓
Workspaces
  ↓
Teams / Squads
  ↓
Workspace Personas
  ↓
Persona Templates
```

Explanation:

- **User** is the human operator at the center of the system.
- **Workspaces** represent ventures, projects, or research environments.
- **Teams and Squads** organize collaboration within a workspace.
- **Workspace Personas** are the operational participants in meetings and conversations.
- **Persona Templates** define the reusable global role definitions that workspace personas are derived from.

This hierarchy ensures that identity, collaboration structure, and memory scope remain predictable and traceable.

---

# 7. Workspace Model

A workspace represents a **venture, project, or research track**.

Examples:

``` id="s6ldav"
Workspaces
  PersonaKit
  Bar
  Baz
  AI Product Lab
```

Workspaces act as boundaries for:

- conversations
- teams and squads
- workspace persona instances
- workspace memory
- meeting histories

A workspace must exist before any conversation or meeting begins.

---

# 8. Persona Templates

Persona templates are global definitions that represent **roles**.

Examples:

``` id="cobuda"
Product Designer
Senior SwiftUI Engineer
Product Manager
Research Lead
```

Templates define:

- role description
- values
- blind spots
- default kits
- default directive
- allowed skills
- forbidden skills

Templates are human authored and version controlled.

Templates **do not contain memory**.

---

# 9. Workspace Personas

A workspace persona represents a persona template **inside a specific workspace**.

Example:

``` id="asxurc"
Workspace: Bar
Persona Template: Product Designer
Instance: bar-product-designer
```

Workspace personas accumulate:

- conversation history
- journal entries
- workspace memory
- meeting participation
- local expertise

This allows personas to evolve differently across workspaces.

---

# 10. Teams and Squads

Workspaces support two grouping mechanisms.

## Teams

Durable organizational groups.

Examples:

``` id="4yloj4"
Bar Product Team
Bar Engineering Team
Architecture Council
```

Teams represent long-lived collaboration structures.

---

## Squads

Focused working groups for specific initiatives.

Examples:

``` id="jla9zq"
Onboarding Squad
Memory System Squad
Design Review Squad
```

Squads may be temporary and may overlap.

---

# 11. Persona Membership

Workspace personas may belong to:

- teams
- squads
- ad-hoc meetings

Membership determines who participates in coordinated conversations.

Example:

``` id="07vdil"
Bar Product Squad
  Product Manager
  Product Designer
  Senior SwiftUI Engineer
```

The Meeting Coordinator expands squad membership during activation.

---

# 12. Activation Context

Persona activation requires:

``` id="gr8ta2"
workspace
persona instance
directive
memory
conversation context
```

Activation must always resolve to a **workspace persona instance**, not a template.

This ensures memory retrieval is scoped correctly.

---

# 13. Memory Scope

Workspace architecture introduces multiple memory scopes.

``` id="pldzip"
Workspace Memory
Workspace Persona Memory
Persona Global Memory
Organization Memory
```

Memory retrieval prioritizes:

1 workspace memory  
2 workspace persona journals  
3 persona global memory  
4 linked memories from other workspaces  
5 organization memory  

This preserves local context before global patterns.

---

# 14. Cross-Workspace Learning

Persona templates may accumulate **global memory profiles** derived from workspace experience.

Example:

``` id="13dr9z"
Product Designer learns
  AJ prefers iterative design exploration
  AJ dislikes modal onboarding flows
```

Promotion to global persona memory requires human approval.

---

# 15. Edge Cases

### Persona template deleted
Workspace persona instances should retain historical identity for attribution.

### Workspace archived
All workspace memory and conversations become read-only.

### Persona removed from workspace
Existing conversation attribution remains intact.

### Persona renamed
Historical records should reference stable identifiers, not mutable display names.

---

# 16. Risks and Tradeoffs

## Risk: Increased conceptual complexity

Introducing workspace personas adds another entity layer.

Tradeoff:  
This complexity reflects real collaboration patterns and enables safe memory growth.

---

## Risk: Memory duplication across workspaces

Tradeoff:  
Explicit promotion pipelines allow meaningful insights to move into global memory profiles.

---

## Risk: Over-engineering early

Tradeoff:  
Defining the structure early prevents schema drift and fragile identity semantics later.

---

# 17. Recommendation

Adopt the **persona template + workspace instance model** as the core identity architecture for Orbit.

This model:

- supports incubator-scale collaboration
- prevents memory contamination
- enables persona growth
- keeps activation deterministic
- supports squads and teams

This structure should anchor future RFCs.

---

# 18. Rollout Plan

### Phase 1

Introduce:

- workspace
- workspace persona
- teams
- squads

### Phase 2

Integrate with:

- conversation model
- meeting coordinator

### Phase 3

Integrate with:

- journaling
- memory candidate system

### Phase 4

Introduce:

- persona global memory profiles
- cross-workspace learning

---

# 19. Self-Review

Questions evaluated for this RFC:

- Does the model prevent persona identity drift?  
- Does it support incubator-scale workspaces?  
- Does it preserve explicit memory boundaries?  
- Does it remain compatible with the activation pipeline?  
- Does it maintain explainability?

Current assessment: yes.

---

# 20. Decision Log

- 2026-03-08 — Initial draft created