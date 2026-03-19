# M2 Single-Workspace macOS Command-Center Proving Loop

Status: Accepted
Primary Owner: `senior-swiftui-engineer`
Supporting Personas: `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Prove the core Orbit room experience in one workspace before broadening the
platform.

## Quality Standard

`M2` is not successful because an Orbit panel exists.

`M2` is successful only when the local macOS experience feels intentionally like
Orbit, persists correctly, exposes lightweight explainability, and closes with
evidence strong enough to justify the next milestone.

The bare minimum is not a milestone win.
If the result still reads like generic persona chat with extra labels, `M2` has
not been reached.

Accepted here means this dossier is the approved planning baseline for `M2`.
The milestone still closes only when its exit criteria and review gate are
satisfied.

## File Map

- `README.md`
  milestone overview, packet order, and top-level guardrails
- `Quality-Bar.md`
  definition of impressive `M2` quality and disqualifying shortcuts
- `Command-Center-Experience-Bar.md`
  bespoke product and interaction quality bar for what must make the app feel
  like Orbit instead of chat
- `Command-Center-Shell-Reproof-Note.md`
  Packet 2 proof that first-open workspace, roster, discussion, and composer
  shell still read as Orbit
- `Addressing-And-Lightweight-Exchange-Reproof-Note.md`
  Packet 4 proof that direct address and lightweight exchange remain visible,
  narrow, and reviewable
- `Activation-Trace-Visibility-Reproof-Note.md`
  Packet 5 proof that trace inspection is discoverable from the room surface and
  still lightweight enough for the checkpoint
- `Durable-Conversation-Reproof-Note.md`
  Packet 3 proof that the room survives reload with visible attribution in
  seeded, empty, direct-address, and lightweight meeting conditions
- `Runtime-Slice-Reverification-Note.md`
  Packet 1 proof that the local runtime shape, persistence path, and default
  workspace data still fit the accepted checkpoint
- `Rerun-Execution-Contract.md`
  packet order, required participants, artifact outputs, and stop conditions for
  a serious `M2` attempt
- `Golden-Checkpoint-Walkthrough.md`
  deterministic product walkthrough of a convincing first-checkpoint Orbit run
- `Validation-And-Review-Matrix.md`
  feature, product, interaction, and evidence review matrix
- `Review-Packet.md`
  compact AJ review packet covering the current `M2` proof set and closeout
  artifacts
- `Evidence-And-Exit-Criteria.md`
  milestone-close rules and proof requirements

## Preconditions

- `M1` is accepted as the identity and activation baseline for this milestone
- the first-checkpoint runtime model is accepted as the local boundary
- the implementation breakdown is aligned with the current rerun contract
- the founding roster keeps the frozen `ProdDoc` -> `venture-product-steward`
  alias explicit

## Scope Freeze

In scope:

- one visible Orbit workspace in the macOS Studio app
- founding roster visibility
- durable thread and message persistence across restart
- direct participant addressing
- lightweight multi-participant exchange
- lightweight activation trace visibility

Out of scope:

- summary generation
- memory candidate review
- memory reuse
- multi-client sync
- deep team and squad modeling
- heavy meeting orchestration UI

## Required Inputs

- `Docs/Orbit/Planning/Orbit-macOS-Command-Center.md`
- `Docs/Orbit/Planning/Orbit-Proving-Loop.md`
- `Docs/Orbit/Planning/Orbit-Execution-Plan.md`
- `Docs/Orbit/Planning/Orbit-First-Checkpoint-Runtime-Model.md`
- `Docs/Orbit/Planning/Orbit-First-Checkpoint-Implementation-Breakdown.md`
- `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Tech-Stack-Posture.md`
- existing Orbit Studio files under `Sources/Features/Studio/UI/Orbit/`

## Implementation Posture

- start from the current macOS app surfaces, but do not treat them as protected
  end-state structure
- use `Swift` and `SwiftUI` for the proving-loop client surface
- use the `senior-swiftui-engineer` persona with the `repo-constraints`,
  `swift-style`, and `swiftui-style` kits when building or reviewing the room
- treat snapshot testing as part of the visual and product-proof toolset,
  including `pointfreeco/swift-snapshot-testing` where it materially improves
  reviewability
- AI lanes in `M2` should strengthen the approved room concept, not reinterpret
  the client stack or product form
- in a dedicated non-main worktree, AI lanes may refactor, replace, or remove
  current PersonaKit macOS app surfaces if that materially improves the Orbit
  room and remains justified by the active milestone
- do not reopen server-stack, deployment, or backend framework decisions while
  proving the local command-center checkpoint

## Execution Packets

### Packet 1. Re-Verify The First-Checkpoint Runtime Slice

Outcome:

- the local runtime and persistence boundary are still minimal and correct

Work:

- re-check Orbit models against the current runtime-model note
- re-check persistence path under `.personakit/Orbit/`
- confirm that existing sample data and defaults still match the checkpoint

Done when:

- the first coding packet can proceed without revisiting entity shape

### Packet 2. Re-Prove The Command-Center Shell

Outcome:

- Orbit is visibly present as a distinct workspace surface inside Studio

Work:

- re-check sidebar integration
- re-check workspace header and roster presentation
- re-check the active thread surface against the command-center doc

Done when:

- AJ can open the app and immediately see Orbit as a room, not generic chat

### Packet 3. Re-Prove Durable Conversation

Outcome:

- the conversation loop is visibly durable and attributable

Work:

- verify message creation and loading
- verify speaker attribution
- verify restart durability
- verify seeded and empty states

Done when:

- a short discussion survives restart without losing speaker identity

### Packet 4. Re-Prove Participant Addressing And Lightweight Exchange

Outcome:

- multi-participant behavior feels intentional instead of accidental

Work:

- verify direct participant addressing
- verify minimal multi-participant exchange path
- verify participant response bridging stays narrow and inspectable

Done when:

- one short exchange can happen without hidden-routing confusion

### Packet 5. Re-Prove Activation Trace Visibility

Outcome:

- the command-center surface exposes enough trace context to feel like Orbit

Work:

- verify participant, directive, and memory-influenced presentation
- verify trace state maps to persisted activation records
- verify the trace affordance is discoverable but not visually heavy

Done when:

- the product reviewer and interaction reviewer agree the checkpoint no longer
  feels like plain persona chat

### Packet 6. Close The Checkpoint Properly

Outcome:

- the first checkpoint closes with evidence instead of optimism

Work:

- run the product acceptance checklist
- record interaction-quality review
- record validation and confidence split
- run retrospective closeout

Done when:

- the branch can honestly be described as a proved local command-center loop

## Subagent Use Pattern

Safe subagents:

- UI-shell implementation review
- persistence and fixture review
- snapshot and restart validation
- product acceptance review
- interaction-quality review

Avoid:

- parallel edits to the same Orbit UI and persistence files
- broadening into M3 server work before checkpoint closeout

## Evidence Package

- runtime slice re-verification note
- command-center shell re-proof note
- durable conversation re-proof note
- addressing and lightweight exchange re-proof note
- activation trace visibility re-proof note
- deterministic persistence checks
- restart verification notes
- snapshot coverage
- product acceptance result
- interaction-quality review artifact
- validation closeout artifact
- retrospective closeout artifact
- review packet

## Stop Points

- stop before summary or memory features
- stop before server architecture work
- stop if the response bridge starts growing into a hidden execution engine

## Exit And Handoff

Exit when the local Orbit room is believable, attributable, and reviewed.

Handoff forward to:

- `M3` with a stable local baseline to migrate
- `M4` and `M5` only after `M3` decides how canonical runtime truth will work
