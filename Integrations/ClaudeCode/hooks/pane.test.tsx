import { expect, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On } from 'claude-code'

import type { SessionState } from '../types'
import { CONTRACT_JSON, EXPORT_MD, LIST_ERRORS_JSON, LIST_JSON, LIST_MERGED_JSON } from './fixtures/golden'
import { usePrompt } from './lib/prompts'
import { rootsMismatchWarning } from './views/library'
import { highlightRuns } from './views/parts'

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
type Ran = { exitCode: number; stdout: string; stderr: string; isStdoutTruncated: boolean; isStderrTruncated: boolean }
const ran = (stdout: string, exitCode = 0, stderr = ''): Ran => ({ exitCode, stdout, stderr, isStdoutTruncated: false, isStderrTruncated: false })

/** The engine beneath the plugin, as register.test.ts stands it up, plus the prompt box and panes. */
function engine(on: On) {
  const answers: { result: unknown; text: string; isError?: true }[] = []
  const world = {
    answers, draft: '', fills: [] as Fill[], fillAnswer: { isFilled: true } as { isFilled: boolean; refusal?: 'dialog' | 'no_composer' },
    opens: [] as Record<string, unknown>[], isPlaced: true, toasts: [] as string[], logs: [] as string[], state: undefined as SessionState | undefined,
    files: {} as Record<string, string>,
    // `personakit` as the pane runs it: every argv, and what each run answers (a `deny` is the host refusing).
    runs: [] as (readonly string[])[], sessionWrites: 0, process: (() => ran(LIST_JSON)) as (argv: readonly string[]) => Ran | { deny: string },
  }
  on('state.set', (_, e, next) => {
    if (e.plugin === 'personakit' && e.key === 'session') {
      world.state = e.value as SessionState
      world.sessionWrites += 1
    }
    return next(e)
  })
  on('process.run', (_, e) => {
    world.runs.push(e.argv)
    const answer = world.process(e.argv)
    return ('deny' in answer ? answer : { value: answer }) as never
  })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('session.compact', (_, e) => ({ messages: e.messages }))
  on('turn.complete', (_, e) => ({ text: e.answer }))
  on('tool.call', () => (answers.shift() ?? { result: 'ok', text: 'ok' }) as never)
  on('fs.read', (_, e) => (e.path in world.files ? { value: world.files[e.path] } : { deny: `${e.path}: missing` }) as never)
  on('session.root', () => ({ value: '/p' }))
  on('session.messages', () => ({ value: [] }) as never)
  on('command.register', () => ({ value: { command: 'pk' } }))
  on('ui.open', (_, e) => {
    world.opens.push({ ...e })
    return { value: world.isPlaced ? { isPlaced: true as const } : { isPlaced: false as const, reason: 'no surface' } }
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
type Ui = Awaited<ReturnType<typeof mount>>
const text = async (ui: Ui, match: RegExp) => (await ui.find({ type: 'Text', text: match }))?.text
type Node = string | { type?: string; children?: Node[] }
const shown = (n: Node): string => (typeof n === 'string' ? n : (n.children ?? []).map(shown).join(''))
/** The outermost Texts' text under the element keyed `key`, in order: a Text nested in a Text reads as part of it. */
const texts = async (ui: Ui, key: string) => {
  const out: string[] = []
  const walk = (n: Node) => {
    if (typeof n === 'string') return
    if (n.type === 'Text') out.push(shown(n))
    else n.children?.forEach(walk)
  }
  walk((await ui.find({ key })) as Node)
  return out
}
const row = (ui: Ui, label: string) => texts(ui, `row-${label}`)
const chips = (ui: Ui) => texts(ui, 'chips')
/** Each chip's text and the color it reads in. */
const chipColors = async (ui: Ui) =>
  (((await ui.find({ key: 'chips' })) as { children?: { props?: { color?: unknown }; children?: Node[] }[] }).children ?? []).map(
    (chip) => [shown(chip as Node), chip.props?.color],
  )

const MANIFEST_PATH = '/p/.claude/personakit/read-only-auditor_audit-pass.checks.json'
const HOOKED_SETTINGS = JSON.stringify({
  hooks: {
    PreToolUse: [{ matcher: '.*', hooks: [{ type: 'command', command: `'/usr/local/bin/personakit' hook-check --manifest '${MANIFEST_PATH}'` }] }],
  },
})
const MANIFEST = JSON.stringify({
  sessionId: SESSION,
  personaId: 'read-only-auditor',
  directiveId: 'audit-pass',
  checks: [{ id: 'a', maxClass: 'hook', rule: { kind: 'capability-deny', deniedActionClasses: ['file-mutation', 'network-egress'] } }],
})

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
  expect(await text(ui, /^read-only-auditor_audit-pass$/)).toBe('read-only-auditor_audit-pass')
  expect(await text(ui, /^Resolved turn/)).toBe('Resolved turn 0 · this turn · MCP')
  expect(await chips(ui)).toEqual(['● Advisory', '● 1 compaction', '● 1 drift'])
  expect(await row(ui, 'Persona')).toEqual(['Persona', 'Read-Only Auditor (read-only-auditor)'])
  expect(await row(ui, 'Directive')).toEqual(['Directive', 'Read-only audit pass (audit-pass)'])
  expect(await row(ui, 'Goal')).toEqual(['Goal', 'Audit the change and report findings without editing it.'])
  expect(await texts(ui, 'step-1')).toEqual(['1', 'Inspect the diff and the surrounding code.'])
  expect(await texts(ui, 'step-2')).toEqual(['2', 'Report confirmed issues before suggestions.', '◆ stop'])
  expect(await row(ui, 'Mode')).toEqual(['Mode', 'project-only'])
  expect(await row(ui, 'State')).toEqual(['State', 'Advisory · no hook installed'])
  expect(await row(ui, 'Drift check')).toEqual(['Drift check', 'command-execution, file-mutation, network-egress · from the handoff context'])
  expect(await row(ui, 'Compactions')).toEqual(['Compactions', '1 · re-ground?'])
  expect(await text(ui, /^Write/)).toBe('Write not blocked · file-mutation · main · turn 0')
  // Clean authorization: no authorization block.
  expect(await ui.find({ key: 'row-Authorized' }).then((r) => r && texts(ui, 'row-Authorized'))).toEqual(['Authorized', 'none'])
  expect(await ui.find({ key: 'problem-0' })).toBe(undefined)
  expect(await ui.find({ type: 'Button', key: 'reground' })).toBeDefined()
  await ui.unmount()
})

each('a wrapped step keeps its later lines aligned with its text', async ($, w, surface) => {
  const long = 'Report confirmed issues before suggestions, citing the file and line for each, so that every finding satisfies the task.'
  await call($, w, EXPORT, EXPORT_MD.replace('Report confirmed issues before suggestions.', long), { sessionId: SESSION })
  const ui = await $.ui.mount({ ...PANE, surface, props: { ...PANE.props, bodyColumns: 30 } })
  expect((await ui.find({ key: 'pane' }))?.props.width).toBe(30)
  await ui.press({ key: 'toggle:contract:steps' })
  const row = (await ui.find({ key: 'step-2' }))!
  expect(row.props.flexDirection).toBe('row')
  const [number, body] = row.children as { props: Record<string, unknown>; text?: string }[]
  // The number column is fixed; the step text wraps inside the box beside it, never back under the number.
  expect(number?.props).toMatchObject({ width: '2. '.length, flexShrink: 0 })
  expect(body?.props).toMatchObject({ flexGrow: 1, flexShrink: 1 })
  expect(await texts(ui, 'step-2')).toEqual(['2', long, '◆ stop'])
  await ui.unmount()
})

each('label and number rows align to the top of their row', async ($, w, surface) => {
  await ground($, w)
  const ui = await mount($, surface)
  for (const key of ['row-Persona', 'row-Goal', 'row-Mode', 'step-1', 'step-2']) {
    expect((await ui.find({ key }))?.props.alignItems, key).toBe('flex-start')
  }
  await ui.unmount()
})

const LONG_STEP = 'Read the diff. Then read every file it touches, top to bottom, before writing anything down at all, ever.'
const longStepExport = () => EXPORT_MD.replace('1. Inspect the diff and the surrounding code.', `1. ${LONG_STEP}`)

each('the contract steps show their first lines until shown in full', async ($, w, surface) => {
  await call($, w, EXPORT, longStepExport(), { sessionId: SESSION })
  const ui = await mount($, surface)
  expect(await texts(ui, 'step-1')).toEqual(['1', 'Read the diff.'])
  expect(await texts(ui, 'step-2')).toEqual(['2', 'Report confirmed issues before suggestions.', '◆ stop'])
  expect((await ui.find({ key: 'toggle:contract:steps' }))?.text).toBe('Show full steps')
  expect(await text(ui, /^⏸/)).toBe(undefined)
  await ui.press({ key: 'toggle:contract:steps' })
  expect(await texts(ui, 'step-1')).toEqual(['1', LONG_STEP])
  expect((await ui.find({ key: 'toggle:contract:steps' }))?.text).toBe('Show first lines')
  await ui.unmount()
})

// An export seen, no contract JSON: `process.run` answers the pane's own `personakit contract` and `export`.
const exportOnly = (w: World) => {
  w.process = (argv) => (argv[1] === 'contract' ? ran(CONTRACT_JSON) : argv[1] === 'export' ? ran(EXPORT_MD) : ran(LIST_JSON))
}
const contractRuns = (w: World) => w.runs.filter((argv) => argv[1] === 'contract')

each('a contract with export details but no contract JSON is filled in from the CLI, labeled as read by the pane', async ($, w, surface) => {
  exportOnly(w)
  await call($, w, EXPORT, EXPORT_MD, { sessionId: SESSION })
  expect((w.state as SessionState).main?.contract).toBe(undefined)
  const before = await mount($, surface)
  expect(await text(before, /not seen/)).toBeDefined() // opened without /pk: nothing read yet
  await before.unmount()

  await pk($, '')
  expect(w.runs).toEqual([
    ['personakit', 'contract', `--session=${SESSION}`],
    ['personakit', 'export', `--session=${SESSION}`],
  ])
  const ui = await mount($, surface)
  expect(await text(ui, /not seen/)).toBe(undefined)
  expect(await text(ui, /read by the pane/)).toBeDefined()
  expect(await row(ui, 'Kits')).toEqual(['Kits', 'none'])
  expect(await row(ui, 'Mode')).toEqual(['Mode', 'project-only'])
  await ui.unmount()
})

each('switching to the Contract fills it in, and a Library refresh in between drops the fill so it is read again', async ($, w, surface) => {
  exportOnly(w)
  await call($, w, EXPORT, EXPORT_MD, { sessionId: SESSION })
  const ui = await mount($, surface)
  await ui.press({ key: 'switch-library' })
  expect(contractRuns(w)).toHaveLength(0)
  await ui.press({ key: 'switch-contract' })
  expect(contractRuns(w)).toHaveLength(1)
  expect(await text(ui, /read by the pane/)).toBeDefined()
  await ui.press({ key: 'switch-library' })
  await ui.press({ key: 'switch-contract' })
  expect(contractRuns(w)).toHaveLength(2)
  await ui.unmount()
})

each('a contract the session resolved is never read again by the pane', async ($, w, surface) => {
  await ground($, w)
  await pk($, '')
  const ui = await mount($, surface)
  await ui.press({ key: 'switch-library' })
  await ui.press({ key: 'switch-contract' })
  expect(contractRuns(w)).toHaveLength(0)
  expect(await text(ui, /read by the pane/)).toBe(undefined)
  await ui.unmount()
})

each('the fill-in never writes the session or changes main', async ($, w, surface) => {
  exportOnly(w)
  await call($, w, EXPORT, EXPORT_MD, { sessionId: SESSION })
  const main = (w.state as SessionState).main
  const writes = w.sessionWrites
  await pk($, '')
  const ui = await mount($, surface)
  await ui.press({ key: 'switch-library' })
  await ui.press({ key: 'switch-contract' })
  expect(w.runs.length).toBeGreaterThan(0)
  expect(w.sessionWrites).toBe(writes)
  expect((w.state as SessionState).main).toEqual(main)
  expect((w.state as SessionState).main?.contract).toBe(undefined)
  await ui.unmount()
})

each('a fill-in that cannot be read keeps the section as not seen and says why', async ($, w, surface) => {
  w.process = () => ran('', 2, 'no such session')
  await call($, w, EXPORT, EXPORT_MD, { sessionId: SESSION })
  await pk($, '')
  const ui = await mount($, surface)
  expect(await text(ui, /not seen/)).toBe("Kits, skills, and scope: not seen (the pane couldn't read them: no such session)")
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
  expect(await texts(ui, 'problem-0')).toEqual(['required skill swift-build is not authorized'])
  expect(await texts(ui, 'problem-1')).toEqual(['Unauthorized required: swift-build'])
  expect(await text(ui, /^false$/)).toBe('false')
  await ui.unmount()
})

each('a subagent resolution shows under subagent contracts', async ($, w, surface) => {
  await ground($, w)
  const helper = JSON.stringify({ ...JSON.parse(CONTRACT_JSON), sessionId: undefined, personaId: 'helper', directiveId: 'd' })
  w.answers.push(ok(helper))
  await $.tool.call({ tool: RESOLVE, agentId: 'a1' } as never)
  const ui = await mount($, surface)
  expect(await texts(ui, 'subagent-a1')).toEqual(['a1 helper › d · resolved turn 0 · MCP'])
  await ui.unmount()
})

each('with no contract the pane gives the /pk use hint and no Re-ground', async ($, _w, surface) => {
  const ui = await mount($, surface)
  expect(await text(ui, /^No contract/)).toBe('No contract in force')
  expect(await text(ui, /\/pk use/)).toBe('Run /pk use <session> to ground this session.')
  expect(await chipColors(ui)).toEqual([['● Advisory', 'inactive'], ['✓ No drift', 'success']])
  // Only the Contract | Library switch: nothing to Re-ground.
  expect((await ui.findAll({ type: 'Button' })).map((b) => b.key)).toEqual(['switch-contract', 'switch-library'])
  expect(await row(ui, 'Drift check')).toEqual(['Drift check', 'Off until handoff context is seen'])
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
  expect(w.fills[1]?.text.startsWith('\n')).toBe(true)

  // A whitespace-only draft is empty.
  w.draft = '  \n'
  await pk($, 'use s')
  expect(w.fills[2]?.mode).toBe('replace')
  expect(w.opens).toEqual([])
  expect(w.toasts).toEqual([])
})

each('/pk use with an id outside the id rule fills nothing and says so', async ($, w) => {
  const ran = await pk($, 'use .hidden')
  // Said once, in the reply, with the rule it broke.
  expect(ran.text).toBe(
    'Unsupported id: PersonaKit ids use only letters, digits, dots, underscores, and hyphens, and do not start with a dot. No prompt was pre-filled.',
  )
  expect(w.fills).toEqual([])
  expect(w.toasts).toEqual([])
})

each('a contract with an unsupported id is never resolved, so there is nothing to re-ground', async ($, w, surface) => {
  await call($, w, RESOLVE, JSON.stringify({ ...JSON.parse(CONTRACT_JSON), sessionId: '.hidden' }))
  const ui = await mount($, surface)
  expect(await ui.find({ key: 'reground' })).toBeUndefined()
  expect(w.fills).toEqual([])
  await ui.unmount()
})

each('/pk use _wip pre-fills --session=_wip', async ($, w) => {
  await pk($, 'use _wip')
  expect(w.fills).toEqual([{ text: usePrompt({ sessionId: '_wip' }), mode: 'replace' }])
  expect(w.fills[0]?.text).toContain('personakit contract --session=_wip')
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
  expect(w.fills[0]?.text).toContain('--persona=read-only-auditor --directive=audit-pass')
  await ui.unmount()
})

// The Library: `process.run` answers `personakit list all --json`; `/pk` opens the pane on the right view.
const IN_FORCE = SESSION
const listing = (change: (library: Record<string, any[]> & { scopes: Record<string, string> }) => void) => {
  const library = JSON.parse(LIST_JSON)
  change(library)
  return JSON.stringify(library)
}
const session = (id: string, personaId = 'read-only-auditor') => ({
  id, personaId, directiveId: 'audit-pass', kitOverrides: [], path: `Sessions/${id}.session.json`, scope: 'project', shadows: null, shadowedPath: null,
})
const keys = async (ui: Pick<Ui, 'findAll'>, type: string) => (await ui.findAll({ type })).map((b) => b.key)
const library = async ($: Engine, w: World, surface: Surface, list = LIST_JSON) => {
  w.process = () => ran(list)
  await pk($, '')
  return mount($, surface)
}

each('/pk opens on the Contract when one is in force, and loads nothing', async ($, w, surface) => {
  await ground($, w)
  await pk($, '')
  const ui = await mount($, surface)
  expect(await text(ui, /^CONTRACT$/)).toBe('CONTRACT')
  expect(await text(ui, /^PEOPLE/)).toBe(undefined)
  expect(w.runs).toEqual([])
  expect(w.opens).toEqual([{ id: 'personakit', title: 'PersonaKit' }])
  await ui.unmount()
})

each('/pk opens on the Library when none is in force, loading it once', async ($, w, surface) => {
  const ui = await library($, w, surface)
  expect(await text(ui, /^PEOPLE$/)).toBe('PEOPLE')
  expect(await text(ui, /^CONTRACT$/)).toBe(undefined)
  expect(w.runs).toEqual([['personakit', 'list', 'all', '--json']])
  await ui.unmount()
})

each('/pk that no surface places loads nothing', async ($, w) => {
  w.isPlaced = false
  await pk($, '')
  expect(w.runs).toEqual([])
})

test('the personakitPath option is the binary the Library runs', { options: { personakitPath: '/opt/pk/personakit' } }, async ($, on) => {
  const w = engine(on)
  await $.session.start({ cwd: '/p', surface: 'terminal', isInteractive: true })
  await pk($, '')
  expect(w.runs[0]).toEqual(['/opt/pk/personakit', 'list', 'all', '--json'])
  expect(w.logs).toEqual([])
})

each('switching to the Library loads it each time and never writes the session', async ($, w, surface) => {
  await ground($, w)
  await pk($, '')
  const ui = await mount($, surface)
  const writes = w.sessionWrites
  await ui.press({ key: 'switch-library' })
  expect(w.runs).toHaveLength(1)
  expect(await text(ui, /^PEOPLE$/)).toBe('PEOPLE')
  await ui.press({ key: 'switch-contract' })
  expect(await text(ui, /^CONTRACT$/)).toBe('CONTRACT')
  await ui.press({ key: 'switch-library' })
  expect(w.runs).toHaveLength(2)
  expect(w.sessionWrites).toBe(writes)
  await ui.unmount()
})

each('Use fills the grounding prompt for that session', async ($, w, surface) => {
  const ui = await library($, w, surface)
  await ui.press({ key: `use:${SESSION}` })
  expect(w.fills).toEqual([{ text: usePrompt({ sessionId: SESSION }), mode: 'replace' }])
  expect(await text(ui, /^Use$/)).toBe(undefined) // a Button, not a Text
  expect((await ui.find({ key: `use:${SESSION}` }))?.text).toBe('Use')
  await ui.unmount()
})

each('another session in force turns Use into Switch and marks the one in force', async ($, w, surface) => {
  await ground($, w)
  w.process = () => ran(listing((l) => l.sessions!.push(session('b-session'))))
  await pk($, '')
  const ui = await mount($, surface)
  await ui.press({ key: 'switch-library' })
  expect((await ui.find({ key: 'use:b-session' }))?.text).toBe('Switch')
  expect(await ui.find({ key: `use:${IN_FORCE}` })).toBe(undefined)
  expect(await texts(ui, `session-${IN_FORCE}`)).toContain('● in force')
  await ui.unmount()
})

each('a persona no session uses says so and has no Use button', async ($, w, surface) => {
  const ui = await library($, w, surface, listing((l) => (l.sessions = [])))
  expect(await texts(ui, 'person-read-only-auditor')).toContain('No session uses this persona yet.')
  expect(await keys(ui, 'Button')).not.toContain(`use:${SESSION}`)
  await ui.unmount()
})

each('a session whose persona is missing from the library keeps its row, badge and Use', async ($, w, surface) => {
  const ui = await library($, w, surface, listing((l) => l.sessions!.push(session('ghost-session', 'ghost'))))
  expect(await texts(ui, 'person-ghost')).toEqual(['ghost', '└ ', 'ghost-session', 'project'])
  expect(await ui.find({ key: 'open:persona:ghost' })).toBe(undefined)
  expect((await ui.find({ key: 'use:ghost-session' }))?.text).toBe('Use')
  expect(await ui.find({ key: 'open:session:ghost-session' })).toBeDefined()
  await ui.unmount()
})

each('the filter groups results by kind and keeps its text through Back', async ($, w, surface) => {
  const ui = await library($, w, surface, LIST_MERGED_JSON)
  await ui.input({ key: 'filter', text: 'style' })
  const captions = async () => (await ui.findAll({ type: 'Text', text: / · \d+$/ })).map((t) => t.text)
  expect(await captions()).toEqual(['PEOPLE · 1', 'DIRECTIVES · 1', 'KITS · 2', 'SKILLS · 2'])
  expect(await text(ui, /^PEOPLE$/)).toBe(undefined)
  expect(await keys(ui, 'Button')).toContain('open:kit:swift-style')

  await ui.press({ key: 'open:directive:apply-style' })
  expect(await ui.find({ key: 'filter' })).toBe(undefined)
  await ui.press({ key: 'back' })
  expect((await ui.find({ key: 'filter' }))?.props.value).toBe('style')
  expect(await captions()).toEqual(['PEOPLE · 1', 'DIRECTIVES · 1', 'KITS · 2', 'SKILLS · 2'])
  await ui.unmount()
})

each('a filter that matches nothing says so and keeps the field', async ($, w, surface) => {
  const ui = await library($, w, surface)
  await ui.input({ key: 'filter', text: 'zzz' })
  expect(await text(ui, /^Nothing matches/)).toBe('Nothing matches “zzz”.')
  expect((await ui.find({ key: 'filter' }))?.props.value).toBe('zzz')
  await ui.input({ key: 'filter', text: '' })
  expect(await text(ui, /^PEOPLE$/)).toBe('PEOPLE')
  await ui.unmount()
})

each('every row carries its scope in words', async ($, w, surface) => {
  const ui = await library($, w, surface, LIST_MERGED_JSON)
  expect(await texts(ui, 'person-architectural-editor')).toContain('project')
  expect(await texts(ui, 'person-senior-swiftui-engineer')).toContain('global')
  expect(await texts(ui, 'session-senior-swiftui-engineer_apply-style')).toEqual(['└ ', 'senior-swiftui-engineer_apply-style'])

  await ui.press({ key: 'list:kits' })
  expect(await texts(ui, 'kit-repo-constraints')).toContain('project · overrides global')
  expect(await texts(ui, 'kit-swift-style')).toContain('project · overrides global')
  expect(await texts(ui, 'kit-architectural-editor-core')).toEqual(['architectural-editor-core', 'project'])

  await ui.press({ key: 'back' })
  await ui.input({ key: 'filter', text: 'repo' })
  expect(await texts(ui, 'kit-repo-constraints')).toContain('project · overrides global')
  await ui.unmount()
})

each('a session shows its scope only when it differs from its persona or overrides', async ($, w, surface) => {
  const ui = await library($, w, surface, LIST_MERGED_JSON)
  // Same scope as the persona: no badge on the session, the persona's own line keeps its.
  expect(await texts(ui, 'person-architectural-editor')).toEqual(['project', '└ ', 'architectural-editor-review'])
  expect(await texts(ui, 'person-senior-swiftui-engineer')).toEqual(['global', '└ ', 'senior-swiftui-engineer_apply-style'])
  await ui.unmount()

  const differs = await library($, w, surface, listing((l) => l.sessions!.push({ ...session('g-session'), scope: 'global' })))
  expect(await texts(differs, 'person-read-only-auditor')).toEqual(['project', '├ ', 'g-session', 'global', '└ ', SESSION])
  await differs.unmount()

  const overrides = await library($, w, surface, listing((l) => (l.sessions![0]!.shadows = 'global')))
  expect(await texts(overrides, 'person-read-only-auditor')).toEqual(['project', '└ ', SESSION, 'project · overrides global'])
  await overrides.unmount()

  const global = JSON.parse(LIST_MERGED_JSON)
  global.sessions[1].scope = 'project'
  const reversed = await library($, w, surface, JSON.stringify(global))
  expect(await texts(reversed, 'person-senior-swiftui-engineer')).toEqual(['global', '└ ', 'senior-swiftui-engineer_apply-style', 'project'])
  await reversed.unmount()
})

each('a scope badge is plain styled words in the terminal and an outline where the surface can draw one', async ($, w, surface) => {
  const ui = await library($, w, surface, LIST_MERGED_JSON)
  // The terminal's filter field is bordered too, but it is not a badge.
  const outlines = (await ui.findAll({ type: 'Box' })).filter((b) => b.props.borderStyle !== undefined && b.key !== 'filter-field')
  // The badges on two rows, so the legend's own scope words are not the ones read.
  const badge = async (key: string, word: string) => {
    const found: { props: Record<string, unknown> }[] = []
    const walk = (n: Node & { props?: Record<string, unknown> }) => {
      if (typeof n === 'string') return
      if (n.type === 'Text' && shown(n) === word) found.push(n as { props: Record<string, unknown> })
      n.children?.forEach(walk)
    }
    walk((await ui.find({ key })) as Node)
    return found[0]
  }
  const project = await badge('person-architectural-editor', 'project')
  const global = await badge('person-senior-swiftui-engineer', 'global')
  if (surface === 'terminal') {
    expect(outlines).toEqual([])
    expect(project?.props).toMatchObject({ bold: true })
    expect(global?.props).toMatchObject({ dimColor: true })
  } else {
    expect(outlines.length).toBeGreaterThan(0)
    expect(outlines.map((b) => [b.props.borderStyle, b.props.borderDimColor ?? false])).toEqual(
      expect.arrayContaining([['round', false], ['round', true]]),
    )
  }
  await ui.unmount()
})

each('the legend names each root with its counts', async ($, w, surface) => {
  const ui = await library($, w, surface, LIST_MERGED_JSON)
  expect(await texts(ui, 'legend-project')).toEqual(['project  <PROJECT>  1 session · 1 persona'])
  expect(await texts(ui, 'legend-global')).toEqual(['global  <GLOBAL>  1 session · 1 persona'])
  await ui.unmount()
  const only = await library($, w, surface, LIST_JSON)
  expect(await texts(only, 'legend-project')).toEqual(['project  <ROOT>  1 session · 1 persona'])
  expect(await only.find({ key: 'legend-global' })).toBe(undefined)
  await only.unmount()
})

each('a kind list is sorted by display label, then id, and Back returns to the Library', async ($, w, surface) => {
  const directive = (id: string, title: string) => ({ ...JSON.parse(LIST_JSON).directives[0], id, entity: { ...JSON.parse(LIST_JSON).directives[0].entity, id, title } })
  const ui = await library($, w, surface, listing((l) => (l.directives = [directive('z-1', 'Alpha'), directive('a-2', 'beta'), directive('b-1', 'Alpha')])))
  await ui.press({ key: 'list:directives' })
  expect(await keys(ui, 'Button')).toEqual(['switch-contract', 'switch-library', 'back', 'open:directive:b-1', 'open:directive:z-1', 'open:directive:a-2'])
  expect((await ui.find({ key: 'back' }))?.text).toBe('‹ Library')
  await ui.press({ key: 'back' })
  expect(await text(ui, /^PEOPLE$/)).toBe('PEOPLE')
  expect(w.runs).toHaveLength(1) // Back is not a switch: nothing reloads
  await ui.unmount()
})

each('errors read as one document, grouped by scope and then path', async ($, w, surface) => {
  const errors = [
    { entityType: 'kit', id: 'k', message: 'no skills', path: null, scope: null },
    { entityType: 'persona', id: null, message: 'bad json', path: 'Packs/personas/b.persona.json', scope: 'global' },
    { entityType: 'persona', id: null, message: 'worse json', path: 'Packs/personas/a.persona.json', scope: 'project' },
    { entityType: 'skill', id: 's', message: 'dup', path: 'Packs/personas/a.persona.json', scope: 'project' },
  ]
  w.process = () => ran(JSON.stringify({ errors }), 1)
  await pk($, '')
  const ui = await mount($, surface)
  expect(await text(ui, /^The library didn't load/)).toBe("The library didn't load. Fix these and press Refresh:")
  expect(await ui.find({ key: 'refresh' })).toBeDefined()
  expect(await ui.find({ key: 'filter' })).toBe(undefined)
  const body = await texts(ui, 'pane')
  expect(body.slice(body.indexOf("The library didn't load. Fix these and press Refresh:") + 1)).toEqual([
    'project', 'Packs/personas/a.persona.json', 'persona: worse json', 'skill s: dup',
    'global', 'Packs/personas/b.persona.json', 'persona: bad json',
    'library', '(no file)', 'kit k: no skills',
  ])
  await ui.unmount()
})

each('the fixture errors document shows its one error and a Refresh that loads again', async ($, w, surface) => {
  w.process = () => ran(LIST_ERRORS_JSON, 1)
  await pk($, '')
  const ui = await mount($, surface)
  expect(await text(ui, /^persona:/)).toContain('Failed to decode JSON')
  await ui.press({ key: 'refresh' })
  expect(w.runs).toHaveLength(2)
  w.process = () => ran(LIST_JSON)
  await ui.press({ key: 'refresh' })
  expect(await text(ui, /^PEOPLE$/)).toBe('PEOPLE')
  await ui.unmount()
})

each('no library says where it looked', async ($, w, surface) => {
  w.process = () => ran('{"noLibrary":true}', 0)
  await pk($, '')
  const ui = await mount($, surface)
  expect(await text(ui, /^No PersonaKit library/)).toBe('No PersonaKit library here: no .personakit in this project and no ~/.personakit. Run `personakit init .personakit` to create one.')
  await ui.unmount()
})

each('a binary that will not start names itself and the option to set', async ($, w, surface) => {
  w.process = () => ({ deny: 'spawn personakit ENOENT' })
  await pk($, '')
  const ui = await mount($, surface)
  const shown = (await text(ui, /^Couldn't run personakit/))!
  expect(shown).toMatch(/^Couldn't run personakit: .+\. Set the personakitPath option if PersonaKit is installed elsewhere\.$/)
  await ui.unmount()
})

each('a CLI too old for the Library names the version it needs and what the CLI said', async ($, w, surface) => {
  w.process = () => ran('', 64, 'usage: personakit list <kind>')
  await pk($, '')
  const ui = await mount($, surface)
  expect(await text(ui, /^This needs PersonaKit/)).toBe('This needs PersonaKit 2.2.0 or later. usage: personakit list <kind>')
  await ui.unmount()
})

each('a CLI that timed out names itself without the personakitPath option', async ($, w, surface) => {
  w.process = () => ({ deny: 'command timed out after 30000ms' })
  await pk($, '')
  const ui = await mount($, surface)
  expect(await text(ui, /^Couldn't run personakit/)).toMatch(/^Couldn't run personakit: .*timed out after 30000ms\.$/)
  await ui.unmount()
})

each('a host that cannot run processes says the Library is not available and keeps the Contract', async ($, w, surface) => {
  w.process = () => ({ deny: 'process.run is not available on this host' })
  await pk($, '')
  const ui = await mount($, surface)
  expect(await text(ui, /^This host can't run PersonaKit/)).toBe(
    "This host can't run PersonaKit, so the Library isn't available here. The Contract view still works.",
  )
  expect(await ui.find({ key: 'refresh' })).toBe(undefined)
  await ui.press({ key: 'switch-contract' })
  expect(await text(ui, /^No contract in force/)).toBe('No contract in force')
  await ui.unmount()
})

test('mobile has no filter, and every Button is still there', async ($, on) => {
  const w = engine(on)
  await $.session.start({ cwd: '/p', surface: 'mobile', isInteractive: true })
  await pk($, '')
  const ui = await $.ui.mount({ ...PANE, surface: 'mobile' })
  expect(await ui.find({ key: 'filter' })).toBe(undefined)
  expect(await ui.findAll({ type: 'Input' })).toEqual([])
  expect(await keys(ui, 'Button')).toEqual([
    'switch-contract', 'switch-library', 'refresh', `open:persona:read-only-auditor`, `open:session:${SESSION}`, `use:${SESSION}`,
    'list:directives', 'list:kits', 'list:skills',
  ])
  await ui.press({ key: `use:${SESSION}` })
  expect(w.fills).toHaveLength(1)
  await ui.unmount()
})

each('a Library loaded from other roots than the contract in force warns', async ($, w, surface) => {
  const elsewhere = JSON.stringify({ ...JSON.parse(CONTRACT_JSON), scope: { mode: 'project-only', projectRoot: '/x' } })
  await call($, w, RESOLVE, elsewhere)
  await pk($, '')
  const ui = await mount($, surface)
  await ui.press({ key: 'switch-library' })
  expect(await text(ui, /^⚠/)).toBe('⚠ Library loaded from <ROOT>; the contract in force came from /x.')
  await ui.unmount()
})

each('a Library from the same roots as the contract in force does not warn', async ($, w, surface) => {
  await ground($, w)
  await pk($, '')
  const ui = await mount($, surface)
  await ui.press({ key: 'switch-library' })
  expect(await text(ui, /^⚠/)).toBe(undefined)
  expect(await text(ui, /^PEOPLE$/)).toBe('PEOPLE')
  await ui.unmount()
})

each('filter results put each match in its own highlighted run, and the words read the same', async ($, w, surface) => {
  const ui = await library($, w, surface, listing((l) => (l.directives![0]!.entity.title = 'Production audit pass')))
  await ui.input({ key: 'filter', text: 'PROD project' })
  const hit = (await ui.find({ key: 'open:directive:audit-pass' }))!
  expect(hit.text).toBe('Production audit pass')
  const runs = await ui.findAll({ type: 'Text', text: /^Prod$/ })
  expect(runs).toHaveLength(2) // the directive's row, and the session row that names it
  for (const run of runs) expect(run.props).toMatchObject({ weight: 'semibold', color: 'suggestion' })
  expect((await ui.find({ key: `open:session:${SESSION}` }))?.text).toBe('Production audit pass') // the session leads with it
  // The scope word filters by scope and is not styled as a match.
  const scope = await ui.findAll({ type: 'Text', text: /^project$/ })
  expect(scope.length).toBeGreaterThan(0)
  for (const word of scope) expect(word.props.color).not.toBe('suggestion')
  // Without a filter nothing is styled.
  await ui.input({ key: 'filter', text: '' })
  expect(await ui.findAll({ type: 'Text', text: /^Prod$/ })).toEqual([])
  await ui.unmount()
})

each('the filter is a bordered field in the terminal and bare elsewhere', async ($, w, surface) => {
  const ui = await library($, w, surface)
  const field = await ui.find({ key: 'filter-field' })
  const input = await ui.find({ key: 'filter' })
  expect(input).toMatchObject({ type: 'Input', props: { label: 'Filter', placeholder: 'id, name, project or global' } })
  if (surface === 'terminal') {
    expect(field).toMatchObject({ type: 'Box', props: { borderStyle: 'round', paddingX: 1 } })
    expect(field?.children?.map((c) => (c as { type?: string }).type)).toEqual(['Input'])
  } else {
    expect(field).toBe(undefined)
  }
  await ui.input({ key: 'filter', text: 'audit' }) // still the same handler
  expect((await ui.find({ key: 'filter' }))?.props.value).toBe('audit')
  await ui.unmount()
})

each('a person row leads with the persona, and each session with its directive title and then its id', async ($, w, surface) => {
  const ui = await library($, w, surface)
  expect((await ui.find({ key: 'open:persona:read-only-auditor' }))?.text).toBe('Read-Only Auditor')
  expect((await ui.find({ key: `open:session:${SESSION}` }))?.text).toBe('Read-only audit pass')
  // Persona: badge only, no id. Session: connector, id; its badge only repeats the persona's scope. The links and Use are Buttons, not Texts.
  expect(await texts(ui, 'person-read-only-auditor')).toEqual(['project', '└ ', SESSION])
  await ui.press({ key: `open:session:${SESSION}` })
  expect(await ui.find({ key: 'filter' })).toBe(undefined) // the session's detail view
  await ui.unmount()
})

each('the persona id shows only when a filter word matches it and nothing else on the row', async ($, w, surface) => {
  const ui = await library($, w, surface, listing((l) => (l.sessions![0]!.id = 'audit-1')))
  const id = async () => (await texts(ui, 'person-read-only-auditor')).filter((t) => t === 'read-only-auditor')
  expect(await id()).toEqual([])
  await ui.input({ key: 'filter', text: 'only-aud' }) // the id alone has it: not the name ("Read-Only Auditor") nor the session
  expect(await id()).toEqual(['read-only-auditor'])
  const runs = await ui.findAll({ type: 'Text', text: /^only-aud$/ })
  expect(runs).toHaveLength(1)
  expect(runs[0]?.props).toMatchObject({ weight: 'semibold', color: 'suggestion' })
  await ui.input({ key: 'filter', text: 'auditor' }) // the name has it too
  expect(await id()).toEqual([])
  await ui.input({ key: 'filter', text: 'audit-1' }) // the session id has it
  expect(await id()).toEqual([])
  await ui.input({ key: 'filter', text: 'only-aud project' }) // a scope word is not text
  expect(await id()).toEqual(['read-only-auditor'])
  await ui.unmount()
})

each('a filter word in the session id is highlighted after the directive title', async ($, w, surface) => {
  const ui = await library($, w, surface)
  await ui.input({ key: 'filter', text: 'pass' })
  expect((await ui.find({ key: `open:session:${SESSION}` }))?.text).toBe('Read-only audit pass')
  expect(await texts(ui, 'person-read-only-auditor')).toEqual(['project', '└ ', 'pass', SESSION])
  const runs: { props: Record<string, unknown> }[] = []
  const walk = (n: Node & { props?: Record<string, unknown> }) => {
    if (typeof n === 'string') return
    if (n.type === 'Text' && shown(n) === 'pass') runs.push(n as { props: Record<string, unknown> })
    n.children?.forEach(walk)
  }
  walk((await ui.find({ key: 'person-read-only-auditor' })) as Node)
  expect(runs).toHaveLength(2) // the directive title on the link, and the session id after it
  for (const run of runs) expect(run.props).toMatchObject({ weight: 'semibold', color: 'suggestion' })
  await ui.unmount()
})

each('session lines hang under a connector: ├ before the last session, └ on it and on the no-session line', async ($, w, surface) => {
  const ui = await library($, w, surface, listing((l) => l.sessions!.push(session('z-session'))))
  const lines = async () => (await texts(ui, 'person-read-only-auditor')).filter((t) => t === '├ ' || t === '└ ')
  expect(await lines()).toEqual(['├ ', '└ '])
  for (const id of [SESSION, 'z-session']) {
    const line = (await ui.find({ key: `session-${id}` }))!
    expect(line).toMatchObject({ type: 'Box', props: { marginLeft: 2, flexDirection: 'row' } })
    const [connector, rest] = line.children as { type: string; props: Record<string, unknown> }[]
    expect(connector).toMatchObject({ type: 'Box', props: { width: 2, flexShrink: 0 } })
    expect(rest).toMatchObject({ type: 'Box', props: { flexDirection: 'row', flexWrap: 'wrap', flexShrink: 1 } })
  }
  await ui.unmount()
  const none = await library($, w, surface, listing((l) => (l.sessions = [])))
  expect(await texts(none, 'person-read-only-auditor')).toEqual(['project', '└ ', 'No session uses this persona yet.'])
  await none.unmount()
})

each('the People caption sits under its title on the home and not on filter results', async ($, w, surface) => {
  const ui = await library($, w, surface)
  const caption = 'Who you can work with, and the jobs you can start with them.'
  expect(await text(ui, /^Who you can/)).toBe(caption)
  const section = (await ui.find({ key: 'section-People' }))!
  expect((section.children as { type: string; props: Record<string, unknown> }[])[1]).toMatchObject({ type: 'Text', props: { dimColor: true } })
  await ui.input({ key: 'filter', text: 'audit' })
  expect(await text(ui, /^PEOPLE · 1$/)).toBe('PEOPLE · 1')
  expect(await text(ui, /^Who you can/)).toBe(undefined)
  await ui.unmount()
})

each('the kind lists sit under Components', async ($, w, surface) => {
  const ui = await library($, w, surface)
  expect(await text(ui, /^COMPONENTS$/)).toBe('COMPONENTS')
  expect(await text(ui, /BUILDING/i)).toBe(undefined)
  await ui.unmount()
})

test('highlightRuns cuts every match, longest word first, and rejoins to the text', () => {
  expect(highlightRuns('Production audit', ['prod', 'AUDIT']).map((r) => [r.text, r.isMatch])).toEqual([
    ['Prod', true], ['uction ', false], ['audit', true],
  ])
  expect(highlightRuns('a.b a.b', ['a.b']).filter((r) => r.isMatch)).toHaveLength(2) // regex characters are literal
  expect(highlightRuns('swift swiftui', ['swift', 'swiftui']).map((r) => r.text)).toEqual(['swift', ' ', 'swiftui'])
  expect(highlightRuns('plain', [])).toEqual([{ text: 'plain', isMatch: false }])
  expect(highlightRuns('', ['x'])).toEqual([{ text: '', isMatch: false }])
})

test('rootsMismatchWarning compares the sets of roots, not their keys', () => {
  const warn = rootsMismatchWarning
  expect(warn({ mode: 'project-only', projectRoot: '/x' }, { project: '/p' })).toBe(
    '⚠ Library loaded from /p; the contract in force came from /x.',
  )
  expect(warn({ mode: 'project+global', projectRoot: '/p', globalRoot: '/g' }, { project: '/p' })).toBe(
    '⚠ Library loaded from /p; the contract in force came from /p, /g.',
  )
  expect(warn({ mode: 'project-only', projectRoot: '/p' }, { project: '/p', global: '/g' })).toBe(
    '⚠ Library loaded from /p, /g; the contract in force came from /p.',
  )
  // The CLI reports an equal project and global root once, as `global`.
  expect(warn({ mode: 'project+global', projectRoot: '/g', globalRoot: '/g' }, { global: '/g' })).toBe(undefined)
  expect(warn({ mode: 'project+global', projectRoot: '/p', globalRoot: '/g' }, { global: '/g', project: '/p' })).toBe(undefined)
  expect(warn({ mode: 'global-only', globalRoot: '/g' }, { global: '/g' })).toBe(undefined)
  expect(warn(undefined, { project: '/p' })).toBe(undefined)
  expect(warn({ mode: 'project-only' }, { project: '/p' })).toBe(undefined)
})

for (const surface of SURFACES) {
  test(`an installed hook reads in plain words: what it blocks, what it checks, and that drift check is off (${surface})`, async ($, on) => {
  const w = engine(on)
  w.files['/p/.claude/settings.json'] = HOOKED_SETTINGS
  w.files[MANIFEST_PATH] = MANIFEST
  await $.session.start({ cwd: '/p', surface, isInteractive: true })
  let ui = await mount($, surface)
  // A hook with nothing resolved names its contract as a warning: nothing contradicts it yet.
  expect(await chipColors(ui)).toEqual([[`● Enforcing ${SESSION}`, 'warning'], ['✓ No drift', 'success']])
  expect(await row(ui, 'State')).toEqual(['State', `⚠ Enforcing ${SESSION}`])
  await ui.unmount()
  await ground($, w)
  ui = await mount($, surface)
  expect(await chipColors(ui)).toEqual([['● Enforced', 'success'], ['✓ No drift', 'success']])
  expect(await row(ui, 'State')).toEqual(['State', 'Enforced'])
  expect(await row(ui, 'Blocks')).toEqual(['Blocks', 'file-mutation, network-egress'])
  expect(await row(ui, 'Checks')).toEqual(['Checks', 'every tool call'])
  expect(await row(ui, 'Drift check')).toEqual(['Drift check', 'Off while a PersonaKit hook is installed'])
  await ui.unmount()
  expect(w.logs).toEqual([])
  })
}

each('an unreadable manifest blocks every tool call the hook checks, and the pane says so', async ($, w, surface) => {
  w.files['/p/.claude/settings.json'] = HOOKED_SETTINGS
  w.files[MANIFEST_PATH] = '{ not json'
  await $.turn.complete({ answer: 'done', durationMs: 1, isAborted: false, turnId: 't0', reason: 'answer' } as never)
  const ui = await mount($, surface)
  expect(await row(ui, 'State')).toEqual(['State', '⚠ Manifest unreadable'])
  expect(await row(ui, 'Blocks')).toEqual(['Blocks', 'every tool call it checks'])
  await ui.unmount()
})
