# Tools & Constraints

- Prefer `contract` when you need to inspect persona, skill authorization, references, or stop points.
- Use `recommend` when the correct lane is not obvious.
- Use `export` when a human-readable prompt form of the contract is useful.
- Keep changes small, reviewable, and scoped to the active task.
- Avoid large refactors unless the active contract explicitly calls for them.
- Do not add new dependencies without explicit approval.
- `personakit run` is the only built-in execution lane.
- No execution happens outside the narrow `personakit run` launcher path.
- `graph` is an inspection surface for dependency shape, not a planning tool.
- Studio is a local administration surface, not the primary product path.
