# AGENTS.md — Working With PersonaPad

This document defines how **automated agents (e.g. Codex)** and human contributors
should interact with the PersonaPad codebase.

It exists to:
- preserve product intent
- protect scope and determinism
- prevent well-meaning overengineering
- keep the project boring, reliable, and maintainable

If an agent or contribution conflicts with this document, **this document wins**.

---

## Project Identity (Non-Negotiable)

PersonaPad is a **local, deterministic utility**.

It is:
- file-based
- schema-driven
- offline
- boring on purpose

It is **not**:
- a platform
- a runtime
- an execution engine
- a cloud service
- a chat client
- an AI product in the startup sense

Any agent operating on this repository must respect this framing.

---

## Source of Truth

All agent behavior is constrained by the project’s scope contract:

- **[PersonaPad v1 Scope & Contract](Docs/PersonaPad_v1_Scope_and_Contract.md)**

If present, v2 exploration intent is captured in:
- **[PersonaPad v2 Draft](Docs/Drafts/PersonaPad_v2_DRAFT.md)**

Agents must not propose or implement changes that violate that contract,
even if technically feasible or seemingly useful.

---

## What Agents Are Allowed To Do

Automated agents may be used for work that **hardens trust** and **reduces entropy**.

Good uses include:
- improving determinism
- increasing CLI ↔ app parity
- adding or strengthening tests
- clarifying error messages
- simplifying code paths
- removing dead or speculative abstractions
- improving documentation accuracy
- tightening release tooling and scripts

Agents are especially valuable for:
- repetitive refactors
- test coverage
- verification tasks
- release readiness checks

---

## What Agents Must Not Do

Agents must **not**:

- add new product features without explicit direction
- introduce execution, chat, or provider integration
- introduce network access or dependencies that require it at runtime
- add cloud sync, accounts, telemetry, or analytics
- invent new abstractions “for flexibility”
- expand schema semantics without a versioned proposal
- add inheritance, composition, or “smart” behavior
- optimize prompts or rewrite user content
- add configuration surfaces that increase support burden

If a change increases scope, cleverness, or surprise, it is likely wrong.

---

## Schema & Determinism Rules

PersonaPad’s core value depends on **deterministic behavior**.

Agents must ensure:
- same persona + same inputs → identical output
- section ordering is fixed and documented
- defaults are explicit, not inferred
- no hidden mutation or reordering occurs

Schema rules:
- Schema v1 is stable
- Unsupported fields (e.g. `extends`, `systemAppend`) are **explicitly rejected**
- Invalid input must fail loudly and clearly
- Schema evolution must be versioned and intentional

---

## Opinionated by Design

PersonaPad is opinionated about:
- structure
- validation
- failure modes

Agents should **not** attempt to:
- add free-form prompt modes
- make validation optional
- “helpfully” recover from invalid input
- infer user intent

Clarity beats convenience.

---

## macOS App vs CLI Expectations

The macOS app and CLI must:
- share core logic
- produce identical output for identical inputs
- diverge only in presentation, not behavior

Agents should prefer:
- refactoring shared logic into `PersonaPadCore`
- adding parity tests when touching either surface

---

## How Agents Should Propose Work

When an agent proposes changes, it should:
1. State which constraint(s) it is reinforcing
2. State which scope boundary it is *not* crossing
3. Prefer small, reversible changes
4. Avoid speculative future-proofing

If a proposal cannot justify itself in these terms, it should not proceed.

---

## Release-Oriented Mindset

PersonaPad values:
- boring releases
- calm usage
- predictable behavior

Agents should optimize for:
- fewer surprises
- fewer knobs
- fewer edge cases
- fewer promises

If a change makes the project feel more exciting, pause.

---

## Living Document

This file is expected to evolve.

When updating `AGENTS.md`:
- prefer tightening language over expanding it
- record intent, not implementation
- assume future agents will not have full context

This document exists to protect future-you.

---

## Git

- Use Conventional Commits for messages. The spec is as follows:
  ```markdown
  The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHALL”, “SHALL NOT”, “SHOULD”, “SHOULD NOT”, “RECOMMENDED”, “MAY”, and “OPTIONAL” in this document are to be interpreted as described in RFC 2119.

  Commits MUST be prefixed with a type, which consists of a noun, feat, fix, etc., followed by the OPTIONAL scope, OPTIONAL !, and REQUIRED terminal colon and space.
  The type feat MUST be used when a commit adds a new feature to your application or library.
  The type fix MUST be used when a commit represents a bug fix for your application.
  A scope MAY be provided after a type. A scope MUST consist of a noun describing a section of the codebase surrounded by parenthesis, e.g., fix(parser):
  A description MUST immediately follow the colon and space after the type/scope prefix. The description is a short summary of the code changes, e.g., fix: array parsing issue when multiple spaces were contained in string.
  A longer commit body MAY be provided after the short description, providing additional contextual information about the code changes. The body MUST begin one blank line after the description.
  A commit body is free-form and MAY consist of any number of newline separated paragraphs.
  One or more footers MAY be provided one blank line after the body. Each footer MUST consist of a word token, followed by either a :<space> or <space># separator, followed by a string value (this is inspired by the git trailer convention).
  A footer’s token MUST use - in place of whitespace characters, e.g., Acked-by (this helps differentiate the footer section from a multi-paragraph body). An exception is made for BREAKING CHANGE, which MAY also be used as a token.
  A footer’s value MAY contain spaces and newlines, and parsing MUST terminate when the next valid footer token/separator pair is observed.
  Breaking changes MUST be indicated in the type/scope prefix of a commit, or as an entry in the footer.
  If included as a footer, a breaking change MUST consist of the uppercase text BREAKING CHANGE, followed by a colon, space, and description, e.g., BREAKING CHANGE: environment variables now take precedence over config files.
  If included in the type/scope prefix, breaking changes MUST be indicated by a ! immediately before the :. If ! is used, BREAKING CHANGE: MAY be omitted from the footer section, and the commit description SHALL be used to describe the breaking change.
  Types other than feat and fix MAY be used in your commit messages, e.g., docs: update ref docs.
  The units of information that make up Conventional Commits MUST NOT be treated as case sensitive by implementors, with the exception of BREAKING CHANGE which MUST be uppercase.
  BREAKING-CHANGE MUST be synonymous with BREAKING CHANGE, when used as a token in a footer.
  ```
- ABSOLUTELY NEVER run destructive git operations (e.g., git reset --hard, rm, git checkout/git restore to an older commit) unless the user gives an explicit, written instruction in this conversation. Treat these commands as catastrophic; if you are even slightly unsure, stop and ask before touching them.
- Never use git restore (or similar commands) to revert files you didn't author—coordinate with other agents instead so their in-progress work stays intact.
- Always double-check git status before any commit.
- Keep commits atomic: commit only the files you touched and list each path explicitly. For tracked files run `git commit -m "<scoped message>" -- path/to/file1 path/to/file2`. 
- For brand-new files, use the one-liner `git restore --staged :/ && git add "path/to/file1" "path/to/file2" && git commit -m "<scoped message>" -- path/to/file1 path/to/file2`.
- Quote any git paths containing brackets or parentheses (e.g., src/app/[candidate]/**) when staging or committing so the shell does not treat them as globs or subshells.
- When running git rebase, avoid opening editors—export GIT_EDITOR=: and GIT_SEQUENCE_EDITOR=: (or pass --no-edit) so the default messages are used automatically.
- Never amend commits unless you have explicit written approval in the task thread.
