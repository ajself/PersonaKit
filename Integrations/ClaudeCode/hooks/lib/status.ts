import type { Enforcement, Resolution, SessionState } from '../../types'
import { driftSinceGrounding } from './session'

const MAX = 120
const SEP = ' · '
// Budgets for observed text in the fallback, used only when the line would not fit otherwise. The lead and the
// enforcing id are all that precede the enforcement segment there, so together they always leave it inside the cut.
const LEAD_MAX = 32
const ID_MAX = 32
const TOOL_MAX = 24

type Fit = (text: string, max: number) => string
const whole: Fit = (text) => text
/** `text` cut to `max` characters, ending in `…` when it was cut. */
const ellipsize: Fit = (text, max) => (text.length <= max ? text : `${text.slice(0, max - 1)}…`)

/** The enforcement segment: the steady word, or the warning that stands in its place. */
function enforcementSegment(enforcement: Enforcement, fit: Fit): string {
  if (enforcement.kind === 'advisory') return 'advisory'
  if (enforcement.pluginMissing) return '⚠ manifest present · plugin not loaded'
  if (enforcement.manifestUnreadable) return '⚠ enforcement manifest unreadable'
  if (enforcement.kind === 'enforced') return 'enforced'
  return `⚠ enforcing ${fit(enforcement.ids.sessionId ?? enforcement.ids.personaId ?? 'another contract', ID_MAX)}`
}

/**
 * Warnings after the enforcement segment: stale, latest drift with its count, re-ground blocked.
 * Drift and re-ground blocked count only from the main resolution's drift mark on, so a re-ground clears what came
 * before it even within its own turn.
 */
function warnings(state: SessionState, fit: Fit): string[] {
  const out: string[] = []
  if (state.main && state.compactions > 0) out.push('⚠ re-ground?')
  const since = driftSinceGrounding(state)
  const drift = since.filter((d) => d.kind !== 'reground-blocked')
  const last = drift.at(-1)
  if (last) {
    const tool = fit(last.tool, TOOL_MAX)
    const what = last.actionClass ? `${tool} (${last.actionClass})` : tool
    out.push(`⚠ drift: ${what}${drift.length > 1 ? ` ×${drift.length}` : ''}`)
  }
  if (since.some((d) => d.kind === 'reground-blocked')) out.push('⚠ re-ground blocked')
  return out
}

/** Who leads the line: the session id, else the persona (shrunk to its id once the persona is dropped). */
function lead(main: Resolution, keepPersona: boolean, fit: Fit): string {
  const { ids, details } = main
  const persona = details?.personaName ?? details?.personaId ?? ids.personaId
  return fit(ids.sessionId ?? (keepPersona ? persona : (ids.personaId ?? persona)) ?? 'contract', LEAD_MAX)
}

/** The trailing names, `<persona> › <directive>`, without whatever already leads; dropped as asked. */
function names(main: Resolution, keepPersona: boolean, keepDirective: boolean): string | undefined {
  const { ids, details } = main
  const persona = ids.sessionId && keepPersona ? (details?.personaName ?? details?.personaId ?? ids.personaId) : undefined
  const directive = keepDirective ? (details?.directiveTitle ?? details?.directiveId ?? ids.directiveId) : undefined
  return [persona, directive].filter(Boolean).join(' › ') || undefined
}

/** What a host words its own way; the mod's own words when absent. */
export type StatusOptions = {
  /** What the no-contract line suggests in place of `advisory`: `/pk use <session>` by default. */
  hint?: string
  /**
   * A warning shown in place of the enforcement segment, whatever the enforcement is. It is never ellipsized, so it
   * must fit beside the lead's budget, as the enforcing segment does.
   */
  enforcementWarning?: string
}

function cut(text: string): string {
  return text.length <= MAX ? text : `${text.slice(0, MAX - 1)}…`
}

/**
 * The mod's one-line readout under the prompt: lead, warnings, enforcement, scope, then names. Plain text;
 * warnings carry `⚠`. Observed text is shown whole while the line fits; when it cannot fit, the lead, the tool name
 * and the enforcing id are ellipsized and the enforcement segment moves ahead of the warnings, so whatever the hard
 * cut takes, it is never the enforcement segment.
 */
export function statusText(state: SessionState, options: StatusOptions = {}): string {
  const { main } = state
  const { hint = '/pk use <session>', enforcementWarning } = options
  const segment = (fit: Fit) => enforcementWarning ?? enforcementSegment(state.enforcement, fit)
  if (!main) {
    const line = (fit: Fit) => {
      const enforcement = enforcementWarning ?? (state.enforcement.kind === 'advisory' ? hint : enforcementSegment(state.enforcement, fit))
      return ['◇ no contract', enforcement, ...warnings(state, fit)].join(SEP)
    }
    const text = line(whole)
    return text.length <= MAX ? text : cut(line(ellipsize))
  }
  const scope = main.contract?.scope.mode
  // Claude Code cuts the line at its own width, which the mod can't know: what matters most goes first.
  const line = (keepPersona: boolean, keepDirective: boolean, fit: Fit, enforcementFirst = false) => {
    const enforcement = segment(fit)
    const warned = warnings(state, fit)
    return [
      '◆ ' + lead(main, keepPersona, fit),
      ...(enforcementFirst ? [enforcement, ...warned] : [...warned, enforcement]),
      scope,
      names(main, keepPersona, keepDirective),
    ]
      .filter(Boolean)
      .join(SEP)
  }
  for (const [persona, directive] of [[true, true], [true, false], [false, false]] as const) {
    const text = line(persona, directive, whole)
    if (text.length <= MAX) return text
  }
  return cut(line(false, false, ellipsize, true))
}
