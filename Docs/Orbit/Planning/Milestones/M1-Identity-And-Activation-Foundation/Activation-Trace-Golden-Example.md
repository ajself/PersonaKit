# Activation Trace Golden Example

Status: Accepted
Milestone: `M1`
Owner: `architectural-editor`
Last Updated: 2026-03-18

## Purpose

Provide one deterministic example of what a correct first-checkpoint activation
looks like.

This example is intentionally small.
Its value is that it can be reviewed, tested, and discussed without ambiguity.

## Scenario

Context:

- workspace: `Orbit`
- initiating participant: AJ
- targeted collaborator: Samwise
- trigger source: direct address in the active thread
- memory influence: none for this example

Example user turn:

> Samwise, summarize what Orbit is trying to prove in this workspace.

## Expected Resolution

- Orbit resolves the active workspace as `Orbit`
- Orbit resolves the visible collaborator target as `Samwise`
- Orbit resolves the collaborator's PersonaKit contract before response
- Orbit writes a durable activation record linked to the response message

## Expected Runtime Records

### Participant snapshot

```json
{
  "participantId": "participant-samwise",
  "displayName": "Samwise",
  "participantClass": "ai-collaborator",
  "workspacePersonaId": "workspace-persona-orbit-samwise",
  "personaTemplateId": "samwise"
}
```

### Response message snapshot

```json
{
  "messageId": "message-0002",
  "threadId": "thread-main",
  "speakerParticipantId": "participant-samwise",
  "messageKind": "participant-response"
}
```

### Activation record snapshot

```json
{
  "activationId": "activation-0001",
  "workspaceId": "orbit",
  "responseMessageId": "message-0002",
  "participantId": "participant-samwise",
  "workspacePersonaId": "workspace-persona-orbit-samwise",
  "personaTemplateId": "samwise",
  "directiveId": "<resolved-directive-id>",
  "responseMode": "direct-message",
  "triggerSource": "direct-address",
  "triggerMessageId": "message-0001",
  "memoryInfluenced": false,
  "memorySourceRefs": []
}
```

### Contract snapshot expectation

Example contract snapshot:

```json
{
  "contractSnapshotId": "activation-0001-contract",
  "activationId": "activation-0001",
  "directiveSource": "participant-default",
  "kitIds": [],
  "authorizedSkillIds": [],
  "stopPointIds": [],
  "reviewGateIds": [],
  "memoryScopeIds": []
}
```

Whether this is embedded or linked, reviewers must be able to inspect:

- stable contract snapshot id or reference
- resolved directive id
- resolved kit ids when present
- allowed skill posture, including the explicit no-skill case
- stop-point posture relevant to the activation
- review-gate posture relevant to the activation
- memory-scope posture relevant to the activation

## Expected Operator-Visible Trace

The first-checkpoint UI or inspection surface should let AJ see:

- Samwise responded
- the response was guided by a specific directive
- no approved memory influenced this response
- the response came from a direct address in the current thread
- the response was allowed under the resolved contract posture rather than an
  opaque fallback

The UI does not need to dump raw JSON.
It does need to make the trace legible enough that the operator can verify this
was a bounded collaborator response rather than opaque routing.

## Why This Example Matters

This example proves all of the following in one small slice:

- collaborator identity is stable
- activation attribution is durable
- contract resolution happened before publication
- no-memory and memory-influenced cases can be distinguished explicitly

## Disqualifying Deviations

This example fails if:

- the response appears without a durable activation record
- the participant label, workspace persona identity, and persona-template identity do not match
- the directive is not inspectable
- the system cannot distinguish "no memory used" from "unknown whether memory was
  used"
