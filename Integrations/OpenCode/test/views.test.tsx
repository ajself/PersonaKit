import { afterEach, expect, test } from 'bun:test'
import type { TuiPluginApi, TuiRouteDefinition, TuiToast } from '@opencode-ai/plugin/tui'
import { RGBA, TextAttributes } from '@opentui/core'
import { testRender } from '@opentui/solid'
import { createSignal } from 'solid-js'
import type { SessionState, View } from '../../ClaudeCode/types'
import { CONTRACT_JSON, EXPORT_MD, LIST_ERRORS_JSON, LIST_JSON, LIST_MERGED_JSON } from '../../ClaudeCode/hooks/fixtures/golden.ts'
import { usePrompt } from '../../ClaudeCode/hooks/lib/prompts.ts'
import type { ProcessRunResult, RunnerDollar } from '../../ClaudeCode/hooks/lib/runner.ts'
import { initial } from '../../ClaudeCode/hooks/lib/session.ts'
import { registerRoute } from '../src/tui/route.tsx'
import { chipText, MANIFEST_CHANGED } from '../src/tui/views/chip.tsx'
import plugin from '../src/tui.tsx'

const MAIN = 'ses_main'
const SESSION = 'read-only-auditor_audit-pass'
const ESC_ID_JSON = 'a\\u001b[2Jb'

type Command = { name: string; run: (ctx?: unknown) => unknown }
type Layer = { commands?: Command[]; bindings?: { key: string; cmd?: unknown }[] }

const ran = (stdout: string, exitCode = 0): ProcessRunResult => ({ stdout, stderr: '', exitCode })

/** `personakit` as the route runs it: the library, then a contract and an export per session. Each call is recorded. */
function fakeRunner(list: string = LIST_JSON, listExit = 0, exportMd: string = EXPORT_MD) {
  const runs: (readonly string[])[] = []
  const pending: { argv: readonly string[]; resolve: (r: ProcessRunResult) => void }[] = []
  let isHeld = false
  const answer = (argv: readonly string[]): ProcessRunResult =>
    argv[1] === 'contract' ? ran(CONTRACT_JSON) : argv[1] === 'export' ? ran(exportMd) : ran(list, listExit)
  const runner: RunnerDollar = {
    process: {
      run: (argv) => {
        runs.push(argv)
        if (!isHeld) return Promise.resolve(answer(argv))
        return new Promise((resolve) => pending.push({ argv, resolve }))
      },
    },
  }
  return {
    runner,
    runs,
    /** Holds every later call until `release`; each is answered then with `answer`, or the given output. */
    hold: () => void (isHeld = true),
    release: (index: number, result?: ProcessRunResult) => {
      const call = pending[index]!
      call.resolve(result ?? answer(call.argv))
    },
    pending,
  }
}

/** A fake `TuiPluginApi` that records routes, key layers, navigations, toasts and appended prompt text. */
function fakeApi() {
  const record = {
    routes: [] as TuiRouteDefinition[],
    unregistered: 0,
    layers: [] as Layer[],
    removedLayers: 0,
    navigations: [] as { name: string; params?: Record<string, unknown> }[],
    appended: [] as string[],
    toasts: [] as TuiToast[],
    events: [] as string[],
  }
  const api = {
    route: {
      current: { name: 'session', params: { sessionID: MAIN } },
      navigate: (name: string, params?: Record<string, unknown>) => {
        record.events.push(`navigate:${name}`)
        record.navigations.push({ name, params })
      },
      register: (routes: TuiRouteDefinition[]) => {
        record.routes.push(...routes)
        return () => void (record.unregistered += 1)
      },
    },
    keymap: {
      registerLayer: (layer: Layer) => {
        record.layers.push(layer)
        return () => void (record.removedLayers += 1)
      },
    },
    ui: { toast: (toast: TuiToast) => void record.toasts.push(toast) },
    client: {
      tui: {
        appendPrompt: async (input: { text?: string }) => {
          record.events.push('append')
          record.appended.push(input.text ?? '')
          return { data: true, error: undefined }
        },
      },
    },
    theme: {
      current: {
        warning: '#ffaa00', textMuted: '#888888', text: '#ffffff', success: '#00ff00', error: '#ff0000', primary: '#4488ff',
        selectedListItemText: '#000000', background: '#000000', border: '#444444', accent: '#ff00ff',
      },
    },
  }
  return { api: api as unknown as TuiPluginApi, record }
}

const renderers: { destroy(): void }[] = []
afterEach(() => {
  while (renderers.length) renderers.pop()!.destroy()
})

