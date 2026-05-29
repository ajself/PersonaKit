# PersonaKit Examples

This directory contains runnable example PersonaKit roots.

Today it has one canonical example:

- `public-starter/` - the first-five-minutes starter root used by the README,
  `personakit init`, and public validation.

The actual PersonaKit authored source lives under
`public-starter/.personakit/`. That directory is intentionally hidden because
real projects store PersonaKit roots in `.personakit/` too. Keeping the example
in that shape makes the commands honest: validation, contract inspection,
dry-run payloads, and adapter launches all use the same path shape a project
would use.

`public-starter/.personakit/` is also the reference content for
`personakit init`. If the generated starter content changes, this example and
the init manifest should stay in sync.

Start here:

```bash
swift run personakit validate --root Examples/public-starter/.personakit
swift run personakit contract --root Examples/public-starter/.personakit --session solo-dev
swift run personakit run --root Examples/public-starter/.personakit --session solo-dev --agent opencode --dry-run -- "Make a small, reviewable CLI improvement."
```
