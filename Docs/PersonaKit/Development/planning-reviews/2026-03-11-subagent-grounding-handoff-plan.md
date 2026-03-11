# Squad Planning Review: Subagent Grounding And Handoff Refinement

Date: `2026-03-11`  
Objective: Refine `assemble-squad-and-plan` so any delegated subagents are
given explicit PersonaKit MCP grounding requirements and robust handoff packets
before execution begins.  
Workspace or initiative scope: `PersonaKit` planning-stack artifacts for
Samwise-led squad planning and execution handoff  
Session ID: `samwise-squad-planning`  
Reviewer: `AJ`  
Handoff status: `awaiting-aj-review`

## Objective Boundary

1. Goal summary:
   - Make delegated-agent grounding a required planning output instead of an
     operator habit, so spawned agents load the right PersonaKit context before
     they act.
2. In scope:
   - `multiagent-squad-planning-contract`
   - `assemble-squad-and-plan-review`
   - `assemble-squad-and-plan`
   - `squad-planning-report-template`
   - Any minimal log-contract refinement needed to record delegated handoff
     packets without bloating the planning stack
3. Out of scope:
   - Changing agent platform capabilities outside this repo
   - Assuming PersonaKit MCP is always available without an explicit failure
     path
   - Starting structural pack edits in this planning pass
4. Hard constraints:
   - Keep the first refinement small and reusable across workspaces
   - Fail closed when a delegated lane requires PersonaKit MCP but cannot load
     it
   - Allow static PersonaKit export fallback only for bounded implementation or
     review work
   - Keep execution blocked until AJ approves the planning-stack changes

## Proposed Squad

1. Role:
   - Owner: `samwise`
   - Responsibility boundary: shaping, orchestration, approval-gate ownership
   - Why this owner: Samwise owns the planning workflow and the stop point
     before execution handoff
2. Role:
   - Owner: `architectural-editor`
   - Responsibility boundary: review, contract clarity, invariant wording
   - Why this owner: the problem is fundamentally about turning implicit
     behavior into an enforceable contract
3. Role:
   - Owner: `studio-workflow-operator`
   - Responsibility boundary: execution, validation-workflow hardening,
     delegated-handoff requirements
   - Why this owner: this persona specializes in reliable multi-agent workflow
     hardening
4. Role:
   - Owner: `pack-gardener`
   - Responsibility boundary: execution, pack/session maintenance hygiene,
     logging discipline
   - Why this owner: the likely implementation is a bounded pack/session update
     set with validation and continuity requirements
5. Role:
   - Owner: `AJ`
   - Responsibility boundary: approval
   - Why this owner: refining the planning stack changes structural PersonaKit
     artifacts and remains human-gated

## Role Coverage Review

1. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: `samwise` plus `assemble-squad-and-plan` already own this
     planning lane
   - Reverse-interview required: No
2. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: `architectural-editor` explicitly reviews falsifiability,
     boundaries, and durable invariants
   - Reverse-interview required: No
3. Role:
   - Coverage status: `covered`
   - Confidence: Medium-High
   - Evidence: `studio-workflow-operator` is dedicated to reliable multi-agent
     execution workflow hardening
   - Reverse-interview required: No
4. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: `pack-gardener` owns pack/session maintenance quality and
     bounded updates
   - Reverse-interview required: No
5. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: AJ approval gates are already explicit in the active planning
     contract and directive
   - Reverse-interview required: No

## Missing Roles And Artifact Gaps

1. Missing role or gap:
   - Recommended artifact type: `none`
   - Priority: High
   - First implementation step: keep the first pass inside the existing
     planning stack by refining current contract, intent, directive, template,
     and log usage before inventing new PersonaKit structure

## Proposed Artifact Edits

1. `multiagent-squad-planning-contract`
   - Add a delegated-handoff requirement whenever a role will be staffed by a
     spawned agent
   - Require each handoff packet to name:
     - assigned persona ID
     - required session or directive
     - explicit PersonaKit MCP grounding requirement
     - load target set: persona, directive, associated kits, and essentials
     - write scope
     - acceptance criteria
     - validation commands
     - stop points and failure path if MCP grounding fails
   - Define the fallback ladder explicitly:
     - live PersonaKit MCP first
     - approved static PersonaKit export second for bounded implementation or
       review work
     - otherwise stop as `grounding-blocked`
2. `assemble-squad-and-plan-review`
   - Extend the intent contract so planning output is incomplete when delegated
     roles lack explicit handoff packets
   - Add risk notes that slim prompts are insufficient for PersonaKit-backed
     delegated lanes
   - Add a note that planning, hiring, remediation, and open-ended discovery
     must not silently degrade to cached PersonaKit context
3. `assemble-squad-and-plan`
   - Insert or tighten a step requiring delegated-handoff packets before
     execution handoff is considered ready
   - Update acceptance criteria and verification so plans must show delegated
     grounding instructions and a fail-closed path when MCP is unavailable
