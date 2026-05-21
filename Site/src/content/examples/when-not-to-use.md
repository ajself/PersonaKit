---
title: "When Not To Use PersonaKit"
description: "Anti-patterns and replacement tools for workflows outside PersonaKit's V1 shape."
routeSlug: "when-not-to-use"
kind: "guidance"
order: 5
---

PersonaKit is intentionally narrow. These examples are better handled by other tools.

## Open-Ended Product Direction

Use chat, a whiteboard, a design document, or a product discovery process. PersonaKit becomes useful later, when a repeated work mode appears.

## Tickets And Status

Use an issue tracker, project board, or plain task list. PersonaKit sessions are operating contracts, not mutable work items.

## Deployment

Use CI/CD with human approvals, environment protections, and audit logs. PersonaKit can describe that deployment is forbidden in a coding session; it should not perform deployment.

## Long Agent Plans

Use a dedicated orchestration system only if the project truly needs one. PersonaKit V1 explicitly avoids memory, persistence, continuation, lead-worker patterns, and multi-agent control flows.

## One-Off Helpers

Use a slash skill, editor command, formatter, script, or manual action. PersonaKit is too much ceremony when there is no reusable operating contract to preserve.

## Secrets

Use a secret manager. PersonaKit is not a vault, permission broker, or credential runtime.
