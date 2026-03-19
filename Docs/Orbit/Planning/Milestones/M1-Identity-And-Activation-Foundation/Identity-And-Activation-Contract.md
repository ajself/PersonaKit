# Identity And Activation Contract

Status: Accepted
Milestone: `M1`
Primary Owner: `architectural-editor`
Last Updated: 2026-03-18

## Purpose

Define the first-checkpoint contract for collaborator identity, activation
sequencing, and attribution boundaries.

This is the contract `M2` should build on.
If this contract is weak, the command-center UI may still look plausible while
its identity and explainability model remains untrustworthy.

## Design Laws

### 1. PersonaKit Owns Authored Truth

PersonaKit remains the authority for:

- persona template identity
- directive identity
- kit selection and authorization
- skill authorization
- stop-point posture

Orbit may resolve and snapshot this truth for a runtime activation, but Orbit may
not redefine it casually.

### 2. Orbit Owns Runtime Collaboration State

Orbit remains the authority for:

- workspace state
- participant records
- thread and message state
- activation events
- visibility and inspection surfaces for collaboration activity

### 3. One Visible AI Collaborator Requires One Stable Identity Anchor

If an AI-backed participant is visible in the workspace, the participant must
map to one stable identity anchor for the current checkpoint.

That anchor may be:

- a formal PersonaKit persona-template id
- an approved product-facing alias with explicit mapping to a PersonaKit persona
  template

It may not be:

- an informal label with no stable mapping
- a hidden role swap behind one participant name

### 4. Activation Trace Is Product Data, Not Debug Metadata

The activation trace is part of Orbit's product difference.

It must not be treated as optional debug information that can disappear when the
system is under pressure.

### 5. Ambiguity Fails Closed

If collaborator identity, contract resolution, authorization, or persistence is
not trustworthy enough to attribute the response, the system should stop or
surface the problem instead of fabricating a smooth answer.

## First-Checkpoint Identity Model

### Workspace

- one local workspace: `Orbit`
- one founding roster for the checkpoint: AJ, Samwise, ProdDoc
- `ProdDoc` is the approved product-facing alias for `venture-product-steward`

### Participants

Checkpoint participant classes:

- human participant
  example: AJ
- AI-backed collaborator
  examples: Samwise, ProdDoc as the approved product-facing alias for
    `venture-product-steward`

Required participant fields:

- stable participant id
- display name
- participant class
- workspace persona id when AI-backed
- linked persona template id when AI-backed
- availability or active-state hint

### Workspace Persona Instance

For the first checkpoint, each visible AI-backed collaborator should be treated
as a workspace-scoped identity, not as a one-off prompt label.

Minimum expectations:

- stable collaborator identity within the workspace
- stable mapping to a PersonaKit persona or approved alias relationship
- visible attribution in messages and traces

## Ownership Matrix

| Concern | Owned by | Runtime expectation |
| --- | --- | --- |
| Persona template id | PersonaKit | resolved and snapshotted for activation |
| Directive id | PersonaKit | resolved and snapshotted for activation |
| Kit ids | PersonaKit | inspectable in the activation snapshot |
| Allowed skills | PersonaKit | inspectable in the activation snapshot |
| Stop-point posture | PersonaKit | inspectable in the activation snapshot or derived review state |
| Workspace id | Orbit runtime | stable and durable |
| Participant id | Orbit runtime | stable and durable |
| Workspace persona id | Orbit runtime | stable and mapped to one visible AI-backed collaborator |
| Thread id | Orbit runtime | stable and durable |
| Message id | Orbit runtime | stable and ordered |
| Activation id | Orbit runtime | stable and linked to the response |
| Trigger source | Orbit runtime | persisted and inspectable |
| Memory-source linkage | Orbit runtime, based on resolved use | explicit even when the answer is "none" |

## Activation Sequence

### Step 1. Trigger Capture

Orbit captures the initiating event.

Required data:

- workspace id
- trigger source
- triggering message id when applicable
- target collaborator or general thread-reply intent

### Step 2. Target Resolution

Orbit resolves which participant or participants are eligible to respond.

Required checks:

- target exists in the workspace
- target identity is unambiguous
- target collaborator mapping is frozen for the checkpoint

If any of these fail, activation stops.

### Step 3. Contract Resolution

Orbit resolves the PersonaKit contract for the targeted collaborator.

Required outputs:

- persona template id
- directive id
- kit ids if applicable
- allowed skill posture
- stop-point posture

If any required contract element is unresolved, activation stops.

### Step 4. Authorization Check

Orbit verifies that the response path is permitted under the resolved contract.

Checks include:

- allowed skill posture remains valid
- no disallowed skill or behavior is required to continue
- no review stop blocks the action

If authorization fails, activation stops.

### Step 5. Activation Record Creation

Before the response is treated as complete, Orbit writes durable activation
state.

Minimum data:

- activation id
- workspace id
- response message id
- participant id
- workspace persona id
- persona template id
- directive id
- trigger source
- trigger message id when applicable
- memory-influenced flag

Required inspectable snapshot data for `M1`:

- stable contract snapshot id or linked snapshot reference
- kit ids or a linked snapshot that contains them
- allowed skill posture or a linked snapshot that contains it
- stop-point posture or a linked snapshot that contains it
- review-gate posture or a linked snapshot that contains it
- memory-scope posture or a linked snapshot that contains it
- explicit memory-source reference set, even if empty

If the response path requires skills outside the authorized skill posture, the
activation must fail closed before publication and leave explicit blocked-state
evidence.

### Step 6. Response Publication

Orbit renders or streams the response only when the activation can still be
attributed and inspected.

If durable trace state cannot be written, the response should not be presented as
a completed, attributable collaborator answer.

### Step 7. Trace Inspection

The operator must be able to inspect:

- responding participant
- workspace persona identity
- persona template identity
- directive identity
- memory-influenced posture
- enough contract context to explain why the response was allowed

## Fail-Closed Rules

The system must stop or surface a blocked state when any of these are true:

- no active workspace can be resolved
- the targeted collaborator is missing or ambiguous
- the collaborator-to-persona mapping is unresolved
- the directive cannot be resolved
- the required authorization posture is not valid
- durable activation state cannot be written

For the local first checkpoint, a blocked activation should persist a durable
activation-failure record and surface an explicit blocked system event instead of
publishing a collaborator response.

For persistence failure specifically, the first checkpoint should fail before the
new turn is committed into the durable workspace state at all.

## Disallowed Shortcuts

Do not:

- let one participant label map to different personas without explicit review
- publish unattributed collaborator output and fill in trace metadata later
- collapse missing contract data into generic system messaging that looks like a
  real collaborator response
- treat memory influence as unknowable when the true answer is "none used"

## Quality Rule

This contract is only good enough for `M1` if it helps reviewers detect
mistakes, not just implementers explain intent.
