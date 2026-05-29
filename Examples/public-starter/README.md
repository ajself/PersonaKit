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

Export handoff context:

```bash
swift run personakit export --root Examples/public-starter/.personakit --session solo-dev
```

Copy handoff context:

```bash
swift run personakit export --root Examples/public-starter/.personakit --session solo-dev --copy
```

Paste the copied context into the coding tool you use for the actual work.

## Expected Export Shape

The export output starts with deterministic contract context:

```text
PersonaKit-Output-Version: 1

# Persona
Name: Solo Developer
Id: solo-developer
```

The output then includes the resolved skill contract, essentials, directive, and
any matched references.
