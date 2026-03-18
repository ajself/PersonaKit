# Delegated Handoff Packet Template

Status: Draft
Milestone: `M0`
Owner: `samwise`
Last Updated: 2026-03-18

## Purpose

Provide the standard packet shape that later Orbit milestone lanes should start
from.

The template is intentionally strict.
Its job is to reduce drift, not to feel conversational.

It should also prevent a lane from treating implementation work as permission to
redefine approved product or stack direction.

## Use Standard

- one packet per bounded lane
- one active execution persona per lane
- one explicit write scope per lane
- one explicit review ring per lane
- no implicit permission beyond what the packet states

## Packet Template

### 1. Header

- milestone id
- packet id
- execution owner persona id
- review personas
- operator or reviewer required
- status: `ready`, `blocked`, `needs-review`, or `grounding-blocked`

### 2. Objective

- one sentence describing the exact outcome
- why this packet exists now
- why it is the right slice size

### 3. Quality Bar

- the attributes that define a high-quality result
- the shortcuts that would make the packet fail even if output exists
- the evidence needed to prove quality, not just activity

### 4. Preconditions

- decisions that must already be frozen
- artifacts that must already exist
- dependencies on earlier packets or milestones

### 5. Grounding Requirements

- PersonaKit session, directive, or export to load
- required planning docs
- required stack-posture docs
- required RFCs or runtime notes
- whether live grounding is mandatory or static export is acceptable

### 6. Exact Scope

Include:

- what the lane must do
- what it may edit
- what it must produce

Exclude:

- what it must not broaden into
- what belongs to later milestones
- what requires explicit AJ approval before proceeding

### 7. Write Scope

- exact directories or files the lane may change
- exact artifacts it may create
- explicit no-write areas when relevant

If the lane is executing in a dedicated non-main worktree, the write scope may
be repo-wide when the active milestone genuinely requires it.

If repo-wide write freedom is granted, the packet should still say why the
milestone needs that breadth and what legacy surfaces are considered replaceable.

If the write scope is unclear, the packet is not ready.

### 8. Ordered Work Packets

For each packet:

- name
- outcome
- ordered tasks
- completion signal
- review checkpoint if needed

The lane should not invent additional major packets unless a stop point is
reached and AJ reviews the change.

### 9. Validation And Evidence

- tests, reviews, or audits required
- artifacts that prove the packet was completed well
- confidence split when relevant: feature, product, process, persona fidelity

### 10. Failure Dispositions

- `blocked`
  a real dependency is missing
- `needs-review`
  the lane reached a named human review gate
- `grounding-blocked`
  PersonaKit grounding is required and unavailable
- `failed`
  the lane attempted the packet but quality or verification failed

### 11. Stop Points

- exact conditions under which the lane must stop
- what artifact or question must be returned when it stops

### 12. Closeout Return Format

The lane should return:

- shipped or completed
- evidence produced
- open risks
- review decisions needed
- next packet recommendation, if any

## Quality Rules For The Template Itself

The template is successful only if it makes poor delegation harder.

That means it must:

- force explicit scope
- force explicit quality criteria
- force explicit evidence
- force explicit stop points
- force explicit fidelity to already-approved stack and product posture
- prevent lanes from claiming success on thin output alone

## Anti-Patterns

Do not hand off work with:

- generic goals like "implement this milestone"
- missing write scope
- no review ring
- no failure disposition
- no distinction between acceptable output and impressive quality

## Worked Example Skeleton

Use this as a shape example, not as a substitute for milestone-specific detail.

```text
Milestone: M1
Packet: M1-P1 boundary-audit
Execution owner: architectural-editor
Review personas: senior-swiftui-engineer, studio-coverage-architect
Status: ready

Objective:
Freeze the authored-truth vs runtime-truth boundary for first-checkpoint
identity and activation work.

Quality bar:
- boundary ownership is explicit and falsifiable
- ambiguous ownership is treated as a failure, not deferred cleanup

Grounding:
- Orbit-Agentic-Milestone-Roadmap.md
- Orbit-Execution-Plan.md
- Orbit-First-Checkpoint-Runtime-Model.md
- RFC-0001
- RFC-0003

Scope include:
- boundary audit note
- ownership matrix
- drift findings

Scope exclude:
- UI implementation
- server migration
- team or squad modeling

Write scope:
- Docs/Orbit/Planning/Milestones/M1-Identity-And-Activation-Foundation/

Validation and evidence:
- architecture review note
- coverage review of audit completeness

Stop points:
- unresolved ProdDoc mapping
- authored/runtime ownership conflict
```
