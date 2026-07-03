# CLI Change Checklist

This grounding skill body is surfaced when its trigger rules match (see `cli-change-checklist.skill.json`). A grounding skill is a `.skill.json` metadata file with trigger rules paired with this `.md` body.

- Confirm the change stays inside the requested CLI task.
- Keep output ordering deterministic.
- Add or update tests alongside the change.
- Run `personakit validate` before handing off.

Replace this checklist with your own guidance, or scaffold new grounding skills with `personakit create skill`.
