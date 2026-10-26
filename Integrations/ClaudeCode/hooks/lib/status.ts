import type { Enforcement, Resolution, SessionState } from '../../types'

const MAX = 120
const SEP = ' · '

/** The enforcement segment: the steady word, or the warning that stands in its place. */
function enforcementSegment(enforcement: Enforcement): string {
  if (enforcement.kind === 'advisory') return 'advisory'
  if (enforcement.manifestUnreadable) return '⚠ enforcement manifest unreadable'
  if (enforcement.kind === 'enforced') return 'enforced'
  return `⚠ enforcing ${enforcement.ids.sessionId ?? enforcement.ids.personaId ?? 'another contract'}`
}

/**
 * Warnings after the enforcement segment: stale, latest drift with its count, re-ground blocked.
 * Drift and re-ground blocked count only from the main resolution's turn on.
 */
function warnings(state: SessionState): string[] {
  const out: string[] = []
  if (state.main && state.compactions > 0) out.push('⚠ re-ground?')
  const since = state.main?.turn ?? 0
  const drift = state.drift.filter((d) => d.kind !== 'reground-blocked' && d.turn >= since)
  const last = drift.at(-1)
  if (last) {
    const what = last.actionClass ? `${last.tool} (${last.actionClass})` : last.tool
    out.push(`⚠ drift: ${what}${drift.length > 1 ? ` ×${drift.length}` : ''}`)
  }
  if (state.drift.some((d) => d.kind === 'reground-blocked' && d.turn >= since)) out.push('⚠ re-ground blocked')
  return out
}

/** `<lead> · <persona> › <directive>`, with persona and directive dropped as asked. */
function head(main: Resolution, keepPersona: boolean, keepDirective: boolean): string {
  const { ids, details } = main
  const persona = details?.personaName ?? details?.personaId ?? ids.personaId
  const directive = details?.directiveTitle ?? details?.directiveId ?? ids.directiveId
  const withDirective = (who: string) => (keepDirective && directive ? `${who} › ${directive}` : who)
  if (ids.sessionId) return keepPersona && persona ? `${ids.sessionId}${SEP}${withDirective(persona)}` : ids.sessionId
  // With no session id the persona leads; dropped, it shrinks to its id rather than vanishing.
  return withDirective((keepPersona ? persona : (ids.personaId ?? persona)) ?? 'contract')
}

function cut(text: string): string {
  return text.length <= MAX ? text : `${text.slice(0, MAX - 1)}…`
}

/** The mod's one-line readout under the prompt. Plain text; warnings carry `⚠`. */
export function statusText(state: SessionState): string {
  const tail = warnings(state)
  const { main } = state
  if (!main) {
    const enforcement = state.enforcement.kind === 'advisory' ? '/pk use <session>' : enforcementSegment(state.enforcement)
    return cut(['◇ no contract', enforcement, ...tail].join(SEP))
  }
  const scope = main.contract?.scope.mode
  const line = (keepPersona: boolean, keepDirective: boolean) =>
    ['◆ ' + head(main, keepPersona, keepDirective), scope, enforcementSegment(state.enforcement), ...tail]
      .filter(Boolean)
      .join(SEP)
  for (const [persona, directive] of [[true, true], [true, false], [false, false]] as const) {
    const text = line(persona, directive)
    if (text.length <= MAX) return text
  }
  return cut(line(false, false))
}
