# Squad Planning Review: Generic Samwise Workflow Bootstrap

Date: `2026-03-09`  
Objective: Establish generic Samwise squad-planning infrastructure so new
product briefs can be staffed, validated, and handed off cleanly.  
Workspace or initiative scope: `PersonaKit` root workflow infrastructure  
Session ID: `samwise-squad-planning`  
Reviewer: `AJ`  
Handoff status: `awaiting-aj-review`

## Objective Boundary

1. Goal summary:
   - Add durable planning logs, a missing-role remediation loop, and one
     reusable orchestration kit for Samwise-led product work.
2. In scope:
   - Planning persistence contract and checker
   - Generic role-gap remediation workflow
   - Default Samwise orchestration kit
3. Out of scope:
   - Starting Orbit implementation
   - Approving new execution personas without reverse-interview evidence
   - Handing work to execution before AJ reviews this planning stack
4. Hard constraints:
   - Reuse existing PersonaKit hiring and squad-delivery loops
   - Keep the workflow reusable across workspaces
   - Require deterministic logs and named next sessions

## Proposed Squad

1. Role:
   - Owner: `samwise`
   - Responsibility boundary: shaping, planning orchestration, validation owner
   - Why this owner: Samwise is the Trusted Partner persona that already owns
     planning, hiring, and delivery handoff quality
2. Role:
   - Owner: `pack-gardener`
   - Responsibility boundary: log-contract hygiene and maintenance review
   - Why this owner: Rosie already owns deterministic pack/session maintenance
     and log integrity patterns
3. Role:
   - Owner: `AJ`
   - Responsibility boundary: approval and stop-point review
   - Why this owner: structural pack expansion and execution handoff remain
     human-gated

## Role Coverage Review

1. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: Samwise partner, hiring, and worktree-squad workflows already
     exist
   - Reverse-interview required: No
2. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: Rosie gardening contracts, validators, and event streams already
     exist
   - Reverse-interview required: No
3. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: AJ approval gates are explicit in existing directives and logs
   - Reverse-interview required: No

## Missing Roles And Artifact Gaps

1. Missing role or gap:
   - Recommended artifact type: `squad-planning-log-contract`
   - Priority: High
   - First implementation step: add schema/jsonl/checker and wire the planning
     directive to append entries
2. Missing role or gap:
   - Recommended artifact type: `remediate-squad-role-coverage-gaps`
   - Priority: High
   - First implementation step: add a generic remediation loop that routes
     missing personas through reverse-interview and hiring calibration before
     execution
3. Missing role or gap:
   - Recommended artifact type: `samwise-orchestration-core`
   - Priority: High
   - First implementation step: bundle planning, hiring, delivery, and
     retrospective expectations into one reusable default kit

## First Checkpoint Plan

1. Checkpoint or milestone:
   - Owner: `samwise`
   - Definition of done:
     - planning passes write markdown plus JSONL
     - missing or uncertain roles name a remediation loop before execution
     - Samwise default context includes one orchestration kit for this lifecycle
   - Dependencies:
     - existing hiring logs
     - existing worktree squad contracts
     - current partner-trust stop gates
   - Review gate:
     - AJ reviews workflow additions before execution handoff
   - Validation owner:
     - `samwise`
   - Validation commands or evidence:
     - `swift run personakit validate --root .personakit`
     - `Scripts/check-persona-hiring-logs.sh`
     - `Scripts/check-squad-planning-logs.sh`

## Unknowns And Risks

1. `Scripts/check-gardening-logs.sh` still reports pre-existing stale
   pack-coverage snapshot counts, so gardening telemetry remains partially out
   of date even after this workflow hardening.

## Recommended Next Session

1. Session ID:
   - Why next: `samwise-squad-planning` should be used on the first real product
     brief, with `samwise-squad-planning-remediation` reserved for any
     execution-critical missing-role loop that planning uncovers
   - Expected inputs:
     - objective summary
     - artifact paths
     - constraints
     - known personas
   - Expected outputs:
     - staffed squad
     - durable planning report + JSONL entry
     - named remediation or execution handoff session

## Evidence

1. Artifact references:
   - `.personakit/Packs/essentials/multiagent-squad-planning-contract.md`
   - `.personakit/Packs/essentials/squad-planning-report-template.md`
   - `.personakit/Packs/essentials/squad-planning-log-contract.md`
   - `.personakit/Packs/intents/assemble-squad-and-plan-review.intent.json`
   - `.personakit/Packs/intents/remediate-squad-role-coverage-gaps.intent.json`
   - `.personakit/Packs/directives/assemble-squad-and-plan.directive.json`
   - `.personakit/Packs/directives/close-squad-role-coverage-gap-loop.directive.json`
   - `.personakit/Packs/kits/samwise-orchestration-core.kit.json`
   - `.personakit/Sessions/samwise-squad-planning.session.json`
   - `.personakit/Sessions/samwise-squad-planning-remediation.session.json`
2. Relevant hiring review IDs:
   - None for bootstrap
3. Related planning review ID:
   - `SPR-0001`
4. Related logs or continuity notes:
   - `Docs/PersonaKit/Development/logs/squad-planning-reviews.jsonl`
   - `Docs/PersonaKit/Development/partner-context-log.md`
   - `Docs/PersonaKit/Development/pack-gardener-log.md`
