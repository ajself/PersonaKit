# PersonaKit, Or: How a Codebase Learned to Keep Its Promises

*Feature draft for an iOS engineering audience, edited in a Studs Terkel-inspired oral-history style*

## Deck

From a single commit on January 23, 2026 to a local-first, deterministic toolchain by March 6, PersonaKit became a working record of reviewer-led AI development: one human shaping intent and review, one agent accelerating execution, and a codebase that kept choosing clarity over convenience.

## Byline

Date: 2026-03-07  
Source window: `2026-01-23` to `2026-03-06` (`306` commits)

---

There are projects that arrive with a slogan. This one arrived with a question.

Not, "Can we ship faster?"  
The better question: "Can we move fast and still trust what we built yesterday?"

PersonaKit starts on **January 23, 2026** with `chore: initial commit` (`aec0ff8`). The early work is modest on paper: persona metadata helpers, parsing tests, filtering, docs cleanup. But the rhythm is already there: code, test, docs, repeat.

That rhythm matters. You can hear it before you can diagram it.

## Act I: The First Spine (Jan 23 to Jan 24)

The earliest commits establish the social contract of the repo:

- behavior should be testable
- docs should describe what is true now
- app and CLI should not drift into separate realities

Then the architecture commits land:

- `feat: add dependency clients scaffold`
- `refactor(app): migrate to UDF store and @Observable`
- `refactor(core): route IO through FileClient`
- `refactor(cli): route filesystem access through dependencies`

For iOS engineers, this is familiar terrain. The team moved side effects to seams. It made state explicit. It gave the code somewhere honest to stand.

In plain terms: this was the first decision to build for tomorrow's debugging session, not just today's demo.

## Act II: Rename, Expand, Retreat (Jan 24 to Jan 26)

On January 24, PersonaPad becomes PersonaKit (`150dbbe`, `cd5fafb`). That rename is not branding theater. It marks intent: this is a kit for context, not a single UI shell.

Then the AppOps chapter appears and disappears. It grows quickly, acquires structure, then gets removed (`772d558`).

That is not failure. That is editing.

A healthy codebase knows when to cut a scene that no longer serves the story.

## Act III: "Blow It Up. Build It Up." (Jan 30 to Jan 31)

Commit `56b1264` reads like a front-page headline: **"Blow it up. Build it up."**

From there, PersonaKit is rebuilt as a tighter system:

- stronger CLI core (`init`, `list`, `describe`, `validate`, `export`, `graph`)
- schema validation as a first-class gate
- deterministic output harnesses

MCP arrives as a serious interface (`e9b4952`, `9013394`). Then the stack simplifies: Swift MCP direction in, Node adapter out (`be33a58`, `059778b`).

The throughline is clear: fewer moving parts, clearer responsibility.

## Act IV: The Scope Problem Is Born (Feb 1 to Feb 2)

By early February, the repo can discover project and global roots, merge scopes, and accept overrides. Powerful, useful, and slightly dangerous.

Because the real question is not "can you find context?" It is "which context wins when two are valid?"

That tension sits quietly for weeks. Then later it becomes the bug everyone can feel but nobody wants to keep.

## Act V: Studio and the Refactor Marathon (Feb 14 to Feb 17)

Mid-February is where the story widens.

Studio lands in milestones:

- workspace loading
- session editing
- preview flow
- raw JSON editing
- diagnostics
- essentials editing

Then FOSA-era refactors hit in waves: shared/core/workspace boundaries, feature-model extraction, panel decomposition, test reorganization.

A lot changed fast, but the pattern stayed disciplined:

1. extract one boundary
2. verify behavior
3. split further
4. repeat

This is how you survive large SwiftUI+CLI refactors without losing the plot.

## Act VI: Ergonomics Catch Up (Feb 17 to Feb 24)

After deep structural work, the product starts sounding like people use it:

- detail refresh behavior improves
- action bars standardize
- inline help expands
- guided persona creation lands (`54093b0`)

It is still engineering-heavy work, but now it is human-centered engineering. The software starts to answer not just "does it compile?" but "does it guide me when I'm tired?"

## Act VII: March 6, The Compression Day

