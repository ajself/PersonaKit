# CLI Change Checklist

This reference body is surfaced when its trigger rules match (see `cli-change-checklist.reference.json`). A reference is a `.reference.json` metadata file paired with this `.md` body.

- Confirm the change stays inside the requested CLI task.
- Keep output ordering deterministic.
- Add or update tests alongside the change.
- Run `personakit validate` before handing off.

Replace this checklist with your own guidance, or scaffold new references with `personakit create reference`.
