# M1 Evidence And Exit Criteria

Status: Accepted
Milestone: `M1`
Owner: `architectural-editor`
Last Updated: 2026-03-18

## Purpose

Define the proof package required to close `M1` honestly.

## Hero Proof

`M1` should produce one hero proof that can be inspected end to end:

- one operator turn
- one correctly resolved collaborator
- one durable response message
- one durable activation record
- one inspectable contract snapshot
- one visible operator trace
- one passing deterministic validation set covering both success and failure

If that hero proof is weak or incomplete, `M1` is not done.

## Required Artifacts

1. boundary audit note
2. workspace persona and collaborator model note
3. identity and activation contract
4. golden trace example
5. failure matrix
6. validation and review matrix
7. deterministic test evidence for happy path and failure path behavior
8. operator-visible trace walkthrough or equivalent review artifact
9. compact review packet that AJ can evaluate without reconstructing thread
   memory

## Exit Checklist

`M1` exits only when all of these are true:

- one response can be traced to a workspace persona instance
- the boundary audit note matches the implemented ownership split
- the identity model note matches the implemented participant and collaborator mapping
- the directive context is inspectable
- kits or equivalent contract snapshot context are inspectable when applicable
- allowed skill posture is inspectable
- stop-point posture is inspectable or explicitly represented in the activation
  contract review path
- blocked activation paths leave explicit operator-visible evidence instead of
  silently disappearing
- ambiguity cases fail closed
- unauthorized cases fail closed
- persistence failure prevents a completed attributable response from being shown
- the golden example matches the implemented behavior
- the operator-visible trace shows why the response was allowed, not only who
  responded
- the compact review packet is strong enough that AJ can judge `M1` without
  re-reading the full dossier set
- architecture review passes
- deterministic coverage review passes

## Residual Open Dependency

`M1` should still be treated as blocked if the frozen `ProdDoc` ->
`venture-product-steward` alias from `M0` is omitted or contradicted in the
first-checkpoint identity model.

That is not a defect in this dossier set.
It is a real dependency that should remain visible.

## Not Enough To Exit

These do not count as success:

- the right collaborator name appears in the UI
- a response exists but trace fields are partial
- only the happy path works
- the implementer can explain the contract verbally but the artifacts do not make
  it inspectable
- memory posture is left as `unknown` for a supposedly successful trace

## Review Gate

Before `M2` is allowed to broaden the UI around this milestone, AJ should be
able to review a small, convincing packet containing:

- the contract summary
- the golden example
- the failure matrix
- the validation results
- the operator-visible trace walkthrough
- the compact review packet

If that packet is not sharp, `M1` should remain open.
