# Persona Hiring Review: orbit-memory-gardener

Date: 2026-03-29
Session: `samwise-persona-hiring`
Reviewer: Samwise

## Role Context And Required Capabilities

Role context: Assess whether `orbit-memory-gardener` is qualified to own `M8`
journaling and memory candidate review with governance-first stewardship, and
to close the missing-owner gap that `M8` through `M10` currently reference
without treating those later milestones as delivery-approved.

Required capabilities:

1. Preserve the reviewed boundary between runtime history, journal entries,
   memory candidates, and approved memory.
2. Keep provenance, scope, and intended future influence explicit for later
   review surfaces.
3. Surface duplicate, contradiction, supersession, and stale-memory concerns
   as visible recommendations rather than hidden behavior.
4. Preserve the boundary between authored persona truth and reviewed memory
   influence.
5. Provide real review and delivery session surfaces instead of leaving the
   owner role as a roadmap placeholder.

## Evidence References

1. `.personakit/Packs/personas/orbit-memory-gardener.persona.json:2`
2. `.personakit/Packs/personas/orbit-memory-gardener.persona.json:6`
3. `.personakit/Packs/personas/orbit-memory-gardener.persona.json:21`
4. `.personakit/Sessions/orbit-memory-gardener-review.session.json:2`
5. `.personakit/Sessions/orbit-memory-gardener-delivery.session.json:2`
6. `Docs/Orbit/Planning/Milestones/M8-Journaling-And-Memory-Candidate-Review/README.md:4`
7. `Docs/Orbit/Planning/Milestones/M9-Approved-Memory-And-Scoped-Retrieval/README.md:4`
8. `Docs/Orbit/Planning/Milestones/M10-Memory-Gardening-And-Cross-Workspace-Promotion/README.md:4`
9. `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md:741`
10. `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md:863`
11. `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md:1051`
12. `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Persona-Coverage-Matrix.md:25`
13. `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Persona-Coverage-Matrix.md:67`
14. `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Decision-Register.md:76`

## Strengths

1. The role boundary is explicit: the memory gardener is a steward for reviewed
   learning, not an authority that auto-promotes memory or bypasses operator
   review.
2. RFC-0005 already defines the core job clearly: journaling and memory remain
   attributable, scope-sensitive, provenance-aware, and review-first.
3. `M8`, `M9`, and `M10` already name this persona as owner, so creating it
   removes the missing-owner gap without silently approving later execution.
4. The new review and delivery sessions make the owner concretely addressable
   for bounded future packet work instead of leaving it as a planning-only
   label.
5. The accepted `M8-P1` intake-boundary posture stays strong: owner coverage is
   now real, but later packets still need explicit packet kickoff and review.

## Gaps By Severity

- Medium: No dedicated `orbit-memory-gardener-core` kit exists yet, so the
  persona currently relies on role text plus shared repo constraints rather
  than a portable memory-governance bundle.
- Medium: Later `M8` through `M10` packets remain intentionally unstarted, so
  the new owner has not yet been exercised on a real memory-governance packet.
- Low: The new review and delivery sessions are candidate lanes and may need
  richer domain-specific directives once journal and candidate workflow packets
  become active.

## Unknowns And Assumptions

Unknowns:

1. How much the delivery session will need to diverge from generic
   integration-with-stop-points guidance once real `M8` packet work begins.
2. Whether later `M9` and `M10` work will require a dedicated core kit or
   additional review surfaces beyond the initial candidate sessions.

Assumptions:

1. AJ is explicitly approving closure of the missing-owner gap for the memory
   steward role, not automatic start of later `M8` packet execution.
2. The accepted `M8-P1` planning baseline remains the authoritative starting
   point for later journaling and candidate-review work.

## Confidence Score And Threshold

Threshold used: 80 (default)

Pre-research score:

1. Domain understanding: 5/5
2. Delivery planning quality: 4/5
3. Risk and guardrail discipline: 4/5
4. Collaboration and handoff clarity: 4/5
5. Tooling/workflow coverage: 4/5

Total: 21/25 => 84%

Research loop run: No (confidence above threshold, unknowns non-blocking for
baseline qualification).

## Verdict

`qualified`

This clears the missing-owner gap for `M8` through `M10` and records
owner/support availability for later memory-governance planning. It does not
promote the candidate sessions or approve `M8`, `M9`, or `M10` execution.

## Missing Artifact Recommendations By Type

- Essentials:
  - none required for baseline qualification
- Kits:
  - `orbit-memory-gardener-core`
- Intents:
  - none required for baseline qualification
- Directives:
  - none required for baseline qualification
- Sessions:
  - none required for baseline qualification

## First Implementation Step

Use the new owner only to open the next explicit `M8` packet from the accepted
`M8-P1` baseline; do not treat owner availability as approval for runtime, UI,
schema, or automatic memory-governance work.
