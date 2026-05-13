# Public V1 Release Checklist

Status: Draft
Owner: Maintainers
Last Reviewed: 2026-05-12

Use this checklist before making PersonaKit public.

## Required Checks

- GitHub private vulnerability reporting is enabled.
- GitHub Actions CI is green.
- `swift test` passes locally or in CI.
- `swift run personakit validate --root Examples/public-starter/.personakit` reports zero errors.
- `swift run personakit validate --root .personakit` reports zero errors and `diff -qr .personakit Examples/public-starter/.personakit` reports no differences.
- `swift run personakit run --root Examples/public-starter/.personakit --session solo-dev-v1 --agent opencode --dry-run -- "Make a small, reviewable CLI improvement."` succeeds.
- `swift run personakit init /tmp/personakit-public-v1-check/.personakit` creates a root where `solo-dev-v1` validates and dry-runs.
- `swift run personakit init` refuses a non-empty destination unless `--force` is provided.
- Root `.personakit` contains only public starter content; internal agent context lives under `Fixtures/internal-agent-root/.personakit`.
- `Fixtures/kit-root` remains a legacy Codex-only fixture: it validates, and `personakit run --agent opencode` against `senior-swiftui-engineer_apply-style` is expected to fail authorization.
- Fake `opencode` adapter launch tests cover argv, payload file contents, exit-code propagation, and missing executable handling.
- `swift run personakit --help` and `swift run personakit run --help` match the README examples.
- Studio review artifacts are fresh enough to inspect core states without treating Studio as a V1 release blocker.
- `git status --short` has no generated archives, scratch workunit directories, private editor config, or local release config staged for release.

The local shortcut is:

```bash
make public-v1-check
```

## Public Wording Sweep

Scan public docs for hard failures before release:

```bash
! rg -n "AJ|Orbit|Taskboard|architectural-editor|Studio release|workflow platform" .personakit README.md Docs Examples CONTRIBUTING.md SECURITY.md CHANGELOG.md AGENTS.md -g "!Docs/PUBLIC_V1_RELEASE_CHECKLIST.md"
```

Scan boundary wording for intentional non-goal mentions:

```bash
rg -n "memory|orchestration" .personakit README.md Docs Examples CONTRIBUTING.md SECURITY.md CHANGELOG.md AGENTS.md -g "!Docs/PUBLIC_V1_RELEASE_CHECKLIST.md"
```

Expected public wording:

- No private names or local-only session examples.
- No Orbit or Taskboard residue.
- No wording that presents Studio packaging as a V1 release blocker.
- Any mention of memory or orchestration appears only as an explicit non-goal.
