# Canonical Runtime Boundary Audit Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `architectural-editor`
Review Ring: `studio-integration-coordinator`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Freeze the Packet 1 ownership boundary by comparing the accepted canonical
runtime contract to the current local Orbit implementation.

## Current `M2` Runtime Reality

The accepted `M2` checkpoint still keeps canonical room truth inside the macOS
client and a workspace-local file:

- `OrbitWorkspace`
- `OrbitConversationThread`
- `OrbitMessage`
- `OrbitActivationRecord`
- `OrbitActivationContractSnapshot`
- `OrbitActivationFailureRecord`
- `.personakit/Orbit/orbit-workspace.json`

That local shape is acceptable for `M2`, but it is exactly what `M3` must stop
treating as long-term canonical truth.

## Canonical Ownership Split

### PersonaKit-authored truth stays outside Orbit Server ownership

- persona templates
- directives
- kits
- skill authorization
- stop-point and review-gate posture
- authored operating constraints

Orbit Server may link or snapshot resolved contract truth for traceability, but
it must not become a second contract-authoring system.

### Orbit Server must own runtime truth for the `M3` slice

- `workspace`
- `channel`
- `workspace_persona`
- `post`
- `thread`
- `message`
- `post_participant`
- `post_event`
- `post_link`
- `persona_activation`
- `agent_run`

### The macOS client may own only non-canonical local state

- selection and navigation state
- composition drafts
- disclosure and inspection state
- cache and bootstrap snapshot state
- queued intent only when explicitly modeled as non-canonical

The client must not keep behaving as the durable owner of room truth after cutover.

## Current-Model To `M3` Mapping

| Current local concept | `M3` canonical target | Boundary decision |
| --- | --- | --- |
| `OrbitWorkspace` | `workspace` plus channel-scoped runtime | server-owned after cutover |
| local founding roster | `workspace_persona` for AI collaborators; human operator remains runtime participant, not forced into `workspace_persona` | server-owned runtime roster |
| one active room thread | `post` + `thread` | server-owned durable conversation anchor |
| user/system/collaborator room entries | `message` and `post_event` | server-owned durable runtime records |
| direct or meeting participant list | `post_participant` | server-owned explicit roster |
| response attribution | `persona_activation` + contract linkage | server-owned runtime linkage to PersonaKit-authored truth |
| provider/run execution placeholder | `agent_run` | server-owned execution record |

## Hard Migration Constraints

- do not keep `.personakit/Orbit/orbit-workspace.json` as long-term canonical
  truth once cutover is complete
- do not introduce long-lived dual-write or local-authoritative fallback
- preserve `M1` and `M2` trace meaning during migration
- keep AJ as a runtime participant where needed, but do not force the human
  operator into `workspace_persona`

## Packet 1 Judgment

Packet 1 is strong enough to proceed because the ownership split is now explicit:
the current client-local runtime shows exactly what must move to server truth,
what must remain PersonaKit-authored, and what may stay client-local after
cutover.
