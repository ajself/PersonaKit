# Multiagent Squad Planning Contract

Use this runtime contract when Samwise turns a new objective into a staffed
multiagent plan.
For deeper examples and rationale, see `multiagent-squad-planning-reference`.

## Purpose

1. Turn an objective into a bounded planning package with explicit owners, gates, and next actions.
2. Make role coverage explicit before execution begins.
3. Keep planning, hiring, and remediation decisions reviewable and workspace-aware.

## Active Authority Rule

1. Active operating rules come from the resolved session stack, not from continuity logs alone.
2. If a required planning rule exists only in a log, promote it into an active artifact before execution handoff.

## Required Planning Output

Each planning pass should produce:

1. Objective summary and scope boundary.
2. Role coverage with explicit owners or explicit missing-role disposition.
3. Missing artifact recommendations grouped by type.
4. First checkpoint plan with definition of done, dependencies, review gates, and validation expectations.
5. Named next session, required closeout session when applicable, and handoff status.

## Delegated Handoff Packet

When a role will be staffed by a spawned agent, include:

1. One authoritative operating persona.
2. Required session or directive.
3. Grounding mode and source:
   - live PersonaKit MCP first
   - approved static export only for bounded implementation or review work
4. Write scope, acceptance criteria, validation expectations, and stop points.
5. Failure disposition:
   - `grounding-blocked`

## Guardrails

1. Planning and hiring work must not silently degrade to cached PersonaKit context.
2. If valid grounding is unavailable for a delegated lane, stop as `grounding-blocked`.
3. Static export fallback is acceptable only for bounded implementation or review work.
4. Stop for AJ review before structural pack changes or execution handoff.

## Persistence

1. Write the human report using `squad-planning-report-template`.
2. Append the machine-readable entry using `squad-planning-log-contract`.
3. Keep the report and JSONL entry aligned on next session, closeout routing, and delegated handoffs.
