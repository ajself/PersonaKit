# Squad Planning Review: Workstream Routing Canary

Date: `2026-03-11`  
Objective: Exercise the new workstream-routing projection with one bounded
planning canary so planning, loop, and retrospective artifacts can share the
same derived route summary.  
Workspace or initiative scope: `PersonaKit` workstream-routing exemplar only  
Session ID: `samwise-squad-planning`  
Reviewer: `AJ`  
Handoff status: `awaiting-aj-review`

## Objective Boundary

1. Goal summary:
   - Produce one documentation-only planning canary that proves reports and
     logs can project directive-owned workstream routing without changing
     session-file semantics.
2. In scope:
   - one planning review
   - one planning JSONL row
   - one loop JSONL row
   - one retrospective report and JSONL row
3. Out of scope:
   - live feature delivery
   - session schema changes
   - new top-level PersonaKit artifact types
4. Hard constraints:
   - keep directive workstream metadata authoritative
   - treat projected workstream fields as derived visibility only
   - do not mutate existing live project records

## Proposed Squad

1. Role:
   - Owner: `samwise`
   - Responsibility boundary: shaping and planning review
   - Why this owner: the canary starts in the planning lane and should stop at
     the normal AJ gate
2. Role:
   - Owner: `worktree-squad-lead`
   - Responsibility boundary: loop and retrospective exemplar ownership
   - Why this owner: the canary should exercise the real worktree-squad log
     surfaces without implying live feature delivery
3. Role:
   - Owner: `pack-gardener`
   - Responsibility boundary: docs and contract normalization
   - Why this owner: the feature is mostly artifact and contract hardening
4. Role:
   - Owner: `AJ`
   - Responsibility boundary: approval
   - Why this owner: the canary should still stop at the standard review gate

## Role Coverage Review

1. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: `samwise-squad-planning` is the active planning session
   - Reverse-interview required: No
2. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: `worktree-squad-lead` owns the loop and retrospective sessions
   - Reverse-interview required: No
3. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: `pack-gardener-maintenance` owns bounded pack/session/doc maintenance
   - Reverse-interview required: No
4. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: AJ review gate remains required
   - Reverse-interview required: No

## Missing Roles And Artifact Gaps

1. Missing role or gap:
   - Recommended artifact type: `none`
   - Priority: Low
   - First implementation step: use the canary only as a reusable example for
     future workstream-aware planning and closeout passes

## First Checkpoint Plan

1. Checkpoint or milestone:
   - Owner: `samwise`
   - Definition of done:
     - the planning report includes a derived workstream routing section
     - the planning JSONL row includes a schema-valid `workstream` object
     - the loop and retrospective canaries carry the same derived routing shape
     - compatibility fields agree with the derived workstream object
   - Dependencies:
     - directive-owned `worktree-squad-lifecycle` metadata
     - updated planning/worktree log schemas and check scripts
     - session-facing workstream directory docs
   - Review gate:
     - AJ confirms the canary is clear enough to reuse
   - Validation owner:
     - `samwise`
   - Validation commands or evidence:
     - `swift run personakit validate --root .personakit`
     - `Scripts/check-squad-planning-logs.sh`
     - `Scripts/check-worktree-squad-logs.sh`

## Delegated Agent Handoff Packets

1. Role:
   - Owner persona ID: `none`
   - Required session or directive: `none`
   - Grounding mode: `none`
   - Static export path (if any):
   - Grounding source path:
   - Snapshot date (if static export):
   - Snapshot revision marker (if any):
   - Write scope: `Documentation-only canary`
   - Acceptance criteria:
     - no delegated execution begins from this canary
   - Validation commands or evidence:
     - `swift run personakit validate --root .personakit`
   - Stop points:
     - keep the canary bounded to planning/log/session-facing artifacts
   - Failure disposition:
     - `not-applicable`

## Unknowns And Risks

1. The canary proves artifact shape and routing clarity, but it does not prove
   live workflow adoption discipline on future product work.
2. If future entries copy the canary mechanically without updating session or
   routing context, the new fields could become ceremony rather than clarity.

## Recommended Next Session

1. Session ID:
   - Why next: `samwise-worktree-squad-oversight` is the routed next phase in
     the worktree-squad lifecycle
   - Required closeout session (if any): `worktree-squad-retrospective`
   - Expected inputs:
     - this planning review
     - updated log contracts and check scripts
     - the workstream directory and session directory
   - Expected outputs:
     - one documentation-only loop canary with derived workstream routing

## Workstream Routing

1. Workstream:
   - Id: `worktree-squad-lifecycle`
   - Phase: `planning`
   - Current session: `samwise-squad-planning`
   - Entry session: `samwise-squad-planning`
   - Next sessions:
     - `samwise-worktree-squad-oversight`
   - Required closeout session:
     - `worktree-squad-retrospective`

## Evidence

1. Artifact references:
   - `.personakit/Sessions/samwise-squad-planning.session.json`
   - `.personakit/Sessions/samwise-worktree-squad-oversight.session.json`
   - `.personakit/Sessions/worktree-squad-delivery.session.json`
   - `.personakit/Sessions/worktree-squad-retrospective.session.json`
   - `.personakit/Sessions/rosie-retrospective-garden.session.json`
   - `Docs/PersonaKit/Development/workstream-directory.md`
   - `Docs/PersonaKit/Development/session-directory.md`
   - `Docs/PersonaKit/Development/logs/squad-planning-reviews.schema.json`
   - `Docs/PersonaKit/Development/logs/worktree-squad-loops.schema.json`
   - `Docs/PersonaKit/Development/logs/worktree-squad-retrospectives.schema.json`
2. Relevant hiring review IDs:
   - None
3. Related planning review ID:
   - `SPR-0007`
4. Historical evidence or continuity notes (optional; not active authority):
   - `Docs/PersonaKit/Development/logs/squad-planning-reviews.jsonl`
