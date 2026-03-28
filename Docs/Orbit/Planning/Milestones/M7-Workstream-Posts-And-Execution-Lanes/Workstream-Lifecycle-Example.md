# M7 Workstream Lifecycle Example

Status: Ready For Review
Milestone: `M7`
Prepared For: `venture-product-steward`, `studio-integration-coordinator`, `studio-coverage-architect`, `AJ`
Prepared By: `samwise`
Last Updated: 2026-03-27

## Purpose

Show how an accepted first-slice workstream stays inspectable from launch
through active work, blockage, recovery, and terminal outcome without hidden
runtime reconstruction.

## Example A: Completed Lifecycle With An Explicit Blocker

### Runtime Floor

- workstream post: `workstream-post-301`
- source link:
  `message-post-201` `follow_up` `workstream-post-301`
- one active owner assignment:
  `worktree-squad-lead`
- visible reviewers:
  `samwise`, `studio-coverage-architect`

### State Trace

1. `draft`
   the workstream exists, but execution has not started
2. `pending`
   launch approval is complete and the lane is ready to begin
3. `in_progress`
   active execution begins and `started_at` becomes meaningful
4. `blocked`
   a required dependency or approval stalls forward progress
5. `in_progress`
   the blocker is resolved and the lane resumes explicitly
6. `completed`
   the requested outcome is achieved and closed out explicitly

### What The Operator Can Inspect

- who owns the lane at every phase
- whether execution has actually started
- whether the lane is blocked versus merely idle
- what closeout truth was returned when work completed

### What Stays On The Workstream Thread

- detailed progress notes
- review discussion
- blocker explanation
- final closeout discussion leading to the terminal signal

## Example B: Failed Lifecycle After Real Launch

### Runtime Floor

- workstream post: `workstream-post-302`
- source link:
  `meeting-post-411` `follow_up` `workstream-post-302`
- one active owner assignment:
  `worktree-squad-lead`

### State Trace

1. `draft`
2. `pending`
3. `in_progress`
4. `failed`

### Required Failure Visibility

- the source context must make clear that:
  - work actually started
  - the requested outcome was not achieved
  - partial evidence or artifacts may still exist
  - retry or follow-up remains an explicit later choice

### Why This Example Matters

- it distinguishes a failed launched workstream from a blocked pre-launch
  handoff
- it proves that terminal failure is explicit rather than inferred from silence
- it keeps the source context and the workstream thread aligned on the same
  lifecycle truth

## Review Focus

- Example A proves that blocked and completed states remain visible and
  reviewable without flattening the lifecycle into one generic status.
- Example B proves that failure remains explicit after launch and does not read
  like hidden abandonment.
