# Persona Hiring Routing Contract

Use this essential when a broader planning or remediation workflow may need to
route through hiring without making hiring ambient context for every pass.

## Purpose

1. Keep hiring as an explicit capability boundary inside reusable orchestration
   workflows.
2. Let planning and remediation surfaces name hiring branches clearly without
   inheriting the full hiring context by default.
3. Preserve machine-checkable hiring validation whenever a hiring path is
   actually exercised.

## Routing Rules

When a planning or remediation workflow identifies a hiring need:

1. Route missing or uncertain persona-fit analysis through
   `reverse-interview-persona-fit` or `samwise-persona-hiring`.
2. Route approved hiring-gap closure through `remediate-persona-hiring-gaps` or
   `samwise-persona-hiring-calibration`.
3. Keep the hiring branch tied to the current objective, role boundary, and
   approved remediation scope.

## Explicit Dependency Rule

A reusable workflow that can trigger a hiring branch must state all of the
following explicitly:

1. Which hiring workflow or session owns the branch.
2. That `persona-hiring-core` or the equivalent hiring essentials must be
   active during the hiring branch.
3. That `Scripts/check-persona-hiring-logs.sh` runs whenever the branch writes
   or updates hiring artifacts or hiring-log entries.

## Guardrails

- Do not make hiring standards, research, calibration, or log contracts ambient
  context for non-hiring passes.
- Do not treat hiring recommendations as approval to change pack artifacts
  without AJ review.
- Do not skip hiring-log validation when a branch updates hiring artifacts.
