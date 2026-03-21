# M4 Packet 4: Participation Roles And Completion Semantics

Status: Ready For Planning Closeout
Packet Id: `M4-P4`
Milestone: `M4`
Execution Owner: `orbit-meeting-coordinator`
Review Personas: `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-20

## Header

- status: `needs-review`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Define the smallest participation-role and completion-state model that makes a
  group exchange understandable.
- This packet exists now because the operator needs visible state, not just more
  replies.
- This is the right slice size because role and state semantics can be sharpened
  separately from target expansion and inline reply behavior.

## Quality Bar

- participant roles are visible enough to understand what Orbit expects
- completion state distinguishes active, complete, partial, and failed paths
- partial-failure behavior remains explicit instead of hidden in aggregate success

## Preconditions

- `M4-P1`, `M4-P2`, and `M4-P3` are coherent enough to describe who participates
  and how replies stay inline
- `orbit-meeting-coordinator` is approved and available through `PHR-0009`
- the M4/M5 boundary is still explicit

## Grounding Requirements

- `.personakit/Sessions/orbit-meeting-coordinator-review.session.json`
- `Packet-03-Inline-Group-Reply-Flow.md`
- `Decision-Register.md`
- `Validation-And-Review-Matrix.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- live grounding required: `yes`

## Exact Scope

Include:

- role vocabulary for the first collaboration slice
- visible completion states for group exchange
- partial-failure behavior expectations

Exclude:

- meeting-only governance roles
- advanced deliberation or moderation policies
- workstream execution state

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/`
- may create: role tables, state examples, and partial-failure notes inside the
  `M4` dossier
- must not edit: `M5`, `M7`, or runtime implementation paths in this packet

## Ordered Work

1. Define the minimum role vocabulary needed for the first `M4` slice.
2. Define visible completion states and the partial-failure path.
3. Return examples that make the trust review in `M4-P5` concrete.

## Validation And Evidence

- one role table for the first slice
- one complete-path example and one partial-failure example
- validation questions aligned with the `M4` review matrix

## Packet 4 Proposed Closure

### First-Slice Role Vocabulary

| Role | Meaning | Expected visible behavior |
| --- | --- | --- |
| `contributor` | A selected participant expected to provide a direct substantive reply in the active thread. | The participant should produce an attributed inline reply unless the run fails. |
| `reviewer` | A selected participant expected to evaluate, refine, or challenge the active thread objective or the emerging group exchange. | The participant should produce an attributed inline reply that reads as review-oriented feedback, regardless of whether it arrives before or after other replies. |

- the first slice keeps the role model intentionally small: `contributor` and
  `reviewer` are enough to explain expected participation without importing full
  meeting governance
- `observer`, `summarizer`, and `facilitator` remain valid RFC concepts, but
  they are deferred from `M4` until Orbit can surface them without turning the
  inline path into implicit meeting management
- role vocabulary is operator-visible expectation, not a substitute for
  low-level runtime fields such as `post_participant.participationMode`
- `reviewer` names the expected function of the reply, not a guaranteed turn
  order or sequencing rule

### Participant And Exchange State Vocabulary

- participant-level visible states for the first slice:
  `pending`, `replied`, `failed`
- exchange-level visible states for the first slice:
  `active`, `completed`, `partial`, `failed`
- Packet 2 expansion outcomes such as `blocked` and `empty` remain pre-exchange
  routing results; they do not become in-exchange completion states here

### State Meanings

- `pending`
  the participant was selected and is still expected to reply, but no visible
  inline reply has arrived yet
- `replied`
  the participant produced a visible attributed inline reply in the current
  thread
- `failed`
  the participant was selected but could not produce a visible reply, and that
  failure remains visible to the operator
- `active`
  the exchange is underway because at least one reply-expected participant is
  still `pending`
- `completed`
  all reply-expected participants reached `replied`, with no visible participant
  failures
- `partial`
  at least one reply-expected participant reached `replied` and at least one
  reply-expected participant reached `failed`
- `failed`
  the exchange began, but no reply-expected participant produced a visible reply
  before the interaction terminated

### Partial-Failure Behavior

- partial failure must preserve both truths at once:
  some participants replied successfully, and some did not
- the operator should not have to infer failure from a missing voice
- a partial exchange may still be useful and may still close as `partial`
  without being mislabeled `completed`
- later packets may add richer coordinator explanation, but the first slice only
  needs visibly separate participant states plus one honest exchange state

### Packet 4 Examples

- complete-path example:
  `Founding Group` expands inline, `samwise` is shown as `contributor`,
  `proddoc` is shown as `reviewer`, both post attributed inline replies, and
  the exchange closes as `completed`
- partial-failure example:
  `samwise` replies successfully as `contributor`, `proddoc` remains selected as
  `reviewer` but fails visibly before replying, and the exchange closes as
  `partial` rather than silently `completed`
- failed-path example:
  the target expands successfully, but every reply-expected participant reaches
  `failed`; the interaction closes as `failed` without pretending that expansion
  alone was sufficient

### Validation Questions Returned To `M4-P5`

- can a reviewer tell what Orbit expected from each selected participant without
  guessing from message tone alone?
- can a reviewer distinguish `partial` from `completed` without reading hidden
  logs or debugger output?
- does the state model remain legible when replies arrive in normal arrival
  order rather than a fixed sequence?

### Open Risks And Review Decisions Needed

- AJ still needs to approve whether `reviewer` is necessary in the first slice
  or whether the initial runtime should collapse everything to `contributor`
- `M4-P5` must test whether the first-slice state model is visible enough
  without a dedicated meeting roster or secondary status surface
- later packets may add deferred roles only if the product can explain them
  without reopening the `M4` versus `M5` boundary

## Failure Dispositions

- `blocked`
  earlier packet contracts are still too vague to define visible state honestly
- `needs-review`
  AJ needs to approve the role and state vocabulary before runtime work begins
- `grounding-blocked`
  required coordinator grounding is unavailable
- `failed`
  the packet cannot make state legible without importing later milestone behavior

## Stop Points

- stop if the role model starts importing full meeting governance
- stop if completion state cannot show partial failure clearly

## Closeout Return Format

- role and state contract defined
- examples and evidence produced
- open risks
- review decisions needed
- next recommended packet: `M4-P5`
