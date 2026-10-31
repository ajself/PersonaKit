import { expect, test } from 'claude-code/testing'
import type { ProcessRunResult } from 'claude-code'
import { read } from 'claude-code'

import { CONTRACT_JSON, EXPORT_MD, LIST_ERRORS_JSON, LIST_JSON, LIST_MERGED_JSON } from './fixtures/golden'
import { loadLibrary, loadPreview, mcpServerName, personakitBinary, previewKey } from './lib/runner'
import { openPreview, pane, refreshLibrary, session } from './register'

type Hook = Parameters<typeof refreshLibrary>[0]
type Answer = ProcessRunResult | string

const ran = (stdout: string, exitCode = 0, stderr = ''): ProcessRunResult => ({
  exitCode,
  stdout,
  stderr,
  isStdoutTruncated: false,
  isStderrTruncated: false,
})

/**
 * A hook's `$` as far as the loaders reach it: `process.run` and `state`. The engine's own test `$` has neither,
 * and a hook the test registers is refused both (the host lets a module call only what its scan finds). A string
 * answer is the error `process.run` rejects with; `argvs` records every command run.
 */
function world(answer: (argv: readonly string[]) => Answer | Promise<Answer>) {
  const argvs: (readonly string[])[] = []
  const values = new Map<string, { value: unknown; version: number }>()
  const $ = {
    process: {
      run: async (argv: readonly string[]) => {
        argvs.push([...argv])
        const got = await answer(argv)
        if (typeof got === 'string') throw new Error(got)
        return got
      },
    },
    state: {
      get: async (ref: { plugin: string; key: string }) => values.get(`${ref.plugin}/${ref.key}`) ?? { value: undefined, version: 0 },
      set: async (ref: { plugin: string; key: string }, value: unknown, options?: { ifVersion?: number }) => {
        const name = `${ref.plugin}/${ref.key}`
        const version = values.get(name)?.version ?? 0
        if (options?.ifVersion !== undefined && options.ifVersion !== version) return { isSet: false as const, version }
        values.set(name, { value, version: version + 1 })
        return { isSet: true as const, version: version + 1 }
      },
    },
  } as unknown as Hook
  return { $, argvs }
}

const gate = () => {
  let open!: () => void
  const opened = new Promise<void>((resolve) => (open = resolve))
  return { open, opened }
}

const both = (argv: readonly string[]) => (argv[1] === 'contract' ? ran(CONTRACT_JSON) : ran(EXPORT_MD))

test('loadLibraryRunsListAll', async () => {
  const w = world(() => ran(LIST_JSON))
  const load = await loadLibrary(w.$, 'personakit')
  expect(w.argvs).toEqual([['personakit', 'list', 'all', '--json']])
  expect(load.kind).toBe('loaded')
})

test('mcpServerNameReadsTheOption', () => {
  expect(mcpServerName({ mcpServerName: 'pk-dev' })).toBe('pk-dev')
  expect(mcpServerName({})).toBe('personakit')
  expect(mcpServerName({ mcpServerName: '' })).toBe('personakit')
  expect(mcpServerName({ mcpServerName: 7 })).toBe('personakit')
})

test('personakitBinaryReadsTheOption', () => {
  expect(personakitBinary({ personakitPath: '/opt/pk' })).toBe('/opt/pk')
  expect(personakitBinary({})).toBe('personakit')
  expect(personakitBinary({ personakitPath: '' })).toBe('personakit')
  expect(personakitBinary({ personakitPath: 3 })).toBe('personakit')
})

test('loadLibraryRunsTheConfiguredBinary', async () => {
  const w = world(() => ran(LIST_JSON))
  await loadLibrary(w.$, '/opt/pk')
  expect(w.argvs).toEqual([['/opt/pk', 'list', 'all', '--json']])
})

test('refreshLibraryRunsTheGivenBinary', async () => {
  const w = world(() => ran(LIST_JSON))
  await refreshLibrary(w.$, '/opt/pk')
  expect(w.argvs).toEqual([['/opt/pk', 'list', 'all', '--json']])
  expect((await read(w.$, pane)).library.kind).toBe('loaded')
})

