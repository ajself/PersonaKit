import { expect, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On, SessionMessage } from 'claude-code'

import type { SessionState } from '../types'
import { CONTRACT_JSON, EXPORT_MD } from './fixtures/golden'

const SESSION = 'read-only-auditor_audit-pass'
const RESOLVE = 'mcp__personakit__personakit_resolve_contract'
const EXPORT = 'mcp__personakit__personakit_export'
const NO_CONTRACT = '◇ no contract · /pk use <session>'
const STEADY = '◆ read-only-auditor_audit-pass · Read-Only Auditor › Read-only audit pass · project-only'
// The golden line with the directive dropped: a drift warning would push it past 120 characters.
const SHORT = '◆ read-only-auditor_audit-pass · Read-Only Auditor · project-only'
// An export seen with no contract JSON: no scope segment.
const EXPORTED = '◆ read-only-auditor_audit-pass · Read-Only Auditor › Read-only audit pass'
const SURFACES = ['terminal', 'desktop'] as const

const MANIFEST_PATH = '/p/.claude/personakit/read-only-auditor_audit-pass.checks.json'
const HOOKED_SETTINGS = JSON.stringify({
  hooks: {
    PreToolUse: [
      {
        matcher: 'Edit|Write|NotebookEdit|Bash|mcp__.*',
        hooks: [{ type: 'command', command: `'/usr/local/bin/personakit' hook-check --manifest '${MANIFEST_PATH}'` }],
      },
    ],
  },
})
const MANIFEST = JSON.stringify({
  sessionId: SESSION,
  personaId: 'read-only-auditor',
  directiveId: 'audit-pass',
  checks: [{ id: 'a', maxClass: 'hook', rule: { kind: 'capability-deny', deniedActionClasses: ['file-mutation'] } }],
})

const otherContract = CONTRACT_JSON.replace(/read-only-auditor_audit-pass/g, 'other-session')
const contractOnly = (personaId: string) =>
  JSON.stringify({ ...JSON.parse(CONTRACT_JSON), sessionId: undefined, personaId, directiveId: 'd' })

type Answer = { result: unknown; text: string; isError?: true }
const ok = (text: string): Answer => ({ result: text, text })
const failed = (text: string): Answer => ({ result: text, text, isError: true })

/** The engine beneath the plugin: every `$` call the mod makes is answered here. */
function engine(on: On, { skipCompactions = false } = {}) {
  const files: Record<string, string> = {}
  const answers: Answer[] = []
  const world = {
    files, answers, messages: [] as SessionMessage[], statuses: [] as (string | undefined)[], toasts: [] as string[], logs: [] as string[],
    state: undefined as SessionState | undefined,
  }
  // The kit keeps `$.state` beneath this hook; it only watches what the mod writes.
  on('state.set', (_, e, next) => {
    if (e.plugin === 'personakit' && e.key === 'session') world.state = e.value as SessionState
    return next(e)
  })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('session.end', (_, e) => ({ sessionId: e.sessionId }))
  on('turn.start', (_, e) => ({ turnId: e.turnId }))
  on('turn.complete', (_, e) => ({ text: e.answer }))
  on('session.compact', (_, e) => (skipCompactions ? { skip: 'not now' } : { messages: e.messages }))
  on('tool.call', () => (answers.shift() ?? ok('ok')) as never)
  on('fs.read', (_, e) => (e.path in files ? { value: files[e.path] } : { deny: `${e.path}: missing` }) as never)
  on('session.root', () => ({ value: '/p' }))
  on('command.register', () => ({ value: { command: 'pk' } }))
  on('session.messages', () => ({ value: world.messages }) as never)
  on('ui.status', (_, e) => {
    world.statuses.push(e.text)
    return { value: undefined }
  })
  on('ui.log', (_, e) => {
    world.logs.push(e.text)
    return { value: undefined }
  })
  on('ui.toast', (_, e) => {
    world.toasts.push(e.text)
    return { value: undefined }
  })
  return world
}

type World = ReturnType<typeof engine>

