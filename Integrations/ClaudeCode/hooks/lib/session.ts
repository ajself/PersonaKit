import type { ContractIds, Enforcement, Observation, Resolution, SessionState } from '../../types'
import { classifyDrift } from './drift'
import { sameContract } from './enforcement'
import { CLAUDE_HOST } from './host'
import type { Host } from './host'

export const initial: SessionState = { subagents: {}, enforcement: { kind: 'advisory' }, compactions: 0, drift: [], turn: 0 }

export type Call = { tool: string; input: Record<string, unknown>; result: { isError?: boolean; text?: string }; agentId?: string }

export function isEmpty(s: SessionState): boolean {
  return s.main === undefined && Object.keys(s.subagents).length === 0 && s.drift.length === 0 && s.compactions === 0
}

export const trustedServers = (configured: string, enforcement: Enforcement) =>
  [...new Set([configured, enforcement.kind === 'advisory' ? undefined : enforcement.mcpServerName])].filter(
    (name): name is string => typeof name === 'string' && name.length > 0,
  )

/**
 * The installed hook judged again against a new main resolution, without re-reading anything. An unreadable manifest
 * and a plugin that is not loaded stay as they are: neither can become `enforced` by a resolution.
 */
export function rejudge(enforcement: Enforcement, ids: ContractIds | undefined): Enforcement {
  if (enforcement.kind === 'advisory' || enforcement.manifestUnreadable || enforcement.pluginMissing) return enforcement
  return { ...enforcement, kind: ids && sameContract(ids, enforcement.ids) ? 'enforced' : 'enforcing-other' }
}

/** A contract or export observation folded into the resolution it updates: merged when the same contract. */
function resolved(prev: Resolution | undefined, o: Exclude<Observation, { kind: 'failed' }>, turn: number): Resolution {
  const contract = o.kind === 'contract' ? o.contract : undefined
  const details = o.kind === 'export' ? o.details : undefined
  const same = prev !== undefined && sameContract(prev.ids, o.ids)
  const next: Resolution = { ids: same ? { ...prev.ids, ...o.ids } : o.ids, source: o.source, turn }
  const keptContract = contract ?? (same ? prev.contract : undefined)
  const keptDetails = details ?? (same ? prev.details : undefined)
  if (keptContract) next.contract = keptContract
  if (keptDetails) next.details = keptDetails
  return next
}

/**
 * One completed tool call applied to the state: its observations in order, then its drift once. Pure.
 * Every successful main observation, a re-ground of the same contract included, marks the drift seen so far as
 * before it. The call's own drift lands after the mark: a PersonaKit call that resolved is never drift, and one that
 * was blocked resolved nothing.
 */
export function applyCall(
  state: SessionState,
  call: Call,
  observations: Observation[],
  trusted: string[],
  host: Host = CLAUDE_HOST,
): SessionState {
  let s = state
  const { agentId } = call
  for (const o of observations) {
    if (o.kind === 'failed') continue
    if (agentId !== undefined) {
      s = { ...s, subagents: { ...s.subagents, [agentId]: resolved(s.subagents[agentId], o, s.turn) } }
    } else {
      const main: Resolution = { ...resolved(s.main, o, s.turn), driftMark: s.drift.length }
      s = { ...s, main, compactions: 0, enforcement: rejudge(s.enforcement, main.ids) }
    }
  }
  // A subagent is judged by its own contract when it resolved one, otherwise by main's.
  const judgedBy = (agentId !== undefined ? s.subagents[agentId] : undefined) ?? s.main
  const denied = judgedBy?.details?.deniedActionClasses ?? []
  const drift = classifyDrift(call, denied, s.enforcement, trusted, s.turn, host)
  return drift ? { ...s, drift: [...s.drift, drift] } : s
}
