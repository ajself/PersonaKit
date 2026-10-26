import { expect, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On } from 'claude-code'

import type { SessionState } from '../types'
import { CONTRACT_JSON, EXPORT_MD } from './fixtures/golden'
import { usePrompt } from './lib/prompts'

const SESSION = 'read-only-auditor_audit-pass'
const RESOLVE = 'mcp__personakit__personakit_resolve_contract'
const EXPORT = 'mcp__personakit__personakit_export'
const SURFACES = ['terminal', 'desktop'] as const
type Surface = (typeof SURFACES)[number]

const PANE = {
  plugin: 'personakit',
  component: 'Pane',
  requestId: 'personakit',
  props: { title: 'PersonaKit', isFocused: false, bodyColumns: 60, placement: 'dock', scroll: { offset: 0, bodyRows: 40 }, view: {} },
} as const

type Fill = { text: string; mode: string }

/** The engine beneath the plugin, as register.test.ts stands it up, plus the prompt box and panes. */
function engine(on: On) {
  const answers: { result: unknown; text: string; isError?: true }[] = []
  const world = {
    answers, draft: '', fills: [] as Fill[], fillAnswer: { isFilled: true } as { isFilled: boolean; refusal?: 'dialog' | 'no_composer' },
    opens: [] as Record<string, unknown>[], isPlaced: true, toasts: [] as string[], logs: [] as string[], state: undefined as SessionState | undefined,
  }
  on('state.set', (_, e, next) => {
    if (e.plugin === 'personakit' && e.key === 'session') world.state = e.value as SessionState
    return next(e)
  })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('session.compact', (_, e) => ({ messages: e.messages }))
  on('tool.call', () => (answers.shift() ?? { result: 'ok', text: 'ok' }) as never)
  on('fs.read', (_, e) => ({ deny: `${e.path}: missing` }) as never)
  on('session.root', () => ({ value: '/p' }))
  on('session.messages', () => ({ value: [] }) as never)
  on('command.register', () => ({ value: { command: 'pk' } }))
  on('ui.open', (_, e) => {
    world.opens.push({ ...e })
    return { value: { isPlaced: world.isPlaced } }
  })
  on('prompt.read', () => ({ value: { text: world.draft, cursor: world.draft.length } }))
  on('prompt.fill', (_, e) => {
    world.fills.push({ text: e.text, mode: e.mode })
    return world.fillAnswer
  })
  on('ui.status', () => ({ value: undefined }))
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

const ok = (text: string) => ({ result: text, text })
const call = ($: Engine, w: World, tool: string, answer: string, input: Record<string, unknown> = {}) => {
  w.answers.push(ok(answer))
  return $.tool.call({ tool, ...input } as never)
}
const ground = async ($: Engine, w: World) => {
  await call($, w, RESOLVE, CONTRACT_JSON)
  await call($, w, EXPORT, EXPORT_MD, { sessionId: SESSION })
}
const mount = ($: Engine, surface: Surface) => $.ui.mount({ ...PANE, surface })
const pk = ($: Engine, args: string) =>
  $.command.run({ command: 'pk', args, origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 160 } } as never)
const text = async (ui: Awaited<ReturnType<typeof mount>>, match: RegExp) => (await ui.find({ type: 'Text', text: match }))?.text

const each = (name: string, body: ($: Engine, w: World, surface: Surface) => Promise<void>) => {
  for (const surface of SURFACES) {
    test(`${name} (${surface})`, async ($, on) => {
      const w = engine(on)
      await $.session.start({ cwd: '/p', surface, isInteractive: true })
      await body($, w, surface)
      expect(w.logs).toEqual([])
    })
  }
}

