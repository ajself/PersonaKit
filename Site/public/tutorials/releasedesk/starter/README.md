# ReleaseDesk Starter

ReleaseDesk is a tiny release-readiness dashboard for a small software team.
It lists launch tasks, tracks blockers, and decides whether a release is ready.

This starter has two deliberate problems:

- The readiness calculation ignores incomplete security tasks.
- The filtered task list has no helpful empty state.

It also includes a host-neutral skill at
`host-skills/releasedesk-readiness/SKILL.md`. The tutorial uses that skill
first, then adds PersonaKit contracts around when the skill is allowed.

Run it locally:

```bash
open index.html
node test/run-tests.mjs
```

The starter test is expected to fail until you fix the readiness logic.
