# Schema And Event Model Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `studio-integration-coordinator`
Review Ring: `architectural-editor`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Freeze the minimum phase-1 runtime mapping and initial realtime event shape so
Packet 2 persistence and Packet 3 realtime work do not invent their own model.

## Minimum Runtime Mapping From `M2` To `M3`

| `M2` local concept | `M3` canonical record(s) | Note |
| --- | --- | --- |
| local Orbit workspace | `workspace` | stable server-owned workspace root |
| one visible room surface | `channel` + `post` + `thread` | the room stops being one client-local blob |
| AI collaborator roster | `workspace_persona` | server-owned runtime identity anchor |
| human operator participation | `post_participant` / `message.author_type = user` | keep human participation explicit without forcing it into `workspace_persona` |
| room utterances | `message` | durable authored contributions inside one thread |
| system room events | `post_event` plus system-authored `message` where visible text is needed | preserve both runtime trace and room readability |
| direct and meeting participation | `post_participant` | explicit roster and participation mode |
| activation attribution | `persona_activation` | preserve response-mode and addressed-target semantics |
| response execution linkage | `agent_run` | do not hide execution behind message persistence alone |

## Phase-1 Posture

For the first server-backed Orbit slice:

- every user-visible room should be represented by a `post` that owns one primary
  `thread`
- the current `M2` room should migrate as a message-post-backed room, not as a
  flat conversation log
- direct address and lightweight meeting should remain post/thread behavior,
  not special client-only side channels

## Initial Realtime Event Categories

Minimum event categories for Packet 3 should include:

- `post.created`
- `message.created`
- `thread.activity.updated`
- `participant.joined`
- `participant.failed`
- `activation.resolved`
- `activation.failed`

These should be projections of durable transitions only.

## Deterministic Proof Added

- `Sources/Features/OrbitServerRuntime/Phase1RuntimeSchema.swift`
  freezes the ordered phase-1 table set and initial event categories in code
- `Tests/Features/OrbitServer/Phase1RuntimeSchemaTests.swift`
  verifies the minimum canonical table set, excludes authored-truth tables, and
  locks the initial event categories

## Replay Rule

Snapshot plus replay must reconstruct:

- current post/thread content
- participant roster state
- visible system events
- activation-linked room semantics

If one of those depends on event-only truth, the model is wrong.

## Packet 1 Judgment

Packet 1 is strong enough to proceed because the minimum record mapping and the
initial event categories are now explicit enough that persistence and realtime
implementation no longer need to improvise their first schema or event shape.