/** Registers the route and renders it opened with `params`; `frame` waits for a frame that passes `predicate`. */
async function open(
  opts: {
    list?: string
    listExit?: number
    view?: View
    sessionID?: string | null
    session?: () => SessionState
    manifestChanged?: boolean
    exportMd?: string
    height?: number
  } = {},
) {
  const fake = fakeApi()
  const runner = fakeRunner(opts.list, opts.listExit ?? 0, opts.exportMd)
  const dispose = registerRoute(fake.api, {
    runner: runner.runner,
    binary: 'personakit',
    session: opts.session ?? (() => initial),
    manifestChanged: () => opts.manifestChanged ?? false,
  })
  const route = fake.record.routes.find((r) => r.name === 'personakit')
  if (!route) throw new Error('no personakit route')
  const params: Record<string, unknown> = {}
  if (opts.sessionID !== null) params.sessionID = opts.sessionID ?? MAIN
  if (opts.view) params.view = opts.view
  const setup = await testRender(() => route.render({ params }), { width: 140, height: opts.height ?? 60 })
  renderers.push(setup.renderer)
  const frame = async (predicate: (frame: string) => boolean): Promise<string> => {
    let last = ''
    for (let i = 0; i < 200; i++) {
      await setup.renderOnce()
      last = setup.captureCharFrame()
      if (predicate(last)) return last
      await new Promise((resolve) => setTimeout(resolve, 5))
    }
    throw new Error(`timed out waiting for a frame; last:\n${last}`)
  }
  /** Clicks the first occurrence of `text` in the current frame. */
  const click = async (text: string) => {
    const lines = (await frame((f) => f.includes(text))).split('\n')
    const row = lines.findIndex((line) => line.includes(text))
    await setup.mockMouse.click(lines[row]!.indexOf(text) + 1, row)
    await setup.renderOnce()
  }
  const command = (name: string) => {
    const found = fake.record.layers.flatMap((layer) => layer.commands ?? []).find((c) => c.name === name)
    if (!found) throw new Error(`no command ${name}`)
    return async () => {
      await found.run()
      await setup.renderOnce()
    }
  }
  return { ...fake, ...runner, setup, frame, click, command, dispose }
}

const settle = () => new Promise((resolve) => setTimeout(resolve, 20))

const until = async (check: () => boolean, what: string) => {
  for (let i = 0; i < 200; i++) {
    if (check()) return
    await new Promise((resolve) => setTimeout(resolve, 5))
  }
  throw new Error(`timed out waiting for ${what}`)
}

test('libraryListsPeopleWithSessions', async () => {
  const r = await open({ view: { kind: 'library' } })
  const frame = await r.frame((f) => f.includes('Read-Only Auditor'))
  expect(frame).toContain('PEOPLE')
  expect(frame).toContain('Who you can work with, and the jobs you can start with them.')
  expect(frame).toContain('Read-only audit pass')
  expect(frame).toContain(SESSION)
  expect(frame).toContain('[ Use ]')
  expect(frame).toContain('COMPONENTS')
  expect(frame).toContain('1 session · 1 persona')
  expect(r.runs).toEqual([['personakit', 'list', 'all', '--json']])
})

test('scopeBadgeIsWords', async () => {
  const r = await open({ list: LIST_MERGED_JSON, view: { kind: 'list', of: 'kits' } })
  const frame = await r.frame((f) => f.includes('Repository Constraints Kit'))
  expect(frame).toContain('project · overrides global')
  expect(frame).toContain('4 kits')
})

test('libraryErrorsListed', async () => {
  const r = await open({ list: LIST_ERRORS_JSON, listExit: 1, view: { kind: 'library' } })
  const frame = await r.frame((f) => f.includes('broken.persona.json'))
  expect(frame).toContain("The library didn't load. Fix these and press Refresh:")
  expect(frame).toContain('Packs/personas/broken.persona.json')
  expect(frame).toContain('persona: Failed to decode JSON')
  expect(frame).toContain('[ Refresh ]')
})

test('libraryRowStripsControlChars', async () => {
  // The id reaches the route as JSON's escape; parsed, it carries a real ESC.
  const list = LIST_JSON.replaceAll(SESSION, ESC_ID_JSON).replace('"Read-Only Auditor"', '"Read\\u001b[31m-Only Auditor"')
  const r = await open({ list, view: { kind: 'library' } })
  const frame = await r.frame((f) => f.includes('a[2Jb'))
  expect(frame).not.toContain('\u001b')
  expect(frame).toContain('Read[31m-Only Auditor')
  expect(frame).toContain('unsupported id')
  // Back, Contract, Library, Refresh, the persona, the session, then the disabled Use.
  for (let i = 0; i < 7; i++) await r.command('personakit.route.next')()
  await r.command('personakit.route.press')()
  await r.click('[ Use ]')
  await settle()
  expect(r.record.appended).toEqual([])
  expect(r.record.navigations).toEqual([])
  expect(r.runs).toEqual([['personakit', 'list', 'all', '--json']])
})