const status = (w: World) => w.statuses.at(-1)
const start = ($: Engine, surface: (typeof SURFACES)[number]) => $.session.start({ cwd: '/p', surface, isInteractive: true })
const resolve = ($: Engine, w: World, answer: Answer, agentId?: string) => {
  w.answers.push(answer)
  return $.tool.call({ tool: RESOLVE, ...(agentId ? { agentId } : {}) } as never)
}
const exportCall = ($: Engine, w: World, answer: Answer, sessionId = SESSION, agentId?: string) => {
  w.answers.push(answer)
  return $.tool.call({ tool: EXPORT, sessionId, ...(agentId ? { agentId } : {}) } as never)
}
const write = ($: Engine, agentId?: string) =>
  $.tool.call({ tool: 'Write', file_path: '/p/a.txt', content: 'x', ...(agentId ? { agentId } : {}) } as never)
/** Resolve, then export, the golden contract as main: the full steady line. */
const ground = async ($: Engine, w: World) => {
  await resolve($, w, ok(CONTRACT_JSON))
  await exportCall($, w, ok(EXPORT_MD))
}
const SUMMARY: SessionMessage[] = [{ role: 'user', text: 'summary', toolUses: [] }]
const turn = async ($: Engine, n: number, agentId?: string) => {
  await $.turn.start({ text: 'go', turnId: `t${n}`, ...(agentId ? { agentId } : {}) })
  await $.turn.complete({ answer: 'done', durationMs: 1, isAborted: false, turnId: `t${n}`, reason: 'answer', ...(agentId ? { agentId } : {}) } as never)
}
const state = async (w: World) => w.state as SessionState

/** One test per surface: the mod must not depend on where it draws. */
const each = (name: string, body: ($: Engine, w: World, surface: (typeof SURFACES)[number]) => Promise<void>) => {
  for (const surface of SURFACES) {
    test(`${name} (${surface})`, async ($, on) => {
      const w = engine(on)
      await start($, surface)
      await body($, w, surface)
      // Handlers swallow their own failures into the debug log; none should have happened.
      expect(w.logs).toEqual([])
    })
  }
}

each('a resolve updates the status line', async ($, w) => {
  expect(status(w)).toBe(NO_CONTRACT)
  await resolve($, w, ok(CONTRACT_JSON))
  expect(status(w)?.startsWith('◆ read-only-auditor_audit-pass')).toBe(true)
})

each('handlers return the result beneath unchanged', async ($, w) => {
  w.answers.push(ok(CONTRACT_JSON))
  const ran = await $.tool.call({ tool: RESOLVE } as never)
  expect(ran.text).toBe(CONTRACT_JSON)
  expect(ran.result).toBe(CONTRACT_JSON)
})

each('an export of the same contract enriches it', async ($, w) => {
  await resolve($, w, ok(CONTRACT_JSON))
  expect(status(w)).toBe('◆ read-only-auditor_audit-pass · read-only-auditor › audit-pass · project-only · advisory')
  await exportCall($, w, ok(EXPORT_MD))
  expect(status(w)).toBe(`${STEADY} · advisory`)
  const s = await state(w)
  expect(s.main?.contract?.personaId).toBe('read-only-auditor')
  expect(s.main?.details?.personaName).toBe('Read-Only Auditor')
})

each('a different contract replaces it', async ($, w) => {
  await ground($, w)
  await resolve($, w, ok(otherContract))
  expect(status(w)?.startsWith('◆ other-session · read-only-auditor › audit-pass')).toBe(true)
  expect((await state(w)).main?.details).toBe(undefined)
})

each('a failed resolve keeps the current one and toasts once', async ($, w) => {
  await resolve($, w, ok(CONTRACT_JSON))
  const before = status(w)
  await resolve($, w, failed('no such session'))
  expect(status(w)).toBe(before)
  expect(w.toasts.length).toBe(1)
  await turn($, 1)
  expect(w.toasts.length).toBe(1)
  await resolve($, w, ok('not json'))
  expect(w.toasts.length).toBe(2)
  expect(status(w)).toBe(before)
})

