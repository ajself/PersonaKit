# Architecture Review Artifact

Status: Accepted
Milestone: `M3`
Owner: `architectural-editor`
Grounding: `architectural-editor` + `apply-style`
Last Updated: 2026-03-20

## Decision

- result: `pass with notes`

## Review Readout

### Canonical ownership

- pass: the canonical runtime boundary is explicit and frozen in the Packet 1
  contract and boundary audit
- pass: runtime records now live in a dedicated `OrbitServerRuntime` module
- pass: the macOS client now activates the server-backed room path directly from
  canonical gateway configuration instead of depending on a separate feature
  gate

### Authored versus runtime truth

- pass: PersonaKit-authored truth is still kept outside server-owned runtime
  tables
- pass: contract linkage remains modeled as runtime linkage rather than a second
  authored policy store

### Persistence and replay architecture

- pass: the first raw-SQL schema, repository, loader, replay, and transport
  adapter stack is coherent
- pass: the first live `Vapor` gateway seam now stays thin over the same replay
  and session services
- pass: replay semantics are layered under the transport seam instead of being
  reimplemented at the edge
- pass: the macOS transport path can now stay on one persistent gateway
  `WebSocket` connection and reconnect from its last canonical replay cursor
- pass: the currently supported runtime mutation types now replay through the
  durable event model on the macOS server-backed path

### Storage boundary

- pass: artifact storage is separated from transactional runtime truth through an
  object-style abstraction and filesystem backend

## Strongest Architecture Wins

1. The server/runtime backbone is now a real module, not only milestone prose.
2. Layering is disciplined: schema -> repository -> store -> replay services ->
   transport-facing adapter.
3. The first backend decisions still honor the approved monolith-first posture.

## Strongest Remaining Architecture Notes

1. The live gateway now includes persistent transport, but the current channel
   still carries bootstrap-plus-poll semantics rather than a fully push-driven
   subscription model.
2. The macOS cutover still depends on canonical gateway configuration being
   present, so architecture review should not confuse configured cutover with
   automatic environment provisioning.

## Judgment

The current `M3` implementation is architecture-reviewable and remains inside the
approved `Swift + Vapor + Postgres`, monolith-first direction.

Current disposition:

- this architecture readout supported AJ approval of the current `M3` checkpoint