test('sessionDetailLabelsPreview', async () => {
  const r = await open({ view: { kind: 'session', id: SESSION } })
  const frame = await r.frame((f) => f.includes('Audit the change and report findings'))
  expect(frame).toContain('preview, not in force')
  expect(frame).toContain('GOAL')
  expect(frame).toContain('STEPS')
  expect(frame).toContain('◆ stop')
  expect(frame).toContain('Read-Only Auditor')
  expect(r.runs).toEqual([
    ['personakit', 'list', 'all', '--json'],
    ['personakit', 'contract', `--session=${SESSION}`],
    ['personakit', 'export', `--session=${SESSION}`],
  ])
})

test('useNavigatesBackAndPrefills', async () => {
  const r = await open({ view: { kind: 'library' } })
  await r.frame((f) => f.includes('[ Use ]'))
  await r.click('[ Use ]')
  await settle()
  expect(r.record.appended).toEqual([usePrompt({ sessionId: SESSION })])
  expect(r.record.navigations).toEqual([{ name: 'session', params: { sessionID: MAIN } }])
  // OpenCode drops appended text while no prompt is on screen, so the session comes back first.
  expect(r.record.events).toEqual(['navigate:session', 'append'])
})

test('useByKeyboardPrefillsTheSelectedSession', async () => {
  const r = await open({ view: { kind: 'library' } })
  await r.frame((f) => f.includes('[ Use ]'))
  // Back, Contract, Library, Refresh, the persona, the session, then Use.
  for (let i = 0; i < 7; i++) await r.command('personakit.route.next')()
  await r.command('personakit.route.press')()
  await settle()
  expect(r.record.appended).toEqual([usePrompt({ sessionId: SESSION })])
})

test('keyboardOrderIsScreenOrderOnADetailView', async () => {
  const r = await open({ view: { kind: 'session', id: SESSION } })
  await r.frame((f) => f.includes('Audit the change'))
  // Back, Contract, Library, then Use: rows (Persona, Directive) build their value once, so no unseen control intervenes.
  for (let i = 0; i < 4; i++) await r.command('personakit.route.next')()
  await r.command('personakit.route.press')()
  await settle()
  expect(r.record.appended).toEqual([usePrompt({ sessionId: SESSION })])
})

test('backPopsTheViewStackThenReturnsToTheSession', async () => {
  const r = await open({ view: { kind: 'library' } })
  await r.click('Read-only audit pass')
  await r.frame((f) => f.includes('preview, not in force'))
  await r.click('Read-Only Auditor')
  await r.frame((f) => f.includes('TALK TO THEM VIA'))
  await r.command('personakit.route.back')()
  await r.frame((f) => f.includes('preview, not in force'))
  await r.command('personakit.route.back')()
  await r.frame((f) => f.includes('PEOPLE'))
  expect(r.record.navigations).toEqual([])
  await r.command('personakit.route.back')()
  expect(r.record.navigations).toEqual([{ name: 'session', params: { sessionID: MAIN } }])
})

test('backWithoutASessionGoesHome', async () => {
  const r = await open({ view: { kind: 'library' }, sessionID: null })
  await r.frame((f) => f.includes('PEOPLE'))
  await r.command('personakit.route.back')()
  expect(r.record.navigations).toEqual([{ name: 'home', params: undefined }])
})

test('opensOnTheLibraryWithoutAContract', async () => {
  const r = await open()
  const frame = await r.frame((f) => f.includes('PEOPLE'))
  expect(frame).toContain('Library')
})

test('contractViewShowsTheContractInForce', async () => {
  const [state] = createSignal<SessionState>({
    ...initial,
    main: { ids: { sessionId: SESSION }, source: 'cli', turn: 1, details: { personaName: 'Read-Only Auditor', personaId: 'read-only-auditor', steps: [], deniedActionClasses: [] } },
    turn: 2,
  })
  const r = await open({ session: state })
  const frame = await r.frame((f) => f.includes('Kits, skills, and scope: read by the pane'))
  expect(frame).toContain(SESSION)
  expect(frame).toContain('Resolved turn 1 · 1 turn ago · CLI')
  expect(frame).toContain('● Advisory')
  expect(frame).toContain('[ Re-ground ]')
  await r.click('[ Re-ground ]')
  await settle()
  expect(r.record.appended).toEqual([usePrompt({ sessionId: SESSION })])
  expect(r.record.events).toEqual(['navigate:session', 'append'])
})

