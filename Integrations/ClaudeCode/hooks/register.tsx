import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { ContractIds, Enforcement, Observation, Resolution, SessionState } from '../types'
import { classifyDrift } from './lib/drift'
import { enforcementFor, installedHook, sameContract } from './lib/enforcement'
import { observe } from './lib/observe'
import { statusText } from './lib/status'

// Under the session's project root (`$.session.root()`), not its working directory.
const SETTINGS = '.claude/settings.json'

const initial: SessionState = { subagents: {}, enforcement: { kind: 'advisory' }, compactions: 0, drift: [], turn: 0 }
export const session = atom({ plugin: 'personakit', key: 'session' } as const, initial)

type Call = { tool: string; input: Record<string, unknown>; result: { isError?: boolean; text?: string }; agentId?: string }
type Installed = { hook: ReturnType<typeof installedHook>; manifest: string | undefined }
// Only what the mod needs of `$`, so `rebuild` and the helpers take any hook's `$`.
type Dollar = Parameters<typeof read>[0] & {
  fs: { read: (path: string) => Promise<unknown> }
  session: { root: () => Promise<string>; messages: () => Promise<readonly { role: string; text: string; toolUses: readonly ToolUse[]; toolResults?: readonly unknown[] }[]> }
}
type ToolUse = { tool: string; input: Record<string, unknown>; result?: unknown; text?: string; isError?: true }

const isEmpty = (s: SessionState) =>
  s.main === undefined && Object.keys(s.subagents).length === 0 && s.drift.length === 0 && s.compactions === 0

/** `$.fs.read` that answers undefined instead of rejecting: a missing or unreadable file is no file. */
const readText = async ($: Dollar, path: string): Promise<string | undefined> => {
  try {
    const text = await $.fs.read(path)
    return typeof text === 'string' ? text : undefined
  } catch {
    return undefined
  }
}

async function readInstalled($: Dollar): Promise<Installed> {
  let root: string
  try {
    root = await $.session.root()
  } catch {
    return { hook: undefined, manifest: undefined }
  }
  const hook = installedHook(await readText($, `${root.replace(/\/$/, '')}/${SETTINGS}`))
  return { hook, manifest: hook ? await readText($, hook.manifestPath) : undefined }
}

const trustedServers = (configured: string, enforcement: Enforcement) =>
  [...new Set([configured, enforcement.kind === 'advisory' ? undefined : enforcement.mcpServerName])].filter(
    (name): name is string => typeof name === 'string' && name.length > 0,
  )