each('subagent resolve and subagent turns do not move the status line', async ($, w) => {
  await ground($, w)
  await turn($, 1)
  const main = status(w)
  expect(main).toBe(`${STEADY} · advisory`)

  await resolve($, w, ok(contractOnly('helper')), 'a1')
  await turn($, 2, 'a1')
  expect(status(w)).toBe(main)
  const s = await state(w)
  expect(s.subagents.a1?.ids).toEqual({ personaId: 'helper', directiveId: 'd' })
  expect(s.main?.ids.sessionId).toBe(SESSION)
  expect(s.turn).toBe(1)

  // The subagent's own contract has no export, so it denies nothing: no drift.
  await write($, 'a1')
  expect((await state(w)).drift).toEqual([])
  // A subagent with no contract of its own is judged against main's.
  await write($, 'a2')
  expect((await state(w)).drift).toEqual([{ tool: 'Write', actionClass: 'file-mutation', kind: 'advisory', agentId: 'a2', turn: 1 }])
  // The subagent's export denies file-mutation too: its own classes drive its drift.
  await exportCall($, w, ok(EXPORT_MD), SESSION, 'a1')
  await write($, 'a1')
  expect((await state(w)).drift.length).toBe(2)
  expect(status(w)).toBe(`${SHORT} · advisory · ⚠ drift: Write (file-mutation) ×2`)
})

each('counted compactions mark stale; precompute, skipped, and subagent ones do not; a new resolve clears it', async ($, w) => {
  await ground($, w)
  await $.session.compact({ trigger: 'precompute', messages: SUMMARY })
  await $.session.compact({ trigger: 'manual', messages: SUMMARY, agentId: 'a1' })
  expect(status(w)).toBe(`${STEADY} · advisory`)
  expect((await state(w)).compactions).toBe(0)

  await $.session.compact({ trigger: 'auto', messages: SUMMARY })
  expect(status(w)).toBe(`${STEADY} · advisory · ⚠ re-ground?`)
  await exportCall($, w, ok(EXPORT_MD))
  expect(status(w)).toBe(`${STEADY} · advisory`)
})

test('a skipped compaction is not counted', async ($, on) => {
  const w = engine(on, { skipCompactions: true })
  await start($, 'terminal')
  await ground($, w)
  await $.session.compact({ trigger: 'manual', messages: SUMMARY })
  expect((await state(w)).compactions).toBe(0)
  expect(status(w)).toBe(`${STEADY} · advisory`)
})

each('/clear resets', async ($, w) => {
  await resolve($, w, ok(CONTRACT_JSON))
  await $.session.end({ reason: 'clear', sessionId: 's1', resume: { id: 's1' } } as never)
  await turn($, 1)
  expect(status(w)).toBe(NO_CONTRACT)
  expect((await state(w)).main).toBe(undefined)
})

each('/clear keeps judging an installed hook, now against no contract', async ($, w, surface) => {
  w.files['/p/.claude/settings.json'] = HOOKED_SETTINGS
  w.files[MANIFEST_PATH] = MANIFEST
  await start($, surface)
  await ground($, w)
  expect(status(w)).toBe(`${STEADY} · enforced`)
  await $.session.end({ reason: 'clear', sessionId: 's1', resume: { id: 's1' } } as never)
  expect(status(w)).toBe(`◇ no contract · ⚠ enforcing ${SESSION}`)
  await $.turn.start({ text: 'go', turnId: 't1' })
  w.answers.push(failed('Blocked by PersonaKit contract: capability-deny.edit-files'))
  await write($)
  expect((await state(w)).drift).toEqual([{ tool: 'Write', actionClass: 'file-mutation', kind: 'blocked', turn: 1 }])
  expect(status(w)).toBe(`◇ no contract · ⚠ enforcing ${SESSION} · ⚠ drift: Write (file-mutation)`)
})

each('resume resets then rebuilds', async ($, w, surface) => {
  await resolve($, w, ok(otherContract))
  await $.session.end({ reason: 'resume', sessionId: 's1', resume: { id: 's1' } } as never)
  expect(status(w)).toBe(NO_CONTRACT)
  w.messages = [
    { role: 'user', text: 'resolve it', toolUses: [] },
    { role: 'assistant', text: '', toolUses: [{ tool_use_id: 'u1', tool: RESOLVE, input: {}, result: CONTRACT_JSON, text: CONTRACT_JSON }] },
  ]
  await start($, surface)
  expect(status(w)?.startsWith('◆ read-only-auditor_audit-pass')).toBe(true)
  const s = await state(w)
  expect(s.main?.ids.sessionId).toBe(SESSION)
  expect(s.turn).toBe(1)
})

