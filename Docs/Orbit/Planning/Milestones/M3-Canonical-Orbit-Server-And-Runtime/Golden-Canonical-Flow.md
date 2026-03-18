# Golden Canonical Flow

Status: Draft
Milestone: `M3`
Owners: `studio-integration-coordinator`, `senior-swiftui-engineer`, `studio-reliability-engineer`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Provide one deterministic end-to-end example of correct `M3` behavior.

This example should be strong enough to prove that Orbit Server now owns runtime
truth without weakening the room semantics already proven in `M2`.

## Scenario

Context:

- the macOS command center opens the Orbit workspace using server-backed data
- AJ sees the same workspace, roster, and active thread model established in
  `M2`
- AJ sends a message addressed to Samwise in the active discussion
- the server persists the runtime state and projects it back to the client
- the client later reconnects and converges on the same state by snapshot plus
  replay

## Expected Flow

### Step 1. Snapshot Bootstrap

- the macOS client loads an Orbit workspace snapshot from Orbit Server
- the snapshot includes the current post, thread, roster, and message state
- the room still reads as Orbit, not as a generic remote feed

### Step 2. Message Submission

- AJ submits a message from the macOS client
- the message is sent through server write paths, not finalized locally
- the server persists the message under the canonical post/thread model

### Step 3. Activation And Response Linkage

- the server records the activation linkage for the collaborator response path
- the response and runtime trace remain attributable to the same room context
- the client sees participant response state that still matches `M1` and `M2`
  expectations

### Step 4. Realtime Projection

- the server emits durable-state-backed events for the transition
- the macOS client reflects those updates without becoming a second truth source
- the event stream does not contain irreplaceable truth that the database lacks

### Step 5. Reconnect And Replay

- the client disconnects or becomes stale
- on reconnect, the client recovers by snapshot and replay
- the resulting room state matches canonical server truth deterministically

## Expected Durable Records

The exact implementation may vary, but the flow should durably account for:

- workspace
- channel
- workspace persona instance
- post
- thread
- message
- post participant linkage where relevant
- post event records for meaningful transitions
- persona activation linkage
- agent run linkage when execution occurs

## Expected Operator-Visible Result

The operator should be able to tell all of the following from the macOS surface:

- the room is still Orbit
- the discussion is current and attributable
- the response happened under a visible collaboration context
- reconnect does not leave the room in a contradictory state

## Why This Example Matters

This example proves all of the following in one small slice:

- Orbit Server owns runtime truth
- the macOS client still presents a believable room
- realtime behavior reflects persisted state
- replay and reconnect are part of the product contract, not an afterthought

## Disqualifying Deviations

This example fails if:

- the client can finalize truth without the server
- reconnect requires local guesswork
- product semantics weaken during migration
- the event stream contains transitions that durable records cannot reconstruct
