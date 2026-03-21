# Persona Hiring Review: orbit-meeting-coordinator

Date: 2026-03-20
Session: `samwise-persona-hiring`
Reviewer: Samwise

## Role Context And Required Capabilities

Role context: Assess whether `orbit-meeting-coordinator` is qualified to own `M4` team-and-squad collaboration with visible coordinator expansion, and to close the missing-owner gap that later coordinator-dependent planning currently references without treating those later milestones as delivery-approved.

Required capabilities:

1. Expand team and squad targets into deterministic workspace persona participation sets.
2. Keep inclusion and exclusion reasoning explicit and operator-inspectable.
3. Preserve the boundary between inline group replies, later meeting promotion, and broader workstream routing.
4. Coordinate packetized delivery with one bounded packet per loop and explicit human review gates.
5. Provide real review and delivery session surfaces instead of relying on an implied future persona.

## Evidence References

1. `.personakit/Packs/personas/orbit-meeting-coordinator.persona.json:2`
2. `.personakit/Packs/personas/orbit-meeting-coordinator.persona.json:6`
3. `.personakit/Packs/personas/orbit-meeting-coordinator.persona.json:21`
4. `.personakit/Sessions/orbit-meeting-coordinator-review.session.json:2`
5. `.personakit/Sessions/orbit-meeting-coordinator-delivery.session.json:2`
6. `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/README.md:4`
7. `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/README.md:15`
8. `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md:44`
9. `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md:163`
10. `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md:179`
11. `Docs/Orbit/RFCs/RFC-0003-Workspace-Group-and-Workspace-Persona-Instance-Model.md:149`
12. `Docs/Orbit/RFCs/RFC-0003-Workspace-Group-and-Workspace-Persona-Instance-Model.md:166`
13. `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Persona-Coverage-Matrix.md:21`
14. `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Persona-Coverage-Matrix.md:22`
15. `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Persona-Coverage-Matrix.md:29`

## Strengths

1. The role boundary is explicit: Samwise remains orchestrator while the coordinator owns group-routing semantics.
2. RFC-0004 already defines the coordinator as the authority for target expansion, inclusion reasoning, participation roles, and visible coordination state.
3. `M4` already names this persona as owner, and `M5` plus coordinator-dependent `M12` planning already reference it as future owner or support, so creating it removes the missing-owner gap without promoting those later milestones.
4. The new review and delivery sessions make the persona concretely addressable for review-led preflight work instead of leaving it as a roadmap placeholder.
5. The approved M4 control posture is strong: no `main` mutation, one packet per loop, and explicit stop points before broader execution.

## Gaps By Severity

- Medium: No dedicated `orbit-meeting-coordinator-core` kit exists yet, so the persona currently relies on role text plus shared repo constraints rather than a portable domain bundle.
- Medium: The M4 dossier still needs the packet docs, quality bar, and validation matrix promised by the preflight plan before live delivery loops should be trusted.
- Low: The new coordinator review and delivery sessions are candidate lanes and have not yet been exercised on a real M4 packet.

## Unknowns And Assumptions

Unknowns:

1. How much the coordinator's delivery session will need to diverge from generic integration guidance once packet implementation begins.
2. Whether later M5 and M12 work will require a richer coordinator-specific kit or additional review surfaces beyond the initial review and delivery sessions.

Assumptions:

1. AJ is explicitly approving review and tightening of the local coordinator persona and its initial session stack through this `M4` Preflight A request.
2. M4 remains limited to inline team and squad collaboration with visible reasoning; meeting promotion remains later-milestone work.

## Confidence Score And Threshold

Threshold used: 80 (default)

Pre-research score:

1. Domain understanding: 5/5
2. Delivery planning quality: 4/5
3. Risk and guardrail discipline: 4/5
4. Collaboration and handoff clarity: 4/5
5. Tooling/workflow coverage: 4/5

Total: 21/25 => 84%

Research loop run: No (confidence above threshold, unknowns non-blocking for baseline qualification).

## Verdict

`qualified`

This clears the missing-owner gap for `M4` and records owner/support availability for later coordinator-dependent planning. It does not promote the candidate sessions or approve `M5` or `M12` execution.

## Missing Artifact Recommendations By Type

- Essentials:
  - none required for baseline qualification
- Kits:
  - `orbit-meeting-coordinator-core`
- Intents:
  - none required for baseline qualification
- Directives:
  - none required for baseline qualification
- Sessions:
  - none required for baseline qualification

## First Implementation Step

Finish M4 preflight by filling the dossier control surfaces promised in the plan: packet docs, quality bar, validation matrix, and decision register before any runtime-facing M4 packet begins.