test('contractViewSaysOpenCodesEnforcementStates', async () => {
  const enforced = (extra: object): (() => SessionState) => () => ({
    ...initial,
    enforcement: { kind: 'enforced', manifestPath: '/p/.opencode/personakit-enforcement.json', ids: { sessionId: SESSION }, deniedActionClasses: ['file-mutation'], matcherTools: ['edit'], ...extra },
  })
  const missing = await open({ view: { kind: 'contract' }, session: enforced({ pluginMissing: true }) })
  expect(await missing.frame((f) => f.includes('ENFORCEMENT'))).toContain('⚠ manifest present · plugin not loaded')
  const changed = await open({ view: { kind: 'contract' }, session: enforced({}), manifestChanged: true })
  const frame = await changed.frame((f) => f.includes('ENFORCEMENT'))
  expect(frame).toContain('⚠ manifest changed · restart OpenCode')
  expect(frame).not.toContain('Enforced')
  const ok = await open({ view: { kind: 'contract' }, session: enforced({}) })
  const okFrame = await ok.frame((f) => f.includes('ENFORCEMENT'))
  expect(okFrame).toContain('● Enforced')
  expect(okFrame).toContain('deny file-mutation')
})

test('chipTextPutsOpenCodesHintAndManifestWarningInTheSharedLine', () => {
  expect(chipText(initial, false)).toBe('◇ no contract · /pk')
  expect(chipText(initial, true)).toBe(`◇ no contract · ${MANIFEST_CHANGED}`)
  // Fitted against OpenCode's shorter hint: this tool name would be cut beside the mod's.
  const tool = 'T'.repeat(80)
  expect(chipText({ ...initial, drift: [{ tool, kind: 'blocked', turn: 1 }] }, false)).toBe(`◇ no contract · /pk · ⚠ drift: ${tool}`)
  const long = 'N'.repeat(300)
  const crowded: SessionState = {
    ...initial,
    main: { ids: { sessionId: long }, source: 'cli', turn: 1 },
    enforcement: { kind: 'enforced', manifestPath: '/m.json', ids: { sessionId: long }, deniedActionClasses: [], matcherTools: ['.*'] },
    drift: [{ tool: long, kind: 'blocked', turn: 1 }],
    compactions: 1,
  }
  const text = chipText(crowded, true)
  expect(text.length).toBeLessThanOrEqual(120)
  expect(text.startsWith(`◆ ${'N'.repeat(31)}… · ${MANIFEST_CHANGED} · `)).toBe(true)
  expect(text).not.toContain('enforced')
})

test('refreshDropsAStaleLibraryLoad', async () => {
  const fake = await open({ view: { kind: 'library' } })
  await fake.frame((f) => f.includes('PEOPLE'))
  fake.hold()
  await fake.click('[ Refresh ]')
  await fake.click('[ Refresh ]')
  expect(fake.pending.length).toBe(2)
  fake.release(1)
  await fake.frame((f) => f.includes('PEOPLE'))
  // The first Refresh answers last, with errors: it is dropped.
  fake.release(0, ran(LIST_ERRORS_JSON, 1))
  await settle()
  const frame = await fake.frame((f) => f.includes('PEOPLE'))
  expect(frame).not.toContain("didn't load")
})

test('refreshDropsAPreviewInFlight', async () => {
  const r = await open({ view: { kind: 'library' } })
  await r.frame((f) => f.includes('PEOPLE'))
  r.hold()
  await r.click('Read-only audit pass')
  await r.frame((f) => f.includes('Loading contract…'))
  expect(r.pending.map((p) => p.argv[1])).toEqual(['contract'])
  await r.command('personakit.route.back')()
  await r.click('[ Refresh ]')
  r.release(1)
  r.release(0)
  await until(() => r.pending.length === 3, 'the export')
  r.release(2)
  await settle()
  await r.click('Read-only audit pass')
  // The preview from before Refresh never landed: the session view reads it again.
  await r.frame((f) => f.includes('Loading contract…'))
  expect(r.pending.map((p) => p.argv[1])).toEqual(['contract', 'list', 'export', 'contract'])
})

test('nothingUpdatesAfterDispose', async () => {
  const r = await open({ view: { kind: 'library' } })
  await r.frame((f) => f.includes('PEOPLE'))
  r.hold()
  await r.click('[ Refresh ]')
  await r.frame((f) => f.includes('Loading the library…'))
  r.dispose()
  expect(r.record.unregistered).toBe(1)
  r.release(0, ran(LIST_ERRORS_JSON, 1))
  await settle()
  const frame = await r.frame((f) => f.includes('Loading the library…'))
  expect(frame).not.toContain("didn't load")
})

