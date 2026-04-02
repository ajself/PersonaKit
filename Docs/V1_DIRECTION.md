## PersonaKit V1 Direction

### Goal

PersonaKit V1 provides a single command:

```bash
personakit run --session <id> --agent <agent> -- "<task>"
```

That resolves reusable context (persona, kits, directives, essentials) and launches an AI agent with that context applied.

The user should not need to copy/paste prompts or manually reconstruct context.

---

### Core Problem

AI coding tools require repeated setup:

- re-explaining architecture
- reapplying style rules
- restating constraints

This leads to:
- inconsistency
- wasted time
- drift in output quality

---

### V1 Solution

PersonaKit resolves a **named session** into a deterministic context bundle and injects it into an agent invocation.

---

### Success Criteria

PersonaKit V1 is successful if:

- A user can start a task in under 10 seconds
- No manual prompt assembly is required
- The agent output reflects consistent style and constraints
- The workflow feels simpler than using the agent directly

---

### In Scope

- Session-based context resolution
- Deterministic merging of:
  - persona
  - kits
  - directives
  - essentials
- CLI command: `personakit run`
- One agent adapter (Codex OR OpenCode)
- Dry-run support for debugging

---

### Out of Scope

- Memory systems
- Multi-session continuity
- Task orchestration (lead-worker, RPI automation)
- Remote execution platforms
- Team collaboration features
- GUI enhancements (Studio paused)
- Task management systems

---

### Product Principle

PersonaKit is not an agent.

PersonaKit is a **context resolver and launcher**.

It defines *how work should be done*, not *what work to do next*.
