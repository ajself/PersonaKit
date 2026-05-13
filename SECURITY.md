# Security Policy

Status: Active
Owner: Maintainers
Last Reviewed: 2026-05-12

## Supported Versions

PersonaKit is preparing its first public V1. Until a `1.0.0` release exists, security fixes are handled on `main`.

## Reporting A Vulnerability

Please do not open a public issue for a suspected vulnerability.

Report privately through GitHub private vulnerability reporting for this repository. If that option is not visible, open a minimal public issue asking for a security contact and do not include exploit details in the issue body.

Maintainers should enable GitHub private vulnerability reporting before making the repository public.

Include:

- affected version or commit
- operating system and Swift version
- reproduction steps
- expected and actual behavior
- whether the issue can cause file mutation, command execution, credential exposure, or unsafe agent invocation

## Security Model

PersonaKit V1 is designed to stay execution-light.

- MCP is read-only grounding.
- `personakit run` is the only V1 execution path.
- `personakit run` launches one explicitly selected supported agent adapter.
- PersonaKit does not provide a workflow engine, memory system, remote execution platform, or autonomous agent loop.

Security-sensitive changes should preserve those boundaries.