test('leavingTheRouteRemovesItsKeys', async () => {
  const r = await open({ view: { kind: 'library' } })
  await r.frame((f) => f.includes('PEOPLE'))
  expect(r.record.layers.length).toBe(1)
  expect(r.record.layers[0]!.bindings!.map((b) => b.key).sort()).toEqual(['down,tab', 'escape', 'return', 'up,shift+tab'])
  r.setup.renderer.destroy()
  renderers.pop()
  expect(r.record.removedLayers).toBe(1)
})

test('escapeClearsTheFilterBeforeLeaving', async () => {
  const r = await open({ view: { kind: 'library' } })
  await r.frame((f) => f.includes('PEOPLE'))
  await r.setup.mockInput.typeText('audit')
  await r.frame((f) => f.includes('PEOPLE · 1'))
  await r.command('personakit.route.back')()
  const frame = await r.frame((f) => f.includes('Who you can work with'))
  expect(frame).toContain('id, name, project or global')
  expect(r.record.navigations).toEqual([])
  await r.command('personakit.route.back')()
  expect(r.record.navigations).toEqual([{ name: 'session', params: { sessionID: MAIN } }])
})

test('filterMatchesAreAccentedAndBold', async () => {
  const r = await open({ view: { kind: 'library' } })
  await r.frame((f) => f.includes('PEOPLE'))
  await r.setup.mockInput.typeText('audit')
  await r.frame((f) => f.includes('PEOPLE · 1'))
  const spans = r.setup.captureSpans().lines.flatMap((l) => l.spans)
  const match = spans.find((span) => span.text === 'audit' || span.text === 'Audit')
  expect(match).toBeDefined()
  expect(match!.attributes & TextAttributes.BOLD).toBe(TextAttributes.BOLD)
  expect(match!.fg.toInts()).toEqual(RGBA.fromHex('#ff00ff').toInts())
})

test('sessionDetailShowsAnEmptyGoal', async () => {
  const exportMd = EXPORT_MD.replace('Goal: Audit the change and report findings without editing it.', 'Goal: ')
  const r = await open({ view: { kind: 'session', id: SESSION }, exportMd })
  const frame = await r.frame((f) => f.includes('STEPS'))
  expect(frame).toContain('GOAL')
})

test('pkOnTheRouteKeepsItsSession', async () => {
  const fake = fakeApi()
  const layers: Layer[] = []
  const api = {
    ...fake.api,
    route: { ...fake.api.route, current: { name: 'personakit', params: { sessionID: MAIN } } },
    keymap: { registerLayer: (layer: Layer) => (layers.push(layer), () => {}) },
    ui: { ...fake.api.ui, dialog: { clear: () => {} } },
    slots: { register: () => 'slot' },
    event: { on: () => () => {} },
    lifecycle: { signal: new AbortController().signal, onDispose: () => {} },
    state: {
      config: { mcp: {}, plugin: [] },
      path: { directory: process.cwd(), worktree: process.cwd(), state: '', config: '' },
      session: { messages: () => [], get: () => undefined },
      part: () => [],
      mcp: () => [],
    },
  }
  await plugin.tui(api as unknown as TuiPluginApi, {}, {} as never, () => 0)
  const pk = layers.flatMap((layer) => layer.commands ?? []).find((c) => (c as { slashName?: string }).slashName === 'pk')!
  await pk.run({})
  expect(fake.record.navigations).toEqual([{ name: 'personakit', params: { sessionID: MAIN } }])
})

test('tuiRegistersTheRouteAndDisposesIt', async () => {
  const fake = fakeApi()
  const disposers: (() => void)[] = []
  const api = {
    ...fake.api,
    keymap: { registerLayer: () => () => {} },
    slots: { register: () => 'slot' },
    event: { on: () => () => {} },
    lifecycle: { signal: new AbortController().signal, onDispose: (fn: () => void) => void disposers.push(fn) },
    state: {
      config: { mcp: {}, plugin: [] },
      path: { directory: process.cwd(), worktree: process.cwd(), state: '', config: '' },
      session: { messages: () => [], get: () => undefined },
      part: () => [],
      mcp: () => [],
    },
  }
  await plugin.tui(api as unknown as TuiPluginApi, {}, {} as never, () => 0)
  expect(fake.record.routes.map((r) => r.name)).toEqual(['personakit'])
  for (const dispose of disposers) dispose()
  expect(fake.record.unregistered).toBe(1)
})
