# ReleaseDesk Complete

This is the completed version of the ReleaseDesk tutorial sample.

It includes:

- fixed release-readiness logic
- a useful empty state for filters with no matching tasks
- a host-neutral ReleaseDesk readiness skill under `host-skills/`
- a completed public PersonaKit root under `personakit-root/`

Run it locally:

```bash
open index.html
node test/run-tests.mjs
personakit validate --root personakit-root
```