test('loadLibraryStartFailure', async () => {
  const load = await loadLibrary(world(() => 'spawn personakit ENOENT').$, 'personakit')
  expect(load.kind).toBe('unavailable')
  if (load.kind !== 'unavailable') return
  expect(load.binary).toBe('personakit')
  expect(load.detail).toContain('ENOENT')
})

test('loadLibraryTimeout', async () => {
  const load = await loadLibrary(world(() => 'command timed out after 30000ms').$, 'personakit')
  expect(load.kind).toBe('unavailable')
  if (load.kind !== 'unavailable') return
  expect(load.binary).toBe('personakit')
  expect(load.detail).toContain('timed out')
})

test('loadLibraryNoProcess', async () => {
  const load = await loadLibrary(world(() => 'process is not available on this host').$, 'personakit')
  expect(load).toEqual({ kind: 'no-process' })
})

test('loadLibraryTruncatedOutput', async () => {
  const load = await loadLibrary(world(() => ({ ...ran(LIST_JSON), isStdoutTruncated: true })).$, 'personakit')
  expect(load.kind).toBe('unavailable')
  if (load.kind !== 'unavailable') return
  expect(load.binary).toBe('personakit')
  expect(load.detail).toContain('4 MiB')
})

test('loadLibraryOldBinary', async () => {
  const load = await loadLibrary(world(() => ran('', 64, 'Usage: personakit list <kind>')).$, 'personakit')
  expect(load.kind).toBe('unavailable')
})

test('loadLibraryErrorsDocument', async () => {
  expect((await loadLibrary(world(() => ran(LIST_ERRORS_JSON, 1)).$, 'personakit')).kind).toBe('errors')
})

test('previewKeyBySessionElsePair', () => {
  expect(previewKey({ sessionId: 'x', personaId: 'p', directiveId: 'd' })).toBe('session:x')
  expect(previewKey({ personaId: 'p', directiveId: 'd' })).toBe('pd:p/d')
})

test('loadPreviewSession', async () => {
  const w = world(both)
  const preview = await loadPreview(w.$, 'personakit', { sessionId: 'x' })
  expect(w.argvs).toEqual([
    ['personakit', 'contract', '--session=x'],
    ['personakit', 'export', '--session=x'],
  ])
  expect(preview.kind).toBe('loaded')
  if (preview.kind !== 'loaded') return
  expect(preview.contract?.personaId).toBe('read-only-auditor')
  expect(preview.details?.directiveTitle).toBe('Read-only audit pass')
})

test('loadPreviewPersonaAndDirective', async () => {
  const w = world(both)
  await loadPreview(w.$, 'personakit', { personaId: 'p', directiveId: 'd' })
  expect(w.argvs[0]).toEqual(['personakit', 'contract', '--persona=p', '--directive=d'])
  expect(w.argvs[1]).toEqual(['personakit', 'export', '--persona=p', '--directive=d'])
})

test('loadPreviewFailure', async () => {
  const w = world(() => ran('', 1, 'error: no such session\nusage: ...'))
  expect(await loadPreview(w.$, 'personakit', { sessionId: 'x' })).toEqual({ kind: 'failed', message: 'error: no such session' })
})

test('loadPreviewExportFailure', async () => {
  const w = world((argv) => (argv[1] === 'contract' ? ran(CONTRACT_JSON) : ran('', 1, 'export broke')))
  expect(await loadPreview(w.$, 'personakit', { sessionId: 'x' })).toEqual({ kind: 'failed', message: 'export broke' })
})

test('loadPreviewRejects', async () => {
  const preview = await loadPreview(world(() => 'spawn personakit ENOENT').$, 'personakit', { sessionId: 'x' })
  expect(preview.kind).toBe('failed')
  if (preview.kind === 'failed') expect(preview.message).toContain('ENOENT')
})

test('loadPreviewTruncated', async () => {
  const w = world(() => ({ ...ran(CONTRACT_JSON), isStdoutTruncated: true }))
  expect(await loadPreview(w.$, 'personakit', { sessionId: 'x' })).toEqual({ kind: 'failed', message: 'output passed 4 MiB' })
})

test('loadPreviewNotAContract', async () => {
  const preview = await loadPreview(world(() => ran('not json')).$, 'personakit', { sessionId: 'x' })
  expect(preview.kind).toBe('failed')
})