each('session.start rebuilds only when state is empty', async ($, w, surface) => {
  // Empty state: the transcript's resolve and drift-worthy call are rebuilt, once.
  w.messages = [
    { role: 'user', text: 'go', toolUses: [] },
    {
      role: 'assistant',
      text: '',
      toolUses: [
        { tool_use_id: 'u1', tool: EXPORT, input: { sessionId: SESSION }, result: EXPORT_MD, text: EXPORT_MD },
        { tool_use_id: 'u2', tool: 'Write', input: { file_path: '/p/a', content: '' }, result: {}, text: 'ok' },
      ],
    },
  ]
  await start($, surface)
  let s = await state(w)
  expect(s.main?.ids.sessionId).toBe(SESSION)
  expect(s.drift.length).toBe(1)
  expect(status(w)).toBe(`${EXPORTED} · advisory · ⚠ drift: Write (file-mutation)`)
  await start($, surface)
  s = await state(w)
  expect(s.drift.length).toBe(1)

  // State holding a contract and a compaction: a hot reload keeps it.
  await $.session.compact({ trigger: 'manual', messages: SUMMARY })
  w.messages = []
  await start($, surface)
  s = await state(w)
  expect(s.main?.ids.sessionId).toBe(SESSION)
  expect(s.compactions).toBe(1)
  expect(status(w)).toBe('◆ read-only-auditor_audit-pass · Read-Only Auditor · advisory · ⚠ re-ground? · ⚠ drift: Write (file-mutation)')
})

each('settings are read on session.start and re-read on turn.complete', async ($, w, surface) => {
  w.files['/p/.claude/settings.json'] = JSON.stringify({ hooks: {} })
  await start($, surface)
  await ground($, w)
  expect(status(w)).toBe(`${STEADY} · advisory`)

  w.files['/p/.claude/settings.json'] = HOOKED_SETTINGS
  w.files[MANIFEST_PATH] = MANIFEST
  await turn($, 1)
  expect(status(w)).toBe(`${STEADY} · enforced`)
  expect((await state(w)).enforcement.kind).toBe('enforced')

  // A different resolve under the installed hook reads as enforcing the other contract.
  await resolve($, w, ok(otherContract))
  expect(status(w)?.endsWith(`· ⚠ enforcing ${SESSION}`)).toBe(true)
})

each('settings missing or not JSON leave enforcement advisory', async ($, w) => {
  await ground($, w)
  await turn($, 1)
  expect(status(w)).toBe(`${STEADY} · advisory`)
  w.files['/p/.claude/settings.json'] = '{ not json'
  await turn($, 2)
  expect(status(w)).toBe(`${STEADY} · advisory`)
})

each('an enforced denial is logged; a grep for the deny string is not', async ($, w) => {
  w.files['/p/.claude/settings.json'] = HOOKED_SETTINGS
  w.files[MANIFEST_PATH] = MANIFEST
  await ground($, w)
  await turn($, 1)
  w.answers.push(ok('Blocked by PersonaKit contract: capability-deny.edit-files'))
  await $.tool.call({ tool: 'Bash', command: 'grep "Blocked by PersonaKit contract" log' } as never)
  expect((await state(w)).drift).toEqual([])
  w.answers.push(failed('Blocked by PersonaKit contract: capability-deny.edit-files'))
  await write($)
  expect(status(w)).toBe(`${SHORT} · enforced · ⚠ drift: Write (file-mutation)`)
})

test('a configured server name is trusted', { options: { mcpServerName: 'pk' } }, async ($, on) => {
  const w = engine(on)
  await start($, 'desktop')
  w.answers.push(ok(CONTRACT_JSON))
  await $.tool.call({ tool: RESOLVE } as never)
  expect(status(w)).toBe(NO_CONTRACT)
  w.answers.push(ok(CONTRACT_JSON))
  await $.tool.call({ tool: 'mcp__pk__personakit_resolve_contract' } as never)
  expect(status(w)?.startsWith('◆ read-only-auditor_audit-pass')).toBe(true)
})