4. `squad-planning-report-template`
   - Add a required section for delegated-agent handoff packets
   - Keep the section compact and structured so it is easy to reuse in later
     sessions
5. `squad-planning-log-contract`
   - Keep the first pass small by recording delegated handoff details under
     `details` unless repeated use proves a top-level schema field is worth the
     added structure

## First Checkpoint Plan

1. Checkpoint or milestone:
   - Owner: `pack-gardener`
   - Definition of done:
     - the planning contract requires delegated handoff packets for spawned
       agent roles
     - the intent and directive explicitly require PersonaKit MCP grounding
       before delegated work begins
     - the report template includes a delegated-handoff section with the
       required packet fields
     - the log contract or `details` guidance records enough delegated-handoff
       structure to preserve continuity without over-expanding schema surface
     - validation and stop-point language makes MCP-unavailable cases follow a
       clear fallback ladder: live MCP first, approved static export second for
       bounded implementation or review work, otherwise `grounding-blocked`
   - Dependencies:
     - current `assemble-squad-and-plan` planning stack
     - AJ approval for structural pack updates
     - a crisp definition of what counts as bounded implementation or review
       fallback versus planning-heavy work that still requires live MCP
   - Review gate:
     - `architectural-editor` reviews contract wording and boundary discipline
     - AJ reviews the planning-stack refinement before implementation handoff
   - Validation owner:
     - `studio-workflow-operator`
   - Validation commands or evidence:
     - `swift run personakit validate --root .personakit`
     - `Scripts/check-squad-planning-logs.sh`
     - manual review that delegated handoff packets include PersonaKit MCP
       grounding, static-export fallback rules, write scope, validation, and
       failure path fields

## Delegated Grounding Policy

1. Preferred path:
   - delegated lanes load PersonaKit context through live MCP before work
     begins
2. Approved fallback:
   - the parent lane may prepare a frozen PersonaKit export on disk or pass the
     same resolved context directly as input
   - the export should include persona, directive, associated kits,
     essentials, scope boundary, and validation expectations
   - the delegated lane should treat the export as a static snapshot
3. Fallback boundary:
   - static export fallback is acceptable for bounded implementation or review
     work
   - planning, hiring, remediation, and open-ended discovery must not silently
     degrade to cached PersonaKit context
4. Failure mode:
   - if neither live MCP nor an approved static export is available, the lane
     stops as `grounding-blocked`

## Unknowns And Risks

1. The plan can make the requirement explicit, but real reliability still
   depends on delegated agents actually having PersonaKit MCP available in their
   tool surface.
2. Over-specifying the handoff packet could create prompt bloat, so the first
   refinement should optimize for minimum sufficient structure rather than long
   prose.
3. Static PersonaKit export fallback is workable, but it introduces staleness
   risk and should not be treated as equivalent to live MCP for planning-heavy
   work.
4. If the implementation tries to add a new essential or schema field
   prematurely, the change could grow beyond the smallest useful refinement.
5. Quality gate result: `pass-with-notes` because the direction is clear and
   actionable, but structural artifact edits remain intentionally blocked for AJ
   review.

## Recommended Next Session

1. Session ID:
   - Why next: `pack-gardener-maintenance` is the best fit for the approved
     structural update pass because the likely work is a bounded set of
     pack/session artifact refinements with validation and continuity logging
   - Expected inputs:
     - this planning review
     - approved list of target artifacts
     - final judgment on whether delegated handoff storage stays in `details`
       or becomes top-level schema
     - final wording for the MCP-first plus static-export fallback ladder
   - Expected outputs:
     - bounded planning-stack artifact edits
     - validation evidence
     - continuity updates documenting the new delegated-handoff requirements
     - explicit `grounding-blocked` behavior for delegated lanes when no valid
       grounding path exists

## Evidence

1. Artifact references:
   - `.personakit/Sessions/samwise-squad-planning.session.json`
   - `.personakit/Sessions/pack-gardener-maintenance.session.json`
   - `.personakit/Packs/essentials/multiagent-squad-planning-contract.md`
   - `.personakit/Packs/essentials/squad-planning-report-template.md`
   - `.personakit/Packs/essentials/squad-planning-log-contract.md`
   - `.personakit/Packs/intents/assemble-squad-and-plan-review.intent.json`
   - `.personakit/Packs/directives/assemble-squad-and-plan.directive.json`
   - `.personakit/Packs/directives/tend-packs-and-sessions.directive.json`
   - `.personakit/Packs/personas/samwise.persona.json`
   - `.personakit/Packs/personas/architectural-editor.persona.json`
   - `.personakit/Packs/personas/studio-workflow-operator.persona.json`
   - `.personakit/Packs/personas/pack-gardener.persona.json`
2. Relevant hiring review IDs:
   - None
3. Related planning review ID:
   - `SPR-0005`
4. Related logs or continuity notes:
   - `Docs/PersonaKit/Development/logs/squad-planning-reviews.jsonl`
   - `Docs/PersonaKit/Development/partner-context-log.md`
