# Failure Matrix

Status: Accepted
Milestone: `M1`
Owner: `architectural-editor`
Last Updated: 2026-03-18

## Purpose

Define the fail-closed behavior expected for identity and activation problems in
the first checkpoint.

## Failure Matrix

| Failure case | Trigger | Expected system behavior | Persisted effect | Visible operator signal | Validation expectation |
| --- | --- | --- | --- | --- | --- |
| No active workspace | request arrives with no valid workspace context | block activation | no activation record for collaborator response | explicit blocked or unavailable state | test proves no response is published |
| Unknown collaborator target | direct address points to no participant in the workspace | block activation | activation failure record plus blocked system-event, no collaborator response | explicit target-not-found message | test proves no fallback collaborator reply |
| Ambiguous collaborator identity | one visible label could map to multiple personas or aliases | block activation | no successful activation record | explicit ambiguity signal requiring review or clarification | test proves ambiguity never auto-resolves silently |
| Frozen `ProdDoc` alias missing or contradicted | first-checkpoint collaborator model omits or conflicts with the `ProdDoc` -> `venture-product-steward` mapping | mark blocked for identity-sensitive activation | activation failure record plus blocked system-event, no successful activation record for that collaborator | explicit blocked state | test proves identity-sensitive flows do not proceed |
| Missing directive | contract resolution returns no directive | block activation | activation failure record plus blocked system-event, no collaborator response | explicit activation-unavailable state | test proves no generic response is substituted |
| Unauthorized skill posture | the required response path would rely on disallowed skill use | block activation | activation failure record plus blocked system-event with required-versus-authorized skill detail | explicit authorization-blocked state | test proves stop before response publication |
| Contract snapshot missing required fields | activation can resolve a persona but not enough inspectable contract context | block or mark failed before publication | no successful attributable response | explicit trace-unavailable or blocked state | test proves inspectability is mandatory |
| Activation persistence failure | response path cannot durably write activation state | fail closed | no user turn or collaborator response is committed into the durable workspace state | explicit persistence-blocked error state | test proves trace-less collaborator output is disallowed |
| Memory-source linkage unknown | system cannot determine whether approved memory influenced the activation | block or mark incomplete | no successful activation until memory posture is explicit | explicit internal inconsistency signal | test proves "unknown" is not shown as if it were "none" |

## Severity Rule

For `M1`, failures in identity, contract resolution, authorization, or durable
trace writing are not soft degradations.

They are milestone-critical failures because each one undermines attribution.

## Quality Rule

The matrix is only useful if every row can be turned into a real test or review
artifact.

If a failure case cannot be validated, it is not controlled.

For the current local first-checkpoint scaffold, the expected blocked-state
artifact is one durable `activation failure` record plus one explicit system
event in the thread. That keeps the operator-visible signal and the persisted
failure evidence aligned.