Some projects have a season finale. PersonaKit had **March 6, 2026**.

In one concentrated run, the repo lands:

- multi-agent persona/directive/session pack (`2f1e0c7`, `88c702f`)
- lane-based execution plans
- reliability gate stabilization (`bf86aef`, `ac6b9f5`)
- boundary and coverage hardening
- guardrail ADR and closeout protocol
- MCP local-first single-scope resolution (`e9cfe82`)
- Xcode host app and CLI wiring (`57ab979`, `9b08c7d`, `01389f3`, `c5f59e3`)

This is where a conceptual promise becomes operational truth.

### The decisive fix

The local-first MCP behavior stopped being implicit and became deterministic:

1. explicit root override
2. environment override
3. project-local discovery
4. global fallback
5. clear startup error if no valid scope

No silent merge. No split identity. No mystery root.

For this class of tooling, that is the difference between "interesting" and "trustworthy."

## Voices From the Work

If you listen to the commit messages as field interviews, you hear the same concerns repeated in different accents:

- "stabilize"
- "harden"
- "normalize"
- "standardize"
- "document"
- "closeout"

That vocabulary is not accidental. It is a team trying to lower surprise.

And this is where the collaboration model becomes the real story.

## The Collaboration Model: Human Editor, Agent Typist

The project narrative is unusual and practical at the same time:

- one human sets scope, constraints, and acceptance criteria
- one agent executes bounded edits quickly
- the human reviews architecture, regressions, and intent fidelity
- tests and docs are updated as part of the same loop

On paper, commit author lines show one name. In practice, the method is editorial: direction and standards from the reviewer, throughput from the agent.

Not autopilot. Not magic. A disciplined feedback loop.

## How We Knew It Was the Right Work

Across 306 commits, the evidence was repetitive in the best way:

1. deterministic output was treated as a feature
2. boundaries were explicit and enforced
3. docs tracked behavior, not aspirations
4. refactors came with gates, not vibes
5. dead ends were removed quickly

This is why speed did not degrade trust.

## Closing

PersonaKit did not get interesting by stacking features. It got interesting by insisting on context integrity:

- whose identity is active
- which scope is authoritative
- when to stop for human review
- how correctness is verified over time

So the headline is not "AI wrote the code."  
The headline is this: a human review practice turned AI velocity into durable software.

That is a story worth reusing.

---

## Timeline Appendix (Condensed)

| Date | Phase | Representative Commits |
| --- | --- | --- |
| 2026-01-23 | Foundation starts | `aec0ff8`, `846829b`, `86adb54` |
| 2026-01-24 | Boundary-first architecture moves | `c591bb6`, `3e32530`, `db09cbf`, `177b419` |
| 2026-01-24 to 2026-01-26 | Rebrand + AppOps rise/fall | `150dbbe`, `ece31a0`, `772d558` |
| 2026-01-30 to 2026-01-31 | Rebuild + CLI/MCP core | `56b1264`, `16af035`, `c5e7bd1`, `e9b4952` |
| 2026-02-01 to 2026-02-02 | Scope and MCP evolution | `ca77686`, `d970208`, `be33a58` |
| 2026-02-14 to 2026-02-17 | Studio expansion + FOSA boundaries | `4d9f01a`, `1726718`, `aabcdfb`, `c46080c`, `fa62e0f` |
| 2026-02-24 | UX flow maturity | `54093b0` |
| 2026-03-06 | Reliability + local-first + Xcode host integration | `bf86aef`, `e9cfe82`, `9b08c7d`, `c5f59e3` |

## Illustration and Artifact Slots (Next Pass)

1. Figure A: UI Evolution Timeline
   - Before/after snapshots for Studio root, Sessions panel, inline help, guided persona creation.
2. Figure B: Reliability and Build Trend
   - Flaky-test elimination checkpoints, stress-run pass streaks, validation duration trend.
3. Figure C: Architecture Over Time
   - Pre-FOSA vs post-FOSA module boundary diagrams.
4. Figure D: MCP Scope Resolution Flow
   - Local-first single-scope decision tree and failure-path examples.
5. Figure E: Review Loop Anatomy
   - Human intent -> agent diff -> review -> verification -> commit.
