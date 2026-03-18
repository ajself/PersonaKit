# M13 Platform Operations, Historical Inspection, And Service Hardening

Status: Planned
Primary Owner: `orbit-platform-operator` or `orbit-server-steward`
Supporting Personas: `studio-integration-coordinator`, `studio-reliability-engineer`, `studio-coverage-architect`, `architectural-editor`
Last Updated: 2026-03-18

## Purpose

Turn Orbit into a mature self-hosted platform rather than a promising prototype.

## Preconditions

- canonical runtime and multi-client behavior are already real enough to operate
- a platform-operations persona is approved
- there is enough production-like usage to justify replay, restore, and audit
  hardening

## Scope Freeze

In scope:

- deployment topology and runbook
- backup and restore stewardship
- replay integrity and historical inspection
- richer storage backends where justified
- observability and operational quality signals
- service decomposition only if evidence supports it

Out of scope:

- fashionable decomposition without need
- invisible platform changes that break runtime semantics

## Required Inputs

- `Docs/Orbit/RFCs/RFC-0006-Orbit-Multi-Client-Platform-Architecture.md`
- platform evidence from `M3`, `M11`, and `M12`
- any deployment and storage notes produced during earlier milestones

## Execution Packets

### Packet 1. Freeze The Operations Model

Outcome:

- Orbit has one clear operational story for self-hosted use

Work:

- define deployment topology
- define ownership for backups, restore, and operational review
- define failure classes and escalation paths

Done when:

- there is one stable platform operations contract

### Packet 2. Implement Backup, Restore, And Replay Integrity

Outcome:

- the platform can recover and inspect history intentionally

Work:

- implement backup paths
- implement restore verification
- implement replay and integrity checks

Done when:

- restore drills and replay checks can be run with deterministic evidence

### Packet 3. Implement Observability And Historical Inspection

Outcome:

- operators can inspect platform state and history without guessing

Work:

- add observability surfaces
- add historical inspection views
- define quality signals that matter operationally

Done when:

- platform health and history can be reviewed without digging through raw logs

### Packet 4. Review Storage And Service Boundaries

Outcome:

- scaling decisions stay evidence-based

Work:

- review storage backend options
- review whether monolith-first boundaries are still serving Orbit
- propose service splits only if operational evidence demands them

Done when:

- architecture decisions are justified by real platform pressure, not taste

### Packet 5. Run Operational Readiness Review

Outcome:

- Orbit can be treated as a dependable self-hosted platform

Work:

- run restore and replay review
- run reliability and coverage review
- produce one operational readiness packet for AJ

Done when:

- AJ can inspect the platform readiness evidence and decide how broadly to rely
  on Orbit

## Subagent Use Pattern

Safe subagents:

- deployment and backup review
- replay-integrity review
- observability review
- architecture review for service-boundary changes

Avoid:

- splitting services in parallel without one authoritative architecture owner

## Evidence Package

- operations model note
- backup and restore drill evidence
- replay-integrity evidence
- observability examples
- operational readiness review packet

## Stop Points

- stop if operational recovery cannot be demonstrated
- stop if service decomposition is driven by fashion instead of evidence
- stop if platform changes break the product-level trust and control model

## Exit And Handoff

Exit when Orbit can be operated, audited, restored, and evolved as a dependable
self-hosted system.
