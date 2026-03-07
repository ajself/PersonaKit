# VentureStudio Planning Management (v1)

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

This directory defines the planning-management operating system for VentureStudio
initiative work. It is docs-first, gate-driven, and deterministic.

## Scope (v1)

- Workspace scope only: `Workspaces/VentureStudio/`
- No migration of root `Docs/Plan` governance in this phase.
- No PersonaKit pack/session encoding in this phase.

## Core Specs

- [Content Operations Charter](./content-operations-charter.md)
- [Pass Protocol Spec](./pass-protocol-spec.md)
- [Content QA Rubric Spec](./content-qa-rubric-spec.md)
- [Artifact Template Library Spec](./artifact-template-library-spec.md)
- [Gardening Cadence and Drift Policy](./gardening-cadence-and-drift-policy.md)
- [Automation Command Spec](./automation-command-spec.md)
- [Pilot Validation Plan](./pilot-validation-plan.md)
- [Pilot Validation Report](./pilot-validation-report.md)

## Status Board

| Spec | Status | Owner | Last Reviewed |
| --- | --- | --- | --- |
| content-operations-charter.md | Active | AJ | 2026-03-07 |
| pass-protocol-spec.md | Active | AJ | 2026-03-07 |
| content-qa-rubric-spec.md | Active | AJ | 2026-03-07 |
| artifact-template-library-spec.md | Active | AJ | 2026-03-07 |
| gardening-cadence-and-drift-policy.md | Active | AJ | 2026-03-07 |
| automation-command-spec.md | Active | AJ | 2026-03-07 |
| pilot-validation-plan.md | Active | AJ | 2026-03-07 |

## Gate Tracker

Hard rule: No gate skipping.

| Gate | Name | Pass Criteria | Fail Criteria | Evidence Required | State | Reviewer Signoff |
| --- | --- | --- | --- | --- | --- | --- |
| G0 | Foundation | Planning index exists with scope, ownership, and status model | Missing scope, ownership, status board, or gate tracker | `README.md` + status board + gate tracker | Approved (2026-03-07) | Complete |
| G1 | Protocol | Canonical pass sequence + pass entry/exit criteria are complete | Missing sequence item, missing entry/exit criteria, or skip/exception allowance | `pass-protocol-spec.md` | Approved (2026-03-07) | Complete |
| G2 | QA | Rubric weights, severity model, and stop rules are complete | Missing weighted model, missing severity definitions, or missing stop rules | `content-qa-rubric-spec.md` | Approved (2026-03-07) | Complete |
| G3 | Templates | Required template schema + minimum depth are complete | Missing required template section, metadata requirement, or traceability expectation | `artifact-template-library-spec.md` | Approved (2026-03-07) | Complete |
| G4 | Operations | Cadence/drift policy and automation contracts are complete | Missing cadence trigger, drift trigger, or command contract section | `gardening-cadence-and-drift-policy.md` + `automation-command-spec.md` | Approved (2026-03-07) | Complete |
| G5 | Pilot Ready | Pilot scenarios, acceptance criteria, and reporting are complete | Missing one required scenario, acceptance criterion, or reporting field | `pilot-validation-plan.md` + `pilot-validation-report.md` | Approved (2026-03-07) | Complete |

## Approval Model

- Reviewer model: human-in-the-loop.
- A gate is approved only when pass criteria and evidence are both satisfied.
- If a gate fails, remediation must be documented before re-review.

## Operating Defaults

- AP style enforcement is mandatory in Voice and QA passes.
- Publish readiness requires QA score `>= 85` and `0` blockers.
- Every Major/Minor finding must include owner and disposition.

## Initial Verification Snapshot (2026-03-07)

- Spec completeness: pass (`7` core specs + `README` present and cross-linked).
- Metadata compliance: pass (all spec files include `Status`, `Owner`, `Last Reviewed`).
- Gate integrity: pass (G0-G5 include pass/fail criteria and required evidence).
- Rubric calibration dry run:
  - Artifact: `Workspaces/VentureStudio/Docs/Business/StoryPilot/03-site-structure.md`
  - Run A: `82`
  - Run B: `84`
  - Result: variance `2` (`<= +/-5`) and same severity class (`Major`)
- Blocker enforcement contract: pass (protocol/rubric require halt before `final` when blocker exists).
- Drift trigger coverage: pass (stale metadata + broken link + rubric-template mismatch + unresolved findings).
- Pilot readiness coverage: pass (happy, blocker, deferred-major, and daily-gardening scenarios defined).

Related docs:

- [Venture Studio Docs Index](../README.md)
- [Venture Studio Session Directory](../Development/session-directory.md)
- [Repository Documentation Style Guide](../../../../Docs/STYLEGUIDE.md)
