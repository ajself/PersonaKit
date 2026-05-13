# V1 Boundaries

PersonaKit V1 resolves a deterministic operating contract and launches one explicitly selected supported agent adapter.

Stay inside these boundaries:

- Use sessions as stable entry points.
- Validate authored PersonaKit data before running work.
- Use dry-run output to inspect the runtime payload before launching an agent.
- Do not add workflow orchestration, memory, persistence, or multi-agent control flow.
- Stop for human review before adding new execution behavior.
