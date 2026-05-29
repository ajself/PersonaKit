# Public Starter Example

This is the canonical first-five-minutes PersonaKit root. It is a runnable
example, and it also mirrors the starter content created by `personakit init`.

The PersonaKit authored source is intentionally inside `.personakit/`, matching
the shape used by real projects. The example stays small, solo-developer
oriented, and free of private project context.

## Run It From The Repository Root

Validate the example:

```bash
swift run personakit validate --root Examples/public-starter/.personakit
```

Inspect the resolved contract:

```bash
swift run personakit contract --root Examples/public-starter/.personakit --session solo-dev
```

Preview the runtime payload without launching an agent:

```bash
swift run personakit run --root Examples/public-starter/.personakit --session solo-dev --agent opencode --dry-run -- "Make a small, reviewable CLI improvement."
```

Launch the configured adapter:

```bash
swift run personakit run --root Examples/public-starter/.personakit --session solo-dev --agent opencode -- "Make a small, reviewable CLI improvement."
```

OpenCode must be installed and available on `PATH` for non-dry-run launches.

## Expected Dry-Run Shape

The dry-run output starts with a deterministic runtime payload:

```text
# PersonaKit Runtime Payload

## Resolution
- session: solo-dev
- persona: solo-developer
- directive: small-cli-change
- kits: [cli-guardrails]
```

The payload then includes the resolved operating contract followed by the task text.