each('the pane shows the golden contract, its enforcement, freshness, and drift', async ($, w, surface) => {
  await ground($, w)
  await $.session.compact({ trigger: 'manual', messages: [{ role: 'user', text: 'summary', toolUses: [] }] })
  await $.tool.call({ tool: 'Write', file_path: '/p/a.txt', content: 'x' } as never)
  const ui = await mount($, surface)

  expect((await ui.find({ key: 'pane' }))?.props.width).toBe(60)
  expect(await text(ui, /^read-only-auditor_audit-pass/)).toBe('read-only-auditor_audit-pass · resolved turn 0 (this turn) · MCP')
  expect(await text(ui, /Read-Only Auditor/)).toBe('Persona: Read-Only Auditor (read-only-auditor)')
  expect(await text(ui, /Read-only audit pass/)).toBe('Directive: Read-only audit pass (audit-pass)')
  expect(await text(ui, /^Goal:/)).toBe('Goal: Audit the change and report findings without editing it.')
  expect(await text(ui, /Inspect the diff/)).toBe('Inspect the diff and the surrounding code.')
  expect(await text(ui, /^  1\.$/)).toBe('  1.')
  expect(await text(ui, /Report confirmed issues/)).toBe('Report confirmed issues before suggestions. (stop for review)')
  expect(await text(ui, /^■ 2\.$/)).toBe('■ 2.')
  expect(await text(ui, /^Mode:/)).toBe('Mode: project-only')
  expect(await text(ui, /^Enforcement:/)).toBe('Enforcement: advisory (no PersonaKit hook installed)')
  expect(await text(ui, /^Advisory drift:/)).toBe('Advisory drift: command-execution, file-mutation, network-egress (from the export)')
  expect(await text(ui, /^Compactions since resolve:/)).toBe('Compactions since resolve: 1 · re-ground?')
  expect(await text(ui, /^Write/)).toBe('Write (file-mutation) · advisory · main · turn 0')
  // Clean authorization: no authorization block.
  expect(await text(ui, /^Authorized:/)).toBe(undefined)
  expect(await ui.find({ type: 'Button', key: 'reground' })).toBeDefined()
  await ui.unmount()
})

each('a wrapped step keeps its later lines aligned with its text', async ($, w, surface) => {
  const long = 'Report confirmed issues before suggestions, citing the file and line for each, so that every finding satisfies the task.'
  await call($, w, EXPORT, EXPORT_MD.replace('Report confirmed issues before suggestions.', long), { sessionId: SESSION })
  const ui = await $.ui.mount({ ...PANE, surface, props: { ...PANE.props, bodyColumns: 30 } })
  expect((await ui.find({ key: 'pane' }))?.props.width).toBe(30)
  const row = (await ui.find({ key: 'step-2' }))!
  expect(row.props.flexDirection).toBe('row')
  const [marker, body] = row.children as { props: Record<string, unknown>; text?: string }[]
  // The marker column is fixed; the step text wraps inside the box beside it, never back under the marker.
  expect(marker.props).toMatchObject({ width: '■ 2. '.length, flexShrink: 0 })
  expect(body.props).toMatchObject({ flexGrow: 1, flexShrink: 1 })
  expect(await text(ui, /citing the file/)).toBe(`${long} (stop for review)`)
  await ui.unmount()
})

each('authorization that is not clean shows its failure reasons', async ($, w, surface) => {
  const unauthorized = JSON.stringify({
    ...JSON.parse(CONTRACT_JSON),
    isAuthorized: false,
    failureReasons: ['required skill swift-build is not authorized'],
    unauthorizedRequiredSkillIds: ['swift-build'],
  })
  await call($, w, RESOLVE, unauthorized)
  const ui = await mount($, surface)
  expect(await text(ui, /^Authorized:/)).toBe('Authorized: false')
  expect(await text(ui, /required skill swift-build/)).toBe('  required skill swift-build is not authorized')
  expect(await text(ui, /^Unauthorized required:/)).toBe('Unauthorized required: swift-build')
  await ui.unmount()
})

each('a subagent resolution shows under subagent contracts', async ($, w, surface) => {
  await ground($, w)
  const helper = JSON.stringify({ ...JSON.parse(CONTRACT_JSON), sessionId: undefined, personaId: 'helper', directiveId: 'd' })
  w.answers.push(ok(helper))
  await $.tool.call({ tool: RESOLVE, agentId: 'a1' } as never)
  const ui = await mount($, surface)
  expect(await text(ui, /^a1:/)).toBe('a1: helper › d · resolved turn 0 · MCP')
  await ui.unmount()
})

