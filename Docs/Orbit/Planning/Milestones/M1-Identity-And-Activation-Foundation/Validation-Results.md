# Validation Results

Status: Accepted
Milestone: `M1`
Owner: `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Record the current deterministic validation readout for the `M1` identity and
activation foundation.

## Validation Command

- `swift test`
- `git diff --check`

## Current Passing Readout

### Successful activation coverage

- `directAddressCreatesParticipantResponseAndActivationTrace`
  proves one direct-address response persists participant, workspace persona,
  directive, contract snapshot, and operator trace data
- `foundingGroupInvitationCreatesMeetingEventAndMultipleResponses`
  proves the lightweight meeting path persists multiple attributable activation
  records with participant-specific contract snapshots

### Fail-closed coverage

- `unknownCollaboratorTargetBlocksActivationAndPersistsFailure`
- `missingDirectiveBlocksActivationAndPersistsFailure`
- `frozenProdDocAliasContradictionBlocksActivation`
- `unauthorizedSkillPostureBlocksActivationAndPersistsSkillDetail`
- `persistenceFailureDoesNotPublishConversationTurn`

Together these prove `M1` blocks instead of fabricating certainty when identity,
directive, authorization, or durable write conditions fail.

### Live contract-resolution coverage

- `contractResolverUsesLivePersonakitContractForSamwise`
- `contractResolverUsesLivePersonakitContractForProdDocAlias`
- `contractResolverFailsCleanlyWhenProjectScopeIsMissing`

These prove the workspace-backed send path can resolve live PersonaKit contract
data and fail clearly when the active workspace cannot provide a usable scope.

### Snapshot review coverage

- `OrbitSnapshotTests.testOrbitDefaultWorkspace`
- `OrbitSnapshotTests.testOrbitMeetingConversation`

These prove the current UI exposes the expected trace surface for both the
default checkpoint workspace and the lightweight meeting view.

## Honest Limits Of This Result

- the current validation set proves the local first-checkpoint slice, not the
  later server-backed runtime
- the response body generator is still deterministic local scaffolding even
  though the contract attribution is now grounded against live PersonaKit data
- memory-scope evidence remains the explicit no-memory case in `M1`

## Review Use

AJ should read this file alongside:

- `Activation-Trace-Golden-Example.md`
- `Failure-Matrix.md`
- `Operator-Trace-Walkthrough.md`
- `Review-Packet.md`

If any listed proof no longer matches the implementation, this file should be
updated before `M1` is treated as review-ready.

Current disposition:

- this validation readout supported AJ approval of `M1` as the local
  identity-and-activation baseline for `M2`
