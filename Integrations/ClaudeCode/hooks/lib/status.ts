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
 * Drift and re-ground blocked count only from the main resolution's drift mark on, so a re-ground clears what came
 * before it even within its own turn.
 */
function warnings(state: SessionState): string[] {
  const out: string[] = []
  if (state.main && state.compactions > 0) out.push('⚠ re-ground?')
  const since = state.drift.slice(state.main?.driftMark ?? 0)
  const drift = since.filter((d) => d.kind !== 'reground-blocked')
  const last = drift.at(-1)
  if (last) {
    const what = last.actionClass ? `${last.tool} (${last.actionClass})` : last.tool
    out.push(`⚠ drift: ${what}${drift.length > 1 ? ` ×${drift.length}` : ''}`)
  }
  if (since.some((d) => d.kind === 'reground-blocked')) out.push('⚠ re-ground blocked')
  return out
}

/** Who leads the line: the session id, else the persona (shrunk to its id once the persona is dropped). */
function lead(main: Resolution, keepPersona: boolean): string {
  const { ids, details } = main
  const persona = details?.personaName ?? details?.personaId ?? ids.personaId
  return ids.sessionId ?? (keepPersona ? persona : (ids.personaId ?? persona)) ?? 'contract'
}

/** The trailing names, `<persona> › <directive>`, without whatever already leads; dropped as asked. */
function names(main: Resolution, keepPersona: boolean, keepDirective: boolean): string | undefined {
  const { ids, details } = main
  const persona = ids.sessionId && keepPersona ? (details?.personaName ?? details?.personaId ?? ids.personaId) : undefined
  const directive = keepDirective ? (details?.directiveTitle ?? details?.directiveId ?? ids.directiveId) : undefined
  return [persona, directive].filter(Boolean).join(' › ') || undefined
}

function cut(text: string): string {
  return text.length <= MAX ? text : `${text.slice(0, MAX - 1)}…`
}

/**
 * The mod's one-line readout under the prompt: lead, warnings, enforcement, scope, then names. Plain text;
 * warnings carry `⚠`.
 */
export function statusText(state: SessionState): string {
  const tail = warnings(state)
  const { main } = state
  if (!main) {
    const enforcement = state.enforcement.kind === 'advisory' ? '/pk use <session>' : enforcementSegment(state.enforcement)
    return cut(['◇ no contract', enforcement, ...tail].join(SEP))
  }
  const scope = main.contract?.scope.mode
  // Claude Code cuts the line at its own width, which the mod can't know: what matters most goes first.
  const line = (keepPersona: boolean, keepDirective: boolean) =>
    ['◆ ' + lead(main, keepPersona), ...tail, enforcementSegment(state.enforcement), scope, names(main, keepPersona, keepDirective)]
      .filter(Boolean)
      .join(SEP)
  for (const [persona, directive] of [[true, true], [true, false], [false, false]] as const) {
    const text = line(persona, directive)
    if (text.length <= MAX) return text
  }
  return cut(line(false, false))
}
