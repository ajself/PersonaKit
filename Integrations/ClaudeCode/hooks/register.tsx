import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Call, ContractIds, Enforcement, PaneState, SessionState, View } from '../types'
import { enforcementFor, installedHook } from './lib/enforcement'
import { canUse } from './lib/ids'
import { observe } from './lib/observe'
import { usePrompt } from './lib/prompts'
import { loadLibrary, loadPreview, mcpServerName, personakitBinary, previewKey } from './lib/runner'
import type { RunnerDollar } from './lib/runner'
import { applyCall, initial, isEmpty, rejudge, trustedServers } from './lib/session'
import { statusText } from './lib/status'
import { paneTree } from './pane'
import type { PaneActions } from './pane'

// Under the session's project root (`$.session.root()`), not its working directory.
const SETTINGS = '.claude/settings.json'
const PANE = 'personakit'

export const session = atom({ plugin: 'personakit', key: 'session' } as const, initial)

// The Library and the previews: pane state apart from the session's, so nothing they load reaches the status line.
// `/pk` picks the opening view; a pane opened any other way shows the Contract and runs nothing.
const initialPane: PaneState = { view: { kind: 'contract' }, back: [], filter: '', library: { kind: 'idle' }, previews: {}, expanded: [], token: 0 }
export const pane = atom({ plugin: 'personakit', key: 'pane' } as const, initialPane)

type Installed = { hook: ReturnType<typeof installedHook>; manifest: string | undefined }
// Only what the mod needs of `$`, so `rebuild` and the helpers take any hook's `$`.
type Dollar = Parameters<typeof read>[0] & {
  fs: { read: (path: string) => Promise<unknown> }
  session: { root: () => Promise<string>; messages: () => Promise<readonly { role: string; text: string; toolUses: readonly ToolUse[]; toolResults?: readonly unknown[] }[]> }
}
type ToolUse = { tool: string; input: Record<string, unknown>; result?: unknown; text?: string; isError?: true }

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

type Runner = Parameters<typeof read>[0] & RunnerDollar

/**
 * Loads the Library into the pane. Each call takes the next token and a result lands only while its token is still
 * the latest, so Refresh during a load replaces the first and a late answer is dropped. Refresh also drops every
 * preview: the pane must not show a contract the library it just reloaded no longer agrees with.
 */
export async function refreshLibrary($: Runner, binary: string): Promise<void> {
  const { token } = await update($, pane, (p): PaneState => ({ ...p, token: p.token + 1, library: { kind: 'loading', token: p.token + 1 }, previews: {} }))
  const library = await loadLibrary($, binary)
  await update($, pane, (p): PaneState => (p.token === token ? { ...p, library } : p))
}

/**
 * Reads the preview for `ids` into the pane, unless it is loaded or loading. A failed one is tried again. The result
 * lands only while the loading marker it claimed is still there, so a Refresh in between drops it.
 */
export async function openPreview($: Runner, binary: string, ids: ContractIds): Promise<void> {
  const key = previewKey(ids)
  let isClaimed = false
  let claimed = 0
  await update($, pane, (p): PaneState => {
    const current = p.previews[key]
    isClaimed = current === undefined || current.kind === 'failed'
    claimed = p.token
    return isClaimed ? { ...p, previews: { ...p.previews, [key]: { kind: 'loading', token: p.token } } } : p
  })
  if (!isClaimed) return
  const preview = await loadPreview($, binary, ids)
  await update($, pane, (p): PaneState => {
    const current = p.previews[key]
    return current?.kind === 'loading' && current.token === claimed ? { ...p, previews: { ...p.previews, [key]: preview } } : p
  })
}