test('staleLoadIsDropped', async () => {
  const answers = [LIST_JSON, LIST_MERGED_JSON]
  const started = [gate(), gate()]
  const release = [gate(), gate()]
  let n = 0
  const w = world(async () => {
    const i = n++
    started[i]?.open()
    await release[i]?.opened
    return ran(answers[i] ?? '')
  })
  const first = refreshLibrary(w.$, 'personakit')
  await started[0]?.opened
  const second = refreshLibrary(w.$, 'personakit')
  await started[1]?.opened
  expect((await read(w.$, pane)).library.kind).toBe('loading')
  release[1]?.open()
  await second
  release[0]?.open()
  await first
  const { library, token } = await read(w.$, pane)
  expect(token).toBe(2)
  expect(library.kind).toBe('loaded')
  if (library.kind !== 'loaded') return
  expect(library.library.scopes).toEqual({ global: '<GLOBAL>', project: '<PROJECT>' })
})

test('openPreviewRunsTheGivenBinary', async () => {
  const w = world(both)
  await openPreview(w.$, '/opt/pk', { sessionId: 'x' })
  expect(w.argvs).toEqual([
    ['/opt/pk', 'contract', '--session=x'],
    ['/opt/pk', 'export', '--session=x'],
  ])
})

test('openPreviewIsNoOpWhenLoaded', async () => {
  const w = world(both)
  await openPreview(w.$, 'personakit', { sessionId: 'x' })
  await openPreview(w.$, 'personakit', { sessionId: 'x' })
  expect(w.argvs).toHaveLength(2)
  expect((await read(w.$, pane)).previews['session:x']?.kind).toBe('loaded')
})

test('openPreviewIsNoOpWhileLoading', async () => {
  const started = gate()
  const release = gate()
  const w = world(async (argv) => {
    started.open()
    await release.opened
    return both(argv)
  })
  const first = openPreview(w.$, 'personakit', { sessionId: 'x' })
  await started.opened
  expect((await read(w.$, pane)).previews['session:x']?.kind).toBe('loading')
  await openPreview(w.$, 'personakit', { sessionId: 'x' })
  release.open()
  await first
  expect(w.argvs).toHaveLength(2)
  expect((await read(w.$, pane)).previews['session:x']?.kind).toBe('loaded')
})

test('refreshClearsLoadedPreviews', async () => {
  const w = world((argv) => (argv[1] === 'list' ? ran(LIST_JSON) : both(argv)))
  await openPreview(w.$, 'personakit', { sessionId: 'x' })
  expect((await read(w.$, pane)).previews['session:x']?.kind).toBe('loaded')
  await refreshLibrary(w.$, 'personakit')
  expect((await read(w.$, pane)).previews).toEqual({})
})

test('previewStartedBeforeRefreshDoesNotLand', async () => {
  const started = gate()
  const release = gate()
  const w = world(async (argv) => {
    if (argv[1] === 'list') return ran(LIST_JSON)
    started.open()
    await release.opened
    return both(argv)
  })
  const preview = openPreview(w.$, 'personakit', { sessionId: 'x' })
  await started.opened
  await refreshLibrary(w.$, 'personakit')
  expect((await read(w.$, pane)).previews['session:x']).toBeUndefined()
  release.open()
  await preview
  expect((await read(w.$, pane)).previews['session:x']).toBeUndefined()
})

test('openPreviewRetriesAfterFailure', async () => {
  let isBroken = true
  const w = world((argv) => (isBroken ? ran('', 1, 'nope') : both(argv)))
  await openPreview(w.$, 'personakit', { sessionId: 'x' })
  expect((await read(w.$, pane)).previews['session:x']).toEqual({ kind: 'failed', message: 'nope' })
  isBroken = false
  await openPreview(w.$, 'personakit', { sessionId: 'x' })
  expect((await read(w.$, pane)).previews['session:x']?.kind).toBe('loaded')
})

test('previewNeverTouchesSession', async () => {
  const w = world(both)
  const before = await read(w.$, session)
  await openPreview(w.$, 'personakit', { sessionId: 'x' })
  await refreshLibrary(w.$, 'personakit')
  expect(await read(w.$, session)).toEqual(before)
})
