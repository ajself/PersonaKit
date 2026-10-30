import { afterEach, expect, test } from 'bun:test'
import type { TuiDialogSelectOption, TuiDialogSelectProps, TuiPluginApi, TuiToast } from '@opencode-ai/plugin/tui'
import { testRender } from '@opentui/solid'
import { createStore } from 'solid-js/store'
import { chmodSync, mkdirSync, mkdtempSync, realpathSync, symlinkSync, unlinkSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { CONTRACT_JSON, EXPORT_MD, LIST_MERGED_JSON } from '../../ClaudeCode/hooks/fixtures/golden.ts'
import { usePrompt } from '../../ClaudeCode/hooks/lib/prompts.ts'
import plugin from '../src/tui.tsx'

const MAIN = 'ses_main'
const SESSION = 'read-only-auditor_audit-pass'

type Handler = (event: { type: string; properties: Record<string, unknown> }) => void
type Command = { name: string; title?: string; namespace?: string; slashName?: string; run: (ctx: unknown) => unknown }
type SlotFn = (ctx: unknown, props: { session_id: string }) => unknown

const tool = (id: string, messageID: string, command: string, output: string, sessionID = MAIN) => ({
  id,
  sessionID,
  messageID,
  type: 'tool',
  callID: `call_${id}`,
  tool: 'bash',
  state: { status: 'completed', input: { command }, output, title: '', metadata: {}, time: { start: 1, end: 2 } },
})

/** A transcript in which main resolved the golden contract over the CLI. */
const resolved = () => ({
  messages: { [MAIN]: [{ id: 'u1', role: 'user', sessionID: MAIN, time: { created: 1 } }, { id: 'a1', role: 'assistant', sessionID: MAIN, time: { created: 2 } }] },
  parts: { a1: [tool('p1', 'a1', `personakit contract --session=${SESSION}`, CONTRACT_JSON)] },
})

const compactionPart = (messageID: string) => ({ id: `c_${messageID}`, sessionID: MAIN, messageID, type: 'compaction', auto: false })

const tempDir = (prefix: string) => realpathSync(mkdtempSync(join(tmpdir(), prefix)))

/** A fake `TuiPluginApi` that records what the plugin registers, shows and appends. */
function fakeApi(opts: {
  directory?: string
  messages?: Record<string, unknown[]>
  parts?: Record<string, unknown[]>
  plugins?: string[]
  parents?: Record<string, string>
} = {}) {
  const directory = opts.directory ?? tempDir('pk-tui-')
  const handlers = new Map<string, Set<Handler>>()
  const record = {
    layers: [] as { commands?: Command[] }[],
    slots: [] as { slots: Record<string, SlotFn> }[],
    toasts: [] as TuiToast[],
    dialogs: [] as (() => unknown)[],
    selects: [] as TuiDialogSelectProps<string>[],
    appended: [] as string[],
    navigations: [] as { name: string; params?: Record<string, unknown> }[],
    disposers: [] as (() => void | Promise<void>)[],
    unsubscribed: 0,
  }
  const api = {
    keymap: {
      registerLayer: (layer: { commands?: Command[] }) => {
        record.layers.push(layer)
        return () => {}
      },
    },
    slots: {
      register: (slot: { slots: Record<string, SlotFn> }) => {
        record.slots.push(slot)
        return `slot-${record.slots.length}`
      },
    },
    route: {
      current: { name: 'session', params: { sessionID: MAIN } },
      navigate: (name: string, params?: Record<string, unknown>) => void record.navigations.push({ name, params }),
      register: () => () => {},
    },
    event: {
      on: (type: string, handler: Handler) => {
        const set = handlers.get(type) ?? new Set<Handler>()
        set.add(handler)
        handlers.set(type, set)
        return () => {
          set.delete(handler)
          record.unsubscribed += 1
        }
      },
    },
    lifecycle: {
      signal: new AbortController().signal,
      onDispose: (fn: () => void) => {
        record.disposers.push(fn)
        return () => {}
      },
    },
    ui: {
      toast: (toast: TuiToast) => void record.toasts.push(toast),
      dialog: { replace: (render: () => unknown) => void record.dialogs.push(render), clear: () => {} },
      DialogSelect: (props: TuiDialogSelectProps<string>) => {
        record.selects.push(props)
        return null
      },
    },
    state: {
      config: { mcp: {}, plugin: opts.plugins ?? [] },
      path: { directory, worktree: directory, state: '', config: '' },
      session: {
        messages: (id: string) => opts.messages?.[id] ?? [],
        get: (id: string) => (opts.parents?.[id] === undefined ? undefined : { id, parentID: opts.parents[id] }),
      },
      part: (id: string) => opts.parts?.[id] ?? [],
      mcp: () => [],
    },
    client: {
      tui: {
        appendPrompt: async (input: { text?: string }) => {
          record.appended.push(input.text ?? '')
          return { data: true, error: undefined }
        },
      },
    },
    theme: { current: { warning: '#ffaa00', textMuted: '#888888', text: '#ffffff', success: '#00ff00', error: '#ff0000', primary: '#4488ff' } },
  }
  const emit = (type: string, properties: Record<string, unknown>) => {
    for (const handler of handlers.get(type) ?? []) handler({ type, properties })
  }
  return { api: api as unknown as TuiPluginApi, record, emit, directory }
}

/** Starts the plugin; `uptime` is the process age it sees, OpenCode's startup by default. */
const start = async (fake: ReturnType<typeof fakeApi>, options: Record<string, unknown> = {}, uptime = () => 0) => {
  await plugin.tui(fake.api, options, {} as never, uptime)
  return fake
}

const commands = (fake: ReturnType<typeof fakeApi>) => fake.record.layers.flatMap((layer) => layer.commands ?? [])
const slot = (fake: ReturnType<typeof fakeApi>, name: string): SlotFn => {
  const found = fake.record.slots.find((s) => name in s.slots)
  if (!found) throw new Error(`no ${name} slot`)
  return found.slots[name]!
}

const renderers: { destroy(): void }[] = []
afterEach(() => {
  while (renderers.length) renderers.pop()!.destroy()
})

/** Renders a slot for the main session; `waitForFrame` gives the plugin's async rebuilds real time to land. */
async function render(fake: ReturnType<typeof fakeApi>, name: string, height = 2) {
  const setup = await testRender(() => slot(fake, name)({ theme: fake.api.theme }, { session_id: MAIN }) as never, { width: 160, height })
  renderers.push(setup.renderer)
  const waitForFrame = async (predicate: (frame: string) => boolean): Promise<string> => {
    let frame = ''
    for (let i = 0; i < 200; i++) {
      await setup.renderOnce()
      frame = setup.captureCharFrame()
      if (predicate(frame)) return frame
      await new Promise((resolve) => setTimeout(resolve, 5))
    }
    throw new Error(`timed out waiting for a frame; last:\n${frame}`)
  }
  return { ...setup, waitForFrame }
}

const until = async (check: () => boolean, what: string) => {
  for (let i = 0; i < 200; i++) {
    if (check()) return
    await new Promise((resolve) => setTimeout(resolve, 5))
  }
  throw new Error(`timed out waiting for ${what}`)
}

test('registersPkAndPkUse', async () => {
  const fake = await start(fakeApi())
  const palette = commands(fake).filter((command) => command.namespace === 'palette')
  expect(palette.map((command) => command.slashName).sort()).toEqual(['pk', 'pk-use'])
})

test('registersSlots', async () => {
  const fake = await start(fakeApi())
  const names = fake.record.slots.flatMap((s) => Object.keys(s.slots)).sort()
  expect(names).toEqual(['session_prompt_right', 'sidebar_content'])
})

test('pkNavigatesToTheRouteWithTheSession', async () => {
  const fake = await start(fakeApi())
  await commands(fake).find((command) => command.slashName === 'pk')!.run({})
  expect(fake.record.navigations).toEqual([{ name: 'personakit', params: { sessionID: MAIN } }])
})

test('chipShowsNoContract', async () => {
  const fake = await start(fakeApi())
  const chip = await render(fake, 'session_prompt_right')
  const frame = await chip.waitForFrame((f) => f.includes('no contract'))
  expect(frame).toContain('◇ no contract · /pk')
  expect(frame).not.toContain('<session>')
})

test('chipShowsTheResolvedContract', async () => {
  const fake = await start(fakeApi(resolved()))
  const chip = await render(fake, 'session_prompt_right')
  const frame = await chip.waitForFrame((f) => f.includes(SESSION))
  expect(frame).toContain(`◆ ${SESSION} · advisory · project-only`)
})

test('compactionToastsOnViewedSession', async () => {
  const transcript = resolved()
  const fake = await start(fakeApi(transcript))
  const sidebar = await render(fake, 'sidebar_content', 40)
  await sidebar.waitForFrame((f) => f.includes(`◆ ${SESSION}`))

  // OpenCode adds the compaction's user message, with its compaction part, before it reports the compaction.
  transcript.messages[MAIN]!.push({ id: 'u2', role: 'user', sessionID: MAIN, time: { created: 3 } })
  ;(transcript.parts as Record<string, unknown[]>).u2 = [compactionPart('u2')]
  fake.emit('session.compacted', { sessionID: MAIN })
  await until(() => fake.record.toasts.length === 1, 'the compaction toast')
  expect(fake.record.toasts[0]!.variant).toBe('warning')
  expect(fake.record.toasts[0]!.message).toContain('re-ground')
  const frame = await sidebar.waitForFrame((f) => f.includes('1 · re-ground?'))
  expect(frame).toContain('Compactions')

  fake.emit('session.compacted', { sessionID: 'ses_other' })
  fake.emit('message.updated', { sessionID: MAIN, info: { id: 'a1', role: 'assistant', sessionID: MAIN } })
  await new Promise((resolve) => setTimeout(resolve, 50))
  await sidebar.renderOnce()
  expect(fake.record.toasts.length).toBe(1)
  expect(sidebar.captureCharFrame()).toContain('1 · re-ground?')
  expect(sidebar.captureCharFrame()).not.toContain('2 · re-ground?')
})

test('autoCompactionCountsOnce', async () => {
  const transcript = resolved()
  const fake = await start(fakeApi(transcript))
  const sidebar = await render(fake, 'sidebar_content', 40)
  await sidebar.waitForFrame((f) => f.includes(`◆ ${SESSION}`))

  // An automatic compaction: its user message, then the synthetic "continue" user message, then the event.
  transcript.messages[MAIN]!.push(
    { id: 'u2', role: 'user', sessionID: MAIN, time: { created: 3 } },
    { id: 'u3', role: 'user', sessionID: MAIN, time: { created: 4 } },
  )
  ;(transcript.parts as Record<string, unknown[]>).u2 = [{ ...compactionPart('u2'), auto: true }]
  fake.emit('session.compacted', { sessionID: MAIN })
  await until(() => fake.record.toasts.length === 1, 'the compaction toast')
  const frame = await sidebar.waitForFrame((f) => f.includes('· re-ground?'))
  expect(frame).toContain('1 · re-ground?')
})

test('compactionInTheHistoryIsCountedAfterARestart', async () => {
  const transcript = resolved()
  transcript.messages[MAIN]!.push({ id: 'u2', role: 'user', sessionID: MAIN, time: { created: 3 } })
  const parts = { ...transcript.parts, u2: [compactionPart('u2')] }
  const fake = await start(fakeApi({ messages: transcript.messages, parts }))
  const chip = await render(fake, 'session_prompt_right')
  expect(await chip.waitForFrame((f) => f.includes(`◆ ${SESSION}`))).toContain(`◆ ${SESSION} · ⚠ re-ground? · advisory`)
  expect(fake.record.toasts).toEqual([])
})

test('aResolutionAfterTheCompactionAnswersIt', async () => {
  const transcript = resolved()
  transcript.messages[MAIN]!.push(
    { id: 'u2', role: 'user', sessionID: MAIN, time: { created: 3 } },
    { id: 'u3', role: 'user', sessionID: MAIN, time: { created: 4 } },
    { id: 'a3', role: 'assistant', sessionID: MAIN, time: { created: 5 } },
  )
  const parts = {
    ...transcript.parts,
    u2: [compactionPart('u2')],
    a3: [tool('p3', 'a3', `personakit contract --session=${SESSION}`, CONTRACT_JSON)],
  }
  const fake = await start(fakeApi({ messages: transcript.messages, parts }))
  const chip = await render(fake, 'session_prompt_right')
  expect(await chip.waitForFrame((f) => f.includes(`◆ ${SESSION}`))).not.toContain('re-ground?')
})

test('compactionWithoutAContractCountsButDoesNotToast', async () => {
  const fake = await start(fakeApi())
  const sidebar = await render(fake, 'sidebar_content', 40)
  await sidebar.waitForFrame((f) => f.includes('no contract'))
  fake.emit('session.compacted', { sessionID: MAIN })
  await new Promise((resolve) => setTimeout(resolve, 50))
  expect(fake.record.toasts).toEqual([])
})

test('regroundPrefillsTheContractInForce', async () => {
  const fake = await start(fakeApi(resolved()))
  const sidebar = await render(fake, 'sidebar_content', 40)
  const frame = await sidebar.waitForFrame((f) => f.includes('[ Re-ground ]'))
  const row = frame.split('\n').findIndex((line) => line.includes('[ Re-ground ]'))
  await sidebar.mockMouse.click(frame.split('\n')[row]!.indexOf('[ Re-ground ]') + 2, row)
  await until(() => fake.record.appended.length === 1, 'the re-ground pre-fill')
  expect(fake.record.appended).toEqual([usePrompt({ sessionId: SESSION })])
})

test('noRegroundWithoutAContract', async () => {
  const fake = await start(fakeApi())
  const sidebar = await render(fake, 'sidebar_content', 40)
  expect(await sidebar.waitForFrame((f) => f.includes('no contract'))).not.toContain('Re-ground')
})

test('subagentSessionDriftIsTheSubagents', async () => {
  const CHILD = 'ses_child'
  const transcript = resolved()
  transcript.parts.a1!.push(tool('p2', 'a1', `personakit export --session=${SESSION}`, EXPORT_MD))
  const messages: Record<string, unknown[]> = { ...transcript.messages, [CHILD]: [] }
  const parts: Record<string, unknown[]> = { ...transcript.parts }
  const fake = await start(fakeApi({ messages, parts, parents: { [CHILD]: MAIN } }))
  const sidebar = await render(fake, 'sidebar_content', 40)
  await sidebar.waitForFrame((f) => f.includes('Read-Only Auditor'))

  // The subagent's own user message is its prompt, not a turn of main's.
  messages[CHILD]!.push({ id: 'cu1', role: 'user', sessionID: CHILD, time: { created: 3 } })
  messages[CHILD]!.push({ id: 'ca1', role: 'assistant', sessionID: CHILD, time: { created: 4 } })
  const child = tool('c1', 'ca1', 'ls', 'README.md\n', CHILD)
  parts.ca1 = [child]
  fake.emit('message.part.updated', { sessionID: CHILD, part: child, time: 4 })
  const frame = await sidebar.waitForFrame((f) => f.includes('Drift (1)'))
  expect(frame).toContain('bash advisory · command-execution · subagent · turn 1')
})

/** A `personakit` stand-in that prints `stdout` for `list all --json`. */
function fakeBinary(stdout: string): string {
  const dir = tempDir('pk-bin-')
  const file = join(dir, 'personakit')
  writeFileSync(file, `#!/bin/sh\ncat <<'PK_EOF'\n${stdout}\nPK_EOF\n`)
  chmodSync(file, 0o755)
  return file
}

test('pkUseSkipsInvalidIds', async () => {
  const library = LIST_MERGED_JSON.replaceAll('senior-swiftui-engineer_apply-style', '.hidden')
  const fake = await start(fakeApi(), { personakitPath: fakeBinary(library) })
  await commands(fake).find((command) => command.slashName === 'pk-use')!.run({})
  expect(fake.record.dialogs.length).toBe(1)
  fake.record.dialogs[0]!()
  const props = fake.record.selects[0]!
  const byId = new Map(props.options.map((option) => [option.value, option]))
  expect(byId.get('.hidden')?.disabled).toBe(true)
  // OpenCode never draws a disabled row, so it carries no extra copy.
  expect(byId.get('.hidden')?.description).toBe('.hidden')
  expect(byId.get('architectural-editor-review')?.disabled).toBe(false)
  expect(byId.get('architectural-editor-review')?.title).toBe('Review architecture invariants before implementation')
  expect(byId.get('architectural-editor-review')?.description).toBe('architectural-editor-review')

  props.onSelect?.(byId.get('.hidden') as TuiDialogSelectOption<string>)
  await new Promise((resolve) => setTimeout(resolve, 10))
  expect(fake.record.appended).toEqual([])

  // OpenCode's own filter reads only title and category; the plugin filters itself so an id matches too.
  expect(props.skipFilter).toBe(true)
  props.onFilter?.('architectural-editor-rev')
  expect(props.options.map((option) => option.value)).toEqual(['architectural-editor-review'])
  props.onFilter?.('swift style')
  expect(props.options.map((option) => option.value)).toEqual(['.hidden'])
  props.onFilter?.('')
  expect(props.options.length).toBe(2)

  props.onSelect?.(byId.get('architectural-editor-review') as TuiDialogSelectOption<string>)
  await until(() => fake.record.appended.length === 1, 'the pre-fill')
  expect(fake.record.appended).toEqual([usePrompt({ sessionId: 'architectural-editor-review' })])
})

test('pkUseAcceptsWorkspaceIds', async () => {
  const library = LIST_MERGED_JSON.replaceAll('senior-swiftui-engineer_apply-style', '_wip')
  const fake = await start(fakeApi(), { personakitPath: fakeBinary(library) })
  await commands(fake).find((command) => command.slashName === 'pk-use')!.run({})
  fake.record.dialogs[0]!()
  const props = fake.record.selects[0]!
  const option = props.options.find((o) => o.value === '_wip')!
  expect(option.disabled).toBe(false)
  expect(option.description).toBe('_wip')
  props.onSelect?.(option as TuiDialogSelectOption<string>)
  await until(() => fake.record.appended.length === 1, 'the pre-fill')
  expect(fake.record.appended[0]).toContain('personakit contract --session=_wip')
})

test('pkUseStripsControlCharactersFromLibraryText', async () => {
  const library = LIST_MERGED_JSON.replace('"Review architecture invariants before implementation"', '"Review\\u001b[2J\\u202e invariants"')
  const fake = await start(fakeApi(), { personakitPath: fakeBinary(library) })
  await commands(fake).find((command) => command.slashName === 'pk-use')!.run({})
  fake.record.dialogs[0]!()
  const titles = fake.record.selects[0]!.options.map((option) => option.title)
  expect(titles).toContain('Review[2J invariants')
})

test('pkUseToastsWhenTheLibraryCannotLoad', async () => {
  const fake = await start(fakeApi(), { personakitPath: join(tempDir('pk-missing-'), 'personakit') })
  await commands(fake).find((command) => command.slashName === 'pk-use')!.run({})
  expect(fake.record.dialogs).toEqual([])
  expect(fake.record.toasts.length).toBe(1)
  expect(fake.record.toasts[0]!.message).toContain('personakitPath')
})

/** Writes the one enforcement manifest in `dir`. */
const writeManifest = (dir: string, text: string) => {
  mkdirSync(join(dir, '.opencode', 'personakit'), { recursive: true })
  writeFileSync(join(dir, '.opencode', 'personakit', `${SESSION}.checks.json`), text)
}

test('manifestChangedAfterStartIsAWarningNeverEnforced', async () => {
  const directory = tempDir('pk-manifest-')
  writeManifest(directory, JSON.stringify({ sessionId: SESSION, checks: [] }))
  const fake = await start(fakeApi({ ...resolved(), directory, plugins: ['opencode-personakit'] }))
  const chip = await render(fake, 'session_prompt_right')
  expect(await chip.waitForFrame((f) => f.includes(`◆ ${SESSION}`))).toContain(' · enforced · ')

  writeManifest(directory, JSON.stringify({ sessionId: SESSION, checks: [], changed: true }))
  fake.emit('message.updated', { sessionID: MAIN, info: { id: 'a1', role: 'assistant', sessionID: MAIN } })
  const frame = await chip.waitForFrame((f) => f.includes('manifest changed'))
  expect(frame).toContain(`◆ ${SESSION} · ⚠ manifest changed · restart OpenCode · project-only`)
  expect(frame).not.toContain('enforced')
})

test('manifestAppearingAfterStartIsAWarning', async () => {
  const directory = tempDir('pk-manifest-')
  const fake = await start(fakeApi({ directory, plugins: ['opencode-personakit'] }))
  const chip = await render(fake, 'session_prompt_right')
  await chip.waitForFrame((f) => f.includes('/pk'))
  writeManifest(directory, JSON.stringify({ sessionId: SESSION, checks: [] }))
  fake.emit('message.updated', { sessionID: MAIN, info: { id: 'u1', role: 'user', sessionID: MAIN } })
  expect(await chip.waitForFrame((f) => f.includes('manifest changed'))).toContain('◇ no contract · ⚠ manifest changed · restart OpenCode')
})

test('reactivatingThePluginKeepsTheStartupSnapshot', async () => {
  // OpenCode starts with no manifest; the server enforces nothing for the rest of the process.
  const directory = tempDir('pk-toggle-')
  await start(fakeApi({ ...resolved(), directory, plugins: ['opencode-personakit'] }))
  writeManifest(directory, JSON.stringify({ sessionId: SESSION, checks: [] }))
  // The person turns the TUI plugin off and on: `tui()` runs again in the same process.
  const again = await start(fakeApi({ ...resolved(), directory, plugins: ['opencode-personakit'] }))
  const chip = await render(again, 'session_prompt_right')
  const frame = await chip.waitForFrame((f) => f.includes(`◆ ${SESSION}`) && f.includes('manifest changed'))
  expect(frame).toContain(`◆ ${SESSION} · ⚠ manifest changed · restart OpenCode`)
  expect(frame).not.toContain('enforced')
})

test('aReactivationNeverClaimsEnforcedUntilAnInstanceDispose', async () => {
  const directory = tempDir('pk-reactivate-')
  const M1 = JSON.stringify({ sessionId: SESSION, checks: [] })
  writeManifest(directory, M1)
  const first = await start(fakeApi({ ...resolved(), directory, plugins: ['opencode-personakit'] }))
  const firstChip = await render(first, 'session_prompt_right')
  expect(await firstChip.waitForFrame((f) => f.includes(`◆ ${SESSION}`))).toContain(' · enforced · ')

  // Toggled off; meanwhile `/connect` disposes the instance and the server finds no manifest, unseen by the TUI. The
  // same manifest is installed again, byte for byte, and the plugin is toggled back on.
  for (const dispose of first.record.disposers) await dispose()
  unlinkSync(join(directory, '.opencode', 'personakit', `${SESSION}.checks.json`))
  writeManifest(directory, M1)
  const again = await start(fakeApi({ ...resolved(), directory, plugins: ['opencode-personakit'] }))
  const chip = await render(again, 'session_prompt_right')
  const frame = await chip.waitForFrame((f) => f.includes(`◆ ${SESSION}`) && f.includes('manifest changed'))
  expect(frame).toContain(`◆ ${SESSION} · ⚠ manifest changed · restart OpenCode`)
  expect(frame).not.toContain('enforced')

  // The next instance dispose retakes the snapshot the server retakes, and the status judges normally again.
  again.emit('server.instance.disposed', { directory })
  expect(await chip.waitForFrame((f) => f.includes(' · enforced · '))).not.toContain('manifest changed')
})

test('aFirstActivationAfterStartupNeverClaimsEnforcedUntilAnInstanceDispose', async () => {
  // OpenCode starts with the plugin disabled (a choice it remembers) and no manifest: the server enforces nothing.
  const directory = tempDir('pk-late-')
  writeManifest(directory, JSON.stringify({ sessionId: SESSION, checks: [] }))
  // A manifest appeared mid-session, then the person enables the plugin: the first `tui()` in this process, late.
  const fake = await start(fakeApi({ ...resolved(), directory, plugins: ['opencode-personakit'] }), {}, () => 15)
  const chip = await render(fake, 'session_prompt_right')
  const frame = await chip.waitForFrame((f) => f.includes(`◆ ${SESSION}`) && f.includes('manifest changed'))
  expect(frame).toContain(`◆ ${SESSION} · ⚠ manifest changed · restart OpenCode`)
  expect(frame).not.toContain('enforced')

  // The next instance dispose starts the server plugin again on this manifest, and the status judges normally.
  fake.emit('server.instance.disposed', { directory })
  expect(await chip.waitForFrame((f) => f.includes(' · enforced · '))).not.toContain('manifest changed')
})

test('aReactivationWithoutAManifestIsAdvisory', async () => {
  const directory = tempDir('pk-reactivate-')
  const first = await start(fakeApi({ ...resolved(), directory, plugins: ['opencode-personakit'] }))
  for (const dispose of first.record.disposers) await dispose()
  const again = await start(fakeApi({ ...resolved(), directory, plugins: ['opencode-personakit'] }))
  const chip = await render(again, 'session_prompt_right')
  const frame = await chip.waitForFrame((f) => f.includes(`◆ ${SESSION}`))
  expect(frame).toContain(`◆ ${SESSION} · advisory`)
  expect(frame).not.toContain('manifest changed')
})

test('aManifestThatIsNotARegularFileIsUnreadableAndNeverBlocks', async () => {
  for (const make of [
    (file: string) => Bun.spawnSync(['mkfifo', file]),
    (file: string) => symlinkSync('/dev/zero', file),
    (file: string) => writeFileSync(file, Buffer.alloc(4 * 1024 * 1024 + 1, 0x20)),
  ]) {
    const directory = tempDir('pk-special-')
    mkdirSync(join(directory, '.opencode', 'personakit'), { recursive: true })
    make(join(directory, '.opencode', 'personakit', `${SESSION}.checks.json`))
    const fake = await start(fakeApi({ ...resolved(), directory, plugins: ['opencode-personakit'] }))
    const chip = await render(fake, 'session_prompt_right')
    const frame = await chip.waitForFrame((f) => f.includes(`◆ ${SESSION}`))
    expect(frame).toContain('⚠ enforcement manifest unreadable')
    expect(frame).not.toContain('manifest changed')
  }
})

test('nothingIsShownAfterDispose', async () => {
  const dir = tempDir('pk-slow-')
  const file = join(dir, 'personakit')
  writeFileSync(file, `#!/bin/sh\nsleep 0.3\ncat <<'PK_EOF'\n${LIST_MERGED_JSON}\nPK_EOF\n`)
  chmodSync(file, 0o755)
  const fake = await start(fakeApi(), { personakitPath: file })
  const running = commands(fake).find((command) => command.slashName === 'pk-use')!.run({})
  for (const dispose of fake.record.disposers) await dispose()
  await running
  expect(fake.record.dialogs).toEqual([])
  expect(fake.record.toasts).toEqual([])
})

test('anInstanceDisposeRetakesTheSnapshotTheServerRetakes', async () => {
  const directory = tempDir('pk-instance-')
  const M1 = JSON.stringify({ sessionId: SESSION, checks: [] })
  writeManifest(directory, M1)
  const fake = await start(fakeApi({ ...resolved(), directory, plugins: ['opencode-personakit'] }))
  const chip = await render(fake, 'session_prompt_right')
  const poke = () => fake.emit('message.updated', { sessionID: MAIN, info: { id: 'a1', role: 'assistant', sessionID: MAIN } })
  expect(await chip.waitForFrame((f) => f.includes(`◆ ${SESSION}`))).toContain(' · enforced · ')

  unlinkSync(join(directory, '.opencode', 'personakit', `${SESSION}.checks.json`))
  poke()
  await chip.waitForFrame((f) => f.includes('manifest changed'))

  // `/connect`, an OAuth callback or an org switch disposes the instance: the server plugin starts again and finds no
  // manifest, so it enforces nothing from here on.
  fake.emit('server.instance.disposed', { directory })
  await chip.waitForFrame((f) => f.includes(`◆ ${SESSION} · advisory`))

  writeManifest(directory, M1)
  poke()
  const frame = await chip.waitForFrame((f) => f.includes('manifest changed'))
  expect(frame).toContain(`◆ ${SESSION} · ⚠ manifest changed · restart OpenCode`)
  expect(frame).not.toContain('enforced')
})

test('anInstanceDisposeReReadsThePluginList', async () => {
  const directory = tempDir('pk-instance-')
  writeManifest(directory, JSON.stringify({ sessionId: SESSION, checks: [] }))
  const fake = await start(fakeApi({ ...resolved(), directory, plugins: ['opencode-personakit'] }))
  const chip = await render(fake, 'session_prompt_right')
  expect(await chip.waitForFrame((f) => f.includes(`◆ ${SESSION}`))).toContain(' · enforced · ')

  // The plugin is taken out of opencode.json, then the instance reloads with that config.
  ;(fake.api.state.config as { plugin: string[] }).plugin = []
  fake.emit('server.instance.disposed', { directory: join(tempDir('pk-elsewhere-'), 'other') })
  await new Promise((resolve) => setTimeout(resolve, 30))
  fake.emit('server.instance.disposed', { directory })
  const frame = await chip.waitForFrame((f) => f.includes('plugin not loaded'))
  expect(frame).toContain('⚠ manifest present · plugin not loaded')
  expect(frame).not.toContain('enforced')
})

test('aReloadedPluginListRebuildsWithoutAnotherEvent', async () => {
  const directory = tempDir('pk-instance-')
  writeManifest(directory, JSON.stringify({ sessionId: SESSION, checks: [] }))
  const fake = fakeApi({ ...resolved(), directory, plugins: ['opencode-personakit'] })
  // OpenCode's config is a reactive store; it is replaced after the instance reloads, after the dispose event.
  const [config, setConfig] = createStore({ mcp: {}, plugin: ['opencode-personakit'] })
  ;(fake.api.state as { config: unknown }).config = config
  await start(fake)
  const chip = await render(fake, 'session_prompt_right')
  expect(await chip.waitForFrame((f) => f.includes(`◆ ${SESSION}`))).toContain(' · enforced · ')
  fake.emit('server.instance.disposed', { directory })
  await new Promise((resolve) => setTimeout(resolve, 50))
  expect(await chip.waitForFrame((f) => f.includes(`◆ ${SESSION}`))).toContain(' · enforced · ')
  setConfig('plugin', [])
  expect(await chip.waitForFrame((f) => f.includes('plugin not loaded'))).not.toContain('enforced')
})

test('disposeUnsubscribesEveryHandler', async () => {
  const fake = await start(fakeApi())
  for (const dispose of fake.record.disposers) await dispose()
  expect(fake.record.unsubscribed).toBe(5)
})
