# Multiagent Squad Planning Contract

Use this contract when Samwise needs to turn a new objective into a staffed
multiagent plan before execution begins.

## Purpose

1. Convert an objective into a bounded planning package with explicit owners,
   gates, and next actions.
2. Check whether current personas cover the required roles with enough
   confidence.
3. Identify missing personas, kits, intents, directives, or sessions before
   implementation starts.
4. Keep staffing, planning, and pack-expansion recommendations reviewable and
   workspace-agnostic.

## Required Inputs

1. Objective summary.
2. Workspace or initiative scope.
3. Hard constraints and non-goals.
4. Current artifact set relevant to the objective.

Optional but recommended:

1. Known persona IDs expected to participate.
2. Explicit planning output path.
3. Confidence threshold for role-fit checks (defaults to `80` if omitted).
4. Definition of done for the first execution checkpoint.
5. Required validation expectations or commands.
6. Roles expected to be delegated to spawned agents.
7. Known grounding artifact paths if a static PersonaKit export fallback is
   already available.

## Required Role-Coverage Review

For each new objective, the planning pass must:

1. Identify the roles required to shape, review, and execute the work.
2. Map each role to an existing persona candidate when possible.
3. Mark each role as one of:
   - `covered`
   - `covered-with-gaps`
   - `missing`
4. Record the responsibility boundary for each role:
   - shaping
   - execution
   - review
   - approval
5. Require an explicit owner or explicit missing-role disposition for every
   required role.
6. Trigger reverse-interview analysis when:
   - a required role has no obvious persona owner
   - a candidate role fit is uncertain
   - the role introduces a new domain, delivery mode, or risk profile

## Delegated Handoff Requirements

When a role is expected to be staffed by a spawned agent, the planning pass
must produce a compact delegated handoff packet for that role before execution
handoff is considered ready.

Use `delegated-agent-handoff-template` as the default packet shape.

Each delegated handoff packet should name:

1. Role and owner persona ID.
2. Required session ID or directive ID.
3. Grounding requirement:
   - live PersonaKit MCP first
   - approved static PersonaKit export second for bounded implementation or
     review work
4. PersonaKit context load target:
   - persona
   - directive
   - associated kits
   - associated essentials
5. Objective boundary and write scope.
6. Acceptance criteria.
7. Validation commands or evidence expectations.
8. Stop points and return conditions.
9. Failure disposition when grounding is unavailable:
   - `grounding-blocked`
10. Grounding source path or export source reference.
11. Snapshot date when the grounding mode is `static-export`.

Guardrails:

1. Planning, hiring, remediation, and open-ended discovery work must not
   silently degrade to cached PersonaKit context.
2. Static export fallback is acceptable only for bounded implementation or
   review work.
3. If neither live MCP nor an approved static export is available, the
   delegated lane stops as `grounding-blocked`.
4. Static export fallback should record provenance and freshness so delegated
   lanes can distinguish the intended snapshot from stale cache data.

## Output Contract

Each squad-planning pass should produce:

1. Objective summary and scope boundary.
2. Proposed squad roster with role responsibilities and named owners or
   explicit missing-role dispositions.
3. Role-coverage table with confidence notes.
4. Missing-role and missing-artifact recommendations grouped by type:
   - personas
   - essentials
   - kits
   - intents
   - directives
   - sessions
5. Initial milestone or checkpoint plan with:
   - owners
   - definition of done
   - dependencies
   - review gates
   - validation expectations
   - next actions
6. Delegated handoff packets for any roles expected to be staffed by spawned
   agents.

Required sections:

1. Evidence references.
2. Unknowns and assumptions.
3. Stop points before execution.
4. Recommended first planning or hiring step.
5. Validation plan with owner and command or evidence expectations.
6. Recommended next session for execution or remediation.
7. Handoff status (`awaiting-aj-review`, `ready-for-remediation`,
   `ready-for-execution`, or `blocked`).
8. Delegated grounding status when delegated roles exist.

## Persistence Requirements

Each squad-planning pass should produce one human-readable report using the
shared template plus one machine-readable log entry:

1. Preferred path:
   - explicit `planningOutputPath`
2. Default shared path:
   - `Docs/PersonaKit/Development/planning-reviews/YYYY-MM-DD-<objective>.md`
3. Machine log:
   - append one schema-valid row to
     `Docs/PersonaKit/Development/logs/squad-planning-reviews.jsonl`
4. Fallback:
   - an approved workspace-local planning path when one is already established
5. Otherwise:
   - stop and request AJ guidance before concluding the pass

The report and JSONL entry should agree on:

1. named next session
2. first checkpoint
3. validation owner
4. handoff status
5. delegated handoff summary when delegated roles exist
6. static-export provenance and snapshot date when static fallback is used

## Reverse-Interview Rules

When reverse-interview is required:

1. Use the existing hiring rubric and evidence requirements.
2. Keep the assessment tied to the current objective and role boundary.
3. Recommend the smallest artifact set needed to close the top gap.
4. Do not treat a reverse-interview verdict as approval to apply structural
   changes without AJ review.
5. For any newly proposed persona that is likely required for execution,
   complete at least one reverse-interview pass before execution handoff.
6. If an execution-critical role remains `missing` or `covered-with-gaps` after
   reverse interview, route the next session to
   `samwise-squad-planning-remediation`, `samwise-persona-hiring`, or another
   explicit approved remediation loop before execution.

## Stop Gates

Stop and request AJ review before:

1. Creating or modifying personas, kits, directives, intents, or sessions.
2. Promoting the plan into execution handoff.
3. Expanding scope beyond the declared objective.
4. Treating a low-confidence role fit as execution-ready.
5. Leaving a required role without an owner or explicit missing-role
   disposition.
6. Concluding the pass without a durable report, JSONL entry, validation owner,
   and named next session.
7. Handing delegated work to execution without an explicit handoff packet and
   grounding path.

## Guardrails

- Keep the workflow reusable across workspaces; do not hard-code one product or
  initiative into the contract.
- Prefer the smallest sufficient squad over speculative staffing.
- Keep missing-role recommendations explicit and prioritized.
- Do not collapse planning, hiring, and execution into one uninterrupted pass.
- Require explicit definition-of-done and validation evidence before execution
  handoff.
- Require a durable planning report, a schema-valid planning log entry, and a
  named next-session handoff before treating the pass as complete.
- Require delegated roles to carry explicit grounding instructions; do not
  assume spawned agents will infer PersonaKit context from slim prompts.
- Respect active commit authorization policy and stop points.