each('with no contract the pane gives the /pk use hint and no Re-ground', async ($, _w, surface) => {
  const ui = await mount($, surface)
  expect(await text(ui, /\/pk use/)).toBe('No contract in force. Run /pk use <session> to ground this session.')
  expect(await ui.findAll({ type: 'Button' })).toEqual([])
  expect(await text(ui, /^Advisory drift:/)).toBe('Advisory drift: off until an export is seen')
  await ui.unmount()
})

each('/pk opens the pane, never focused', async ($, w) => {
  await pk($, '')
  expect(w.opens).toEqual([{ id: 'personakit', title: 'PersonaKit' }])
  expect(w.fills).toEqual([])
})

each('/pk use s fills the prompt', async ($, w) => {
  await pk($, 'use s')
  expect(w.fills).toEqual([{ text: usePrompt({ sessionId: 's' }), mode: 'replace' }])

  w.draft = 'draft'
  await pk($, '  use   s  ')
  expect(w.fills[1]).toEqual({ text: `\n${usePrompt({ sessionId: 's' })}`, mode: 'append' })
  expect(w.fills[1].text.startsWith('\n')).toBe(true)

  // A whitespace-only draft is empty.
  w.draft = '  \n'
  await pk($, 'use s')
  expect(w.fills[2].mode).toBe('replace')
  expect(w.opens).toEqual([])
  expect(w.toasts).toEqual([])
})

each('/pk use with no session replies with usage and fills nothing', async ($, w) => {
  const ran = await pk($, 'use')
  expect(ran.text).toBe('Usage: /pk use <session>')
  expect(w.fills).toEqual([])
  const other = await pk($, 'nonsense')
  expect(other.text).toBe('Usage: /pk opens the PersonaKit pane; /pk use <session> pre-fills a grounding prompt.')
  expect(w.fills).toEqual([])
})

each('/pk use toasts the prompt when a hook keeps the fill out without a refusal', async ($, w) => {
  w.fillAnswer = { isFilled: false }
  await pk($, 'use s')
  expect(w.toasts).toEqual([usePrompt({ sessionId: 's' })])
})

each('/pk says so when no surface places the pane', async ($, w) => {
  w.isPlaced = false
  expect((await pk($, '')).text).toBe('No surface here can show the PersonaKit pane.')
})

each('/pk use toasts the prompt when the fill is refused', async ($, w) => {
  w.fillAnswer = { isFilled: false, refusal: 'dialog' }
  await pk($, 'use s')
  expect(w.toasts).toEqual([usePrompt({ sessionId: 's' })])
})

each('Re-ground fills with the current ids', async ($, w, surface) => {
  await ground($, w)
  const ids = (w.state as SessionState).main!.ids
  const ui = await mount($, surface)
  await ui.press({ key: 'reground' })
  expect(w.fills).toEqual([{ text: usePrompt(ids), mode: 'replace' }])
  expect(w.toasts).toEqual([])

  w.fillAnswer = { isFilled: false, refusal: 'dialog' }
  await ui.press({ key: 'reground' })
  expect(w.toasts).toEqual([usePrompt(ids)])
  await ui.unmount()
})

test('Re-ground fills with persona and directive when the contract has no session id', async ($, on) => {
  const w = engine(on)
  await $.session.start({ cwd: '/p', surface: 'desktop', isInteractive: true })
  const personaOnly = JSON.stringify({ ...JSON.parse(CONTRACT_JSON), sessionId: undefined })
  await call($, w, RESOLVE, personaOnly)
  const ui = await mount($, 'desktop')
  await ui.press({ key: 'reground' })
  expect(w.fills).toEqual([{ text: usePrompt({ personaId: 'read-only-auditor', directiveId: 'audit-pass' }), mode: 'replace' }])
  expect(w.fills[0].text).toContain('--persona read-only-auditor --directive audit-pass')
  await ui.unmount()
})
