# Persona Hiring Routing Contract

Use this runtime contract when planning or remediation may need a hiring branch.

## Routing Rules

1. Route missing or uncertain persona-fit analysis through
   `reverse-interview-persona-fit` or `samwise-persona-hiring`.
2. Route approved hiring-gap closure through
   `remediate-persona-hiring-gaps` or `samwise-persona-hiring-calibration`.
3. Keep the hiring branch tied to the current objective, role boundary, and
   approved remediation scope.

## Explicit Dependency Rule

Any reusable workflow that can trigger a hiring branch must name:

1. the hiring workflow or session that owns the branch
2. the active hiring context for that branch
3. `Scripts/check-persona-hiring-logs.sh` whenever hiring artifacts or logs are
   updated

## Guardrails

- Do not make hiring standards, research, calibration, or log contracts ambient
  context for non-hiring passes.
- Do not treat hiring recommendations as approval to change pack artifacts
  without AJ review.
- Do not skip hiring-log validation when a branch updates hiring artifacts.
