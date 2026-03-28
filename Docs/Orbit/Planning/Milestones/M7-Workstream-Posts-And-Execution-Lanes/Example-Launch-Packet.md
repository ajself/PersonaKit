# M7 Example Launch Packet

Status: Ready For Review
Milestone: `M7`
Prepared For: `venture-product-steward`, `studio-integration-coordinator`, `studio-coverage-architect`, `AJ`
Prepared By: `samwise`
Last Updated: 2026-03-27

## Purpose

Provide one approved launch example and one blocked pre-launch example so `M7`
closeout review can judge lane authority, source continuity, and visible
non-launch behavior from concrete dossier-local evidence rather than packet
prose alone.

## Example A: Approved Launch From A Message Post

### Source Context

- source post id: `message-post-201`
- source post type: `message`
- source thread: `thread-room-alpha`
- handoff reason:
  the source discussion has converged on a bounded implementation follow-up that
  now needs an explicit execution lane

### Objective Boundary

- packet id: `launch-packet-alpha`
- goal:
  implement the accepted Orbit workstream post shell for one bounded
  implementation slice
- in scope:
  bounded execution-lane work for the accepted `M7` first slice
- out of scope:
  UI design expansion, schema invention, hidden execution helpers, and `M8`
  memory behavior

### Ownership And Grounding

- execution owner: `worktree-squad-lead`
- review personas:
  `samwise`, `venture-product-steward`, `studio-coverage-architect`
- grounding:
  local `personakit` CLI for `samwise` with directive `apply-style`
- approval posture:
  operator approval recorded before execution begins

### Execution Lane

- approved lane type:
  explicit non-`main` execution lane
- write scope:
  bounded workstream implementation scope only
- validation owner:
  `studio-coverage-architect`

### Acceptance And Verification

- acceptance criteria:
  preserve `M7-P1` through `M7-P4` contracts while making the bounded workstream
  slice inspectable
- required evidence:
  explicit launch visibility, explicit owner visibility, bounded progress
  return, explicit closeout

### Stop Points And Return Contract

- stop if owner authority broadens beyond `worktree-squad-lead`
- stop if execution would begin without explicit approval
- required returned signals:
  launch visibility, status changes, blocker truth, artifact availability,
  explicit closeout

### Expected Launch Outputs

- one linked `workstream` post:
  `workstream-post-301`
- one workstream thread:
  `thread-workstream-301`
- one initial `workstream_state` record with status:
  `draft`
- one `post_link`:
  `message-post-201` `follow_up` `workstream-post-301`
- explicit `post_participant` and `workstream_assignment` records showing one
  active owner and visible reviewers

## Example B: Blocked Pre-Launch From A Meeting Post

### Source Context

- source post id: `meeting-post-410`
- source post type: `meeting`
- source thread: `thread-meeting-410`
- handoff reason:
  the meeting produced a possible follow-up, but the execution lane is not yet
  approved

### Missing Gate

- missing requirement:
  explicit owner approval and write-scope approval for the proposed lane

### Correct Result

- no workstream post is created
- no speculative `pending` workstream appears
- the meeting post remains durable and visible
- the source context records:
  - handoff was proposed
  - launch is currently `blocked`
  - what approval is still missing

### Why This Example Matters

- it proves that `M7` does not treat discussion heat or meeting completion as
  launch authority
- it preserves `M5` continuity by keeping the source meeting inspectable even
  when the workstream does not launch
- it keeps non-launch visible without hidden coordinator reconstruction

## Review Focus

- Example A proves the floor for approved launch authority, ownership, and
  initial runtime visibility.
- Example B proves the floor for visible non-launch when required approval is
  missing.
- Together they show that first-slice `M7` handoff is explicit rather than
  ambient.
