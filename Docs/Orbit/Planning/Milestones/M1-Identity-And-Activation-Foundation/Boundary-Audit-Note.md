# Boundary Audit Note

Status: Draft
Milestone: `M1`
Owner: `architectural-editor`
Last Updated: 2026-03-18

## Purpose

Freeze the authored-truth versus runtime-truth boundary for the first
checkpoint so later `M1` packets and implementation work stop guessing.

## Inputs Audited

- `Docs/Orbit/RFCs/RFC-0001-Workspace-Persona-Contract-Resolution-and-Activation-Model.md`
- `Docs/Orbit/RFCs/RFC-0003-Workspace-Group-and-Workspace-Persona-Instance-Model.md`
- `Sources/Features/Studio/UI/Orbit/OrbitModels.swift`
- `Sources/Features/Studio/UI/Orbit/OrbitSampleData.swift`
- `Sources/Features/Studio/UI/Orbit/OrbitParticipantResponseBridge.swift`
- `Sources/Features/Studio/UI/Orbit/OrbitPanelView+Persistence.swift`
- `Sources/Features/Studio/UI/Orbit/OrbitPanelView+UI.swift`
- `Tests/Features/Studio/OrbitWorkspaceTests.swift`

## Boundary Rule

PersonaKit owns authored operating contract truth.

That includes:

- persona templates and persona-template ids
- directive ids and directive precedence
- kits and kit precedence
- skill authorization
- stop-point and review-gate posture

Orbit owns runtime collaboration truth.

That includes:

- workspace state and persistence
- product-facing collaborator records inside the workspace
- local workspace persona instance anchors used by the checkpoint runtime
- thread and message state
- activation records and operator-visible trace presentation

Orbit may persist resolved references to authored truth in runtime records.

Orbit must not mutate or redefine authored contract truth ad hoc.

## Current First-Checkpoint Mapping

| Concern | Owner | Current first-checkpoint representation | Audit note |
| --- | --- | --- | --- |
| workspace boundary | Orbit runtime | `OrbitWorkspace.id`, `displayName`, `purpose` | aligned with RFC-0003 workspace boundary |
| collaborator display label | Orbit runtime product surface | `OrbitParticipant.displayName` | aligned; collaborator remains product-facing, not a separate stored entity |
| workspace persona instance anchor | Orbit runtime | `OrbitParticipant.workspacePersonaID`, `OrbitActivationRecord.workspacePersonaID` | now explicit for the local slice, though still closely coupled to participant records |
| authored persona template reference | PersonaKit authored truth, persisted by Orbit | `OrbitParticipant.personaTemplateID`, `OrbitActivationRecord.personaTemplateID` | aligned as a resolved reference, not a runtime-owned template |
| authored directive reference | PersonaKit authored truth, persisted by Orbit | `OrbitParticipant.defaultDirectiveID`, `OrbitActivationRecord.directiveID` | aligned as a resolved reference, not a runtime-authored directive |
| conversation runtime | Orbit runtime | `OrbitConversationThread`, `OrbitMessage` | aligned with the local first-checkpoint scope |
| activation runtime trace | Orbit runtime | `OrbitActivationRecord`, `OrbitActivationContractSnapshot`, and `OrbitActivationFailureRecord` | improved; local trace now records success and blocked activation paths distinctly for the first checkpoint |
| memory influence posture | Orbit runtime, constrained by PersonaKit policy | `OrbitActivationRecord.memoryInfluenced`, `memorySourceRefs` | improved; explicit empty memory-source refs are now recordable |
| collaborator alias mapping | Orbit runtime presentation over PersonaKit identity | `ProdDoc` display name + `venture-product-steward` persona-template id | aligned with accepted `M0` decision |

## What Is Already Aligned

- Orbit keeps runtime state under `.personakit/Orbit/` and does not attempt to
  write authored PersonaKit definitions.
- The first-checkpoint runtime persists persona and directive references in
  activation records before treating participant responses as durable output.
- The accepted `ProdDoc` -> `venture-product-steward` alias is explicit in the
  local sample data rather than hidden behind a vague product label.
- The response bridge remains a feature-local seam in
  `OrbitParticipantResponseBridge.swift`, not a repo-wide execution engine.

## Low-Risk Alignment Applied In This Packet

- activation records now persist `workspaceID` explicitly instead of relying only
  on container context
- activation records now persist `workspacePersonaID` explicitly for AI-backed
  collaborators in the local first-checkpoint model
- activation records now persist `responseMode` explicitly
- activation records now support explicit `memorySourceRefs`, including the empty
  set for the no-memory case
- local runtime now persists a distinct activation contract snapshot with explicit
  empty sets for kits, authorized skills, stop points, review gates, and memory
  scopes in the no-memory local scaffold case
- local runtime now persists blocked activation attempts as explicit failure
  records instead of dropping identity-sensitive failures silently
- workspace-backed send flows now resolve live PersonaKit contract state before
  publication instead of relying only on local checkpoint defaults

These are safe to add now because they sharpen runtime attribution without
forcing final contract-resolution or server schema choices.

## Current Drift Still To Resolve In Later `M1` Packets

- sample/default scaffolds still use checkpoint defaults when no workspace-backed
  PersonaKit contract resolution is available
- the current response bridge is deterministic local scaffolding, not live
  PersonaKit contract resolution
- blocked activation records are now present, but the local scaffold still lacks
  richer degraded-state detail beyond the first explicit fail-closed reasons
- the first checkpoint still collapses channel and post context into one active
  workspace thread, which is acceptable for the local slice but not for later
  canonical runtime work
- the operator-visible trace UI is still a compact first-checkpoint surface, not
  the richer final inspection workflow expected later in Orbit

## Packet 1 Decision

For the local first checkpoint, the implementation may keep collaborator records,
workspace persona anchors, thread state, and activation records inside the Orbit
feature as long as all authored contract truth remains referenced rather than
re-authored.

Later `M1` packets should build on this note rather than reopening who owns what.
