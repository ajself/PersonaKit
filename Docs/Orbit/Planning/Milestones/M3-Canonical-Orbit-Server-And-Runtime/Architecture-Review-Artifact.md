# Architecture Review Artifact

Status: Accepted
Milestone: `M3`
Owner: `architectural-editor`
Grounding: `architectural-editor` + `apply-style`
Last Updated: 2026-03-18

## Decision

- result: `pass with notes`

## Review Readout

### Canonical ownership

- pass: the canonical runtime boundary is explicit and frozen in the Packet 1
  contract and boundary audit
- pass: runtime records now live in a dedicated `OrbitServerRuntime` module
- note: the macOS client has a projection seam, but full cutover is not yet
  complete

### Authored versus runtime truth

- pass: PersonaKit-authored truth is still kept outside server-owned runtime
  tables
- pass: contract linkage remains modeled as runtime linkage rather than a second
  authored policy store

### Persistence and replay architecture

- pass: the first raw-SQL schema, repository, loader, replay, and transport
  adapter stack is coherent
- pass: replay semantics are layered under the transport seam instead of being
  reimplemented at the edge
- note: a durable event-store table is still deferred; replay is currently
  projected from canonical room state

### Storage boundary

- pass: artifact storage is separated from transactional runtime truth through an
  object-style abstraction and filesystem backend

## Strongest Architecture Wins

1. The server/runtime backbone is now a real module, not only milestone prose.
2. Layering is disciplined: schema -> repository -> store -> replay services ->
   transport-facing adapter.
3. The first backend decisions still honor the approved monolith-first posture.

## Strongest Remaining Architecture Notes

1. The first network transport is still absent, so the transport adapter remains
   request/response rather than a live channel.
2. The current replay model still projects from canonical room state rather than
   a dedicated durable event log.

## Judgment

The current `M3` implementation is architecture-reviewable and remains inside the
approved `Swift + Vapor + Postgres`, monolith-first direction.

Current disposition:

- this architecture readout supported AJ approval of the current `M3` checkpoint
