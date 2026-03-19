# Execution Packet Template

Status: <Draft | Ready For Planning Closeout | In Review | Accepted>
Packet Id: `<milestone-id>-P<packet-number>`
Milestone: `<milestone-id>`
Execution Owner: `<primary-persona-id>`
Review Personas: `<persona-a>`, `<persona-b>`
Last Updated: <YYYY-MM-DD>

## Header

- status: `<ready | blocked | needs-review | grounding-blocked | failed>`
- operator or reviewer required: `<yes or no>`
- packet type: `<planning | implementation | review | validation>`

## Objective

- <one sentence exact outcome>
- <why this packet exists now>
- <why this is the right slice size>

## Quality Bar

- <quality attribute>
- <quality attribute>
- <evidence requirement>

## Preconditions

- <dependency>
- <dependency>

## Grounding Requirements

- `<PersonaKit session, directive, or export>`
- `<planning doc>`
- `<RFC or runtime note>`
- live grounding required: `<yes or no>`

## Exact Scope

Include:

- <included work>
- <included work>

Exclude:

- <excluded work>
- <excluded work>

## Write Scope

- may edit: `<path or directory>`
- may create: `<artifact or path>`
- must not edit: `<path or category>`

## Ordered Work

1. <work step>
2. <work step>
3. <work step>

## Validation And Evidence

- <test or review>
- <artifact>
- confidence split if relevant: `<feature | product | process | persona fidelity>`

## Failure Dispositions

- `blocked`
  <real dependency missing>
- `needs-review`
  <named review gate reached>
- `grounding-blocked`
  <required grounding unavailable>
- `failed`
  <quality or verification failure>

## Stop Points

- stop if <condition>
- stop if <condition>

## Closeout Return Format

- completed or shipped
- evidence produced
- open risks
- review decisions needed
- next recommended packet