/** The installed hook judged again against a new main resolution, without re-reading anything. */
function rejudge(enforcement: Enforcement, ids: ContractIds | undefined): Enforcement {
  if (enforcement.kind === 'advisory' || enforcement.manifestUnreadable) return enforcement
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

/** One completed tool call applied to the state: its observation, then its drift. Pure. */
function applyCall(state: SessionState, call: Call, o: Observation | undefined, trusted: string[]): SessionState {
  let s = state
  const { agentId } = call
  if (o && o.kind !== 'failed') {
    if (agentId !== undefined) {
      s = { ...s, subagents: { ...s.subagents, [agentId]: resolved(s.subagents[agentId], o, s.turn) } }
    } else {
      const main = resolved(s.main, o, s.turn)
      s = { ...s, main, compactions: 0, enforcement: rejudge(s.enforcement, main.ids) }
    }
  }
  // A subagent is judged by its own contract when it resolved one, otherwise by main's.
  const judgedBy = (agentId !== undefined ? s.subagents[agentId] : undefined) ?? s.main
  const denied = judgedBy?.details?.deniedActionClasses ?? []
  const drift = classifyDrift(call, denied, s.enforcement, trusted, s.turn)
  return drift ? { ...s, drift: [...s.drift, drift] } : s
}

/** The state the transcript implies, from scratch: main's resolves and drift, turn by turn. */
export async function rebuild($: Dollar, enforcement: Enforcement, configured: string): Promise<SessionState> {
  let s: SessionState = { ...initial, enforcement }
  let messages: Awaited<ReturnType<Dollar['session']['messages']>> = []
  try {
    messages = await $.session.messages()
  } catch {
    return s
  }
  for (const message of messages) {
    if (message.role === 'user' && !message.toolResults?.length) s = { ...s, turn: s.turn + 1 }
    for (const use of message.toolUses) {
      if (use.text === undefined && use.result === undefined) continue // still in flight
      const call: Call = { tool: use.tool, input: use.input, result: { result: use.result, text: use.text, isError: use.isError } as Call['result'] }
      const trusted = trustedServers(configured, s.enforcement)
      s = applyCall(s, call, await observe(call, trusted, (path) => readText($, path)), trusted)
    }
  }
  return s
}

type Ui = { ui: { status: (text: string | undefined) => void; log: (text: string, options?: { to: 'debug' }) => void } }

/** Paints the latest state, not the one this handler wrote: a parallel call may have written since. */
async function paint($: Dollar & Ui): Promise<void> {
  $.ui.status(statusText(await read($, session)))
}

/** Observe-only: a failure is logged for the maintainer and never reaches the engine. */
async function safely($: Ui, work: () => Promise<void>): Promise<void> {
  try {
    await work()
  } catch (error) {
    try {
      $.ui.log(`personakit: ${error instanceof Error ? error.message : String(error)}`, { to: 'debug' })
    } catch {}
  }
}

/** Judges the installed hook and manifest (re-read unless given) against main's resolution. */
async function refreshEnforcement($: Dollar & Ui, installed?: Installed): Promise<void> {
  const { hook, manifest } = installed ?? (await readInstalled($))
  await update($, session, (s) => ({ ...s, enforcement: enforcementFor(s.main?.ids, hook, manifest) }))
  await paint($)
}

export const register: Register = (on, options) => {
  const configured = typeof options.mcpServerName === 'string' ? options.mcpServerName : 'personakit'

  on('session.start', async ($, e, next) => {
    const ran = await next(e)
    await safely($, async () => {
      const installed = await readInstalled($)
      if (isEmpty(await read($, session))) {
        const rebuilt = await rebuild($, enforcementFor(undefined, installed.hook, installed.manifest), configured)
        // A hook that ran meanwhile wins over the rebuild: it only replaces a still-empty state.
        await update($, session, (s) => (isEmpty(s) ? rebuilt : s))
      }
      await refreshEnforcement($, installed)
    })
    return ran
  })

  on('session.end', async ($, e, next) => {
    if (e.reason === 'clear' || e.reason === 'resume') {
      // The hook stays installed and no session.start follows a /clear: keep judging it, now against no contract.
      await safely($, async () => {
        await update($, session, (s) => ({ ...initial, enforcement: rejudge(s.enforcement, undefined) }))
        await paint($)
      })
    }
    return next(e)
  })

  on('turn.start', async ($, e, next) => {
    if (e.agentId === undefined) await safely($, async () => void (await update($, session, (s) => ({ ...s, turn: s.turn + 1 }))))
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const ran = await next(e)
    if (e.agentId === undefined) await safely($, () => refreshEnforcement($))
    return ran
  })

  on('session.compact', async ($, e, next) => {
    const ran = await next(e)
    const counted = e.agentId === undefined && e.trigger !== 'precompute' && ran.skip === undefined && ran.messages !== undefined
    if (counted) {
      await safely($, async () => {
        await update($, session, (s) => ({ ...s, compactions: s.compactions + 1 }))
        await paint($)
      })
    }
    return ran
  })

  on('tool.call', async ($, e, next) => {
    const ran = await next(e)
    await safely($, async () => {
      const { tool, tool_use_id: _id, agentId, requestMeta: _meta, ...input } = e as typeof e & { agentId?: string; requestMeta?: unknown }
      // A deny from beneath reaches the model as an error result; judge it as one.
      const result = (ran.deny !== undefined ? { isError: true, text: ran.deny } : ran) as Call['result']
      const call: Call = { tool, input, result, ...(agentId !== undefined ? { agentId } : {}) }
      const trusted = trustedServers(configured, (await read($, session)).enforcement)
      const o = await observe(call, trusted, (path) => readText($, path))
      const s = await update($, session, (cur) => applyCall(cur, call, o, trusted))
      await paint($)
      if (o?.kind === 'failed' && agentId === undefined) {
        const kept = s.main ? `; ${s.main.ids.sessionId ?? s.main.ids.personaId ?? 'the current contract'} stays in force` : ''
        $.ui.toast(`PersonaKit resolve failed${kept}`)
      }
    })
    return ran
  })
}
