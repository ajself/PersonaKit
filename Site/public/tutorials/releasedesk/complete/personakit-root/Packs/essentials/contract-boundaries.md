# Contract Boundaries

ReleaseDesk is a tiny release-readiness dashboard. Agent work must stay inside
the current task and the resolved session boundary.

Shared rules:

- Inspect the resolved contract before asking an agent to act.
- Keep implementation changes focused on the approved product behavior.
- Report validation results and residual risk.
- Stop before deployment, release tags, notarization, credential changes, or
  new execution behavior.
- Do not add workflow orchestration, memory, persistence, or multi-agent control
  flow.

