# Contract Boundaries

PersonaKit resolves a deterministic operating contract and exports handoff context for another coding tool.

Stay inside these boundaries:

- Use sessions as stable entry points.
- Validate authored PersonaKit data before handing context to another tool.
- Use `personakit contract` to inspect structured resolution output.
- Use `personakit export` to produce handoff context.
- Do not add workflow orchestration, memory, persistence, or multi-agent control flow.
- Stop for human review before adding new execution behavior.
