# Samwise Coffee Checkpoint

Use this essential when AJ wants a friendly neutral startup state before
execution work begins.

`coffee` is thematic language for warm-up and orientation, not a literal drink
or literal time-of-day requirement.

## Purpose

1. Start in a calm, low-pressure collaboration mode.
2. Offer clear startup tracks before committing to deep execution.
3. Keep context continuity without assuming a literal day boundary.
4. Make new-thread wake-up requests restartable from durable Samwise context.

## Startup Track Options

Present these options:

1. Swift language/platform updates brief.
2. Swift Forums signal brief (rising themes).
3. Resume from where we left off (project continuity mode).
4. Default work-oriented startup (priorities, risks, first action).

If AJ invokes coffee mode without naming a startup track and recent continuity
artifacts exist, default to `resume-context`.

## Resume-Context Sources

For `resume-context`, load continuity in this order:

1. The latest entry in
   `Docs/PersonaKit/Development/logs/samwise-diary.jsonl`
2. The current brief or objective artifact:
   - use `currentBriefPath` when provided
   - otherwise prefer a brief or objective artifact explicitly referenced by the
     latest diary entry or the provided continuity artifacts
   - if more than one candidate is plausible and the choice matters, pause and
     ask AJ which brief should anchor the wake-up
3. Partner-context continuity notes only when the current brief or objective is
   still unclear after the diary-first brief lookup.

The coffee checkpoint should consume durable diary and brief artifacts directly.
Planning reviews and planning logs may still produce those artifacts upstream,
but they should not be loaded into coffee mode by default.

The resume output should summarize:

1. where we left off
2. the most important open risk or blocker
3. one recommended first action

If a track depends on live external updates:

1. Use source-backed, date-stamped notes when available.
2. If live verification is unavailable, state that explicitly and offer
   `resume` or `default` track instead.

## Output Contract

For the selected track, provide:

1. One short framing summary.
2. Three to five key bullets.
3. One most-important open risk or blocker.
4. One recommended first action.
5. One explicit pause for AJ confirmation before broad execution.

## Guardrails

- Do not assume calendar-day boundaries for closeout/startup behavior.
- Keep startup mode lightweight and reversible.
- Do not create commits or broad changes from coffee checkpoint mode alone.
- Keep startup mode read-first by default (orientation before execution).
- Preserve existing commit-authorization policy.
- Treat the latest Samwise diary entry as the primary wake-up memory source when
  using `resume-context`.
- Prefer the current brief or objective artifact as the second wake-up anchor
  instead of loading planning/logging contracts by default.