/** Reads the contract preview for the Contract view when it has export details but no contract JSON of its own. */
async function fillContract($: Runner, binary: string): Promise<void> {
  const { main } = await read($, session)
  if (main?.details && !main.contract) await openPreview($, binary, main.ids)
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

type Prompt = Ui & {
  prompt: {
    read: () => Promise<{ text: string }>
    fill: (input: { text: string; mode: 'replace' | 'append' }) => Promise<{ isFilled: boolean }>
  }
  ui: { toast: (text: string) => void }
}

/**
 * Pre-fills `text` without losing a draft: over an empty box, else on a new line after it.
 * The person reviews and sends it; the mod never submits. Not filled, it is shown as a toast to copy.
 */
async function fillPrompt($: Prompt, text: string): Promise<boolean> {
  let isFilled = false
  try {
    const draft = (await $.prompt.read()).text
    const input = draft.trim() === '' ? { text, mode: 'replace' as const } : { text: `\n${text}`, mode: 'append' as const }
    isFilled = (await $.prompt.fill(input)).isFilled
  } catch (error) {
    try {
      $.ui.log(`personakit: prompt fill failed: ${error instanceof Error ? error.message : String(error)}`, { to: 'debug' })
    } catch {}
  }
  if (!isFilled) $.ui.toast(text)
  return isFilled
}

/** Pre-fills the grounding prompt for `ids`; an id outside the id rule fills nothing and is toasted. */
async function fillGrounding($: Prompt, ids: ContractIds): Promise<boolean> {
  if (!canUse(ids)) {
    $.ui.toast('PersonaKit: unsupported id')
    return false
  }
  return fillPrompt($, usePrompt(ids))
}

const USE = 'Usage: /pk use <session>'
const USAGE = 'Usage: /pk opens the PersonaKit pane; /pk use <session> pre-fills a grounding prompt.'

export const register: Register = (on, options) => {
  const configured = mcpServerName(options)
  const binary = personakitBinary(options)

  on('session.start', async ($, e, next) => {
    const ran = await next(e)
    await safely($, async () => {
      await $.command.register({ name: 'pk', description: 'Show the PersonaKit contract in force, or pre-fill a prompt to ground one', argumentHint: '[use <session>]' })
    })
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
      const os = await observe(call, trusted, (path) => readText($, path))
      const s = await update($, session, (cur) => applyCall(cur, call, os, trusted))
      await paint($)
      if (agentId === undefined && os.length > 0 && os.every((o) => o.kind === 'failed')) {
        const kept = s.main ? `; ${s.main.ids.sessionId ?? s.main.ids.personaId ?? 'the current contract'} stays in force` : ''
        $.ui.toast(`PersonaKit resolve failed${kept}`)
      }
    })
    return ran
  })

  on('command.run', { command: 'pk' }, async ($, e) => {
    const [sub = '', name, ...rest] = e.args.trim().split(/\s+/)
    if (sub === '') {
      // Opens on the Contract when one is in force, else on the Library, which loads each time it is shown.
      const view: View = (await read($, session)).main ? { kind: 'contract' } : { kind: 'library' }
      await safely($, async () => void (await update($, pane, (p): PaneState => ({ ...p, view, back: [] }))))
      // Never `focus`: a focused pane would hold the keys and refuse Re-ground's fill.
      const { isPlaced } = await $.ui.open({ id: PANE, title: 'PersonaKit' })
      if (isPlaced && view.kind === 'library') await safely($, () => refreshLibrary($, binary))
      if (isPlaced && view.kind === 'contract') await safely($, () => fillContract($, binary))
      return { text: isPlaced ? 'PersonaKit pane opened.' : 'No surface here can show the PersonaKit pane.' }
    }
    if (sub !== 'use') return { text: USAGE }
    if (name === undefined || rest.length > 0) return { text: USE }
    if (!canUse({ sessionId: name })) {
      $.ui.toast('PersonaKit: unsupported id')
      return { text: 'Unsupported id; no prompt was pre-filled.' }
    }
    const filled = await fillGrounding($, { sessionId: name })
    return { text: filled ? `Pre-filled a prompt to ground this session in \`${name}\`; review it and send.` : 'The prompt box took no text; the prompt is in a toast to copy.' }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const reground = async () => {
      const { main } = await read($, session)
      if (main) await fillGrounding($, main.ids)
    }
    const edit = (change: (p: PaneState) => PaneState) => void safely($, async () => void (await update($, pane, change)))
    // A top-level view clears the back stack and the Library loads each time it is shown; any other view stacks.
    // A session view reads its contract preview, once; so does the Contract, when it lacks contract JSON.
    const go = async (view: View) => {
      const isTop = view.kind === 'contract' || view.kind === 'library'
      await update($, pane, (p): PaneState => ({ ...p, view, back: isTop ? [] : [...p.back, p.view] }))
      if (view.kind === 'library') await refreshLibrary($, binary)
      if (view.kind === 'contract') await fillContract($, binary)
      if (view.kind === 'session') await openPreview($, binary, { sessionId: view.id })
    }
    const actions: PaneActions = {
      go: (view) => void safely($, () => go(view)),
      back: () => edit((p) => ({ ...p, view: p.back.at(-1) ?? { kind: 'library' }, back: p.back.slice(0, -1) })),
      setFilter: (filter) => edit((p) => ({ ...p, filter })),
      refresh: () => void safely($, () => refreshLibrary($, binary)),
      use: (sessionId) => void safely($, async () => void (await fillGrounding($, { sessionId }))),
      reground: () => void safely($, reground),
      toggle: (key) => edit((p) => ({ ...p, expanded: p.expanded.includes(key) ? p.expanded.filter((k) => k !== key) : [...p.expanded, key] })),
    }
    return paneTree({ ...$.ui.resolve(e), surface: e.surface }, await read($, session), await read($, pane), e.props.bodyColumns, actions)
  })
}
