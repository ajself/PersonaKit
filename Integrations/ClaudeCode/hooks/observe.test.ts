import { expect, test } from 'claude-code/testing'

import { isPersonaKitCall, observe } from './lib/observe'
import { CONTRACT_JSON, EXPORT_MD } from './fixtures/golden'

const none = async () => undefined
const trusted = ['personakit']

const mcp = (text: string, extra: Record<string, unknown> = {}) => ({ result: text, text, ...extra }) as never
const bash = (stdout: string, extra: Record<string, unknown> = {}) =>
  ({ result: { stdout, stderr: '', interrupted: false, ...extra }, text: stdout }) as never
const runTruncated = (command: string) =>
  observe(
    { tool: 'Bash', input: { command }, result: bash('', { persistedOutputPath: '/tmp/gone.txt' }) },
    trusted,
    none,
  )
const run = (command: string, stdout: string, readPersisted = none) =>
  observe({ tool: 'Bash', input: { command }, result: bash(stdout) }, trusted, readPersisted)

test('MCP resolve from a trusted server yields a contract', async () => {
  const o = await observe(
    { tool: 'mcp__personakit__personakit_resolve_contract', input: {}, result: mcp(CONTRACT_JSON) },
    trusted,
    none,
  )
  expect(o?.kind).toBe('contract')
  expect(o?.source).toBe('mcp')
  expect(o?.ids).toEqual({
    sessionId: 'read-only-auditor_audit-pass',
    personaId: 'read-only-auditor',
    directiveId: 'audit-pass',
  })
})

test('MCP export ids come from input and details', async () => {
  const o = await observe(
    {
      tool: 'mcp__personakit__personakit_export',
      input: { sessionId: 'read-only-auditor_audit-pass' },
      result: mcp(EXPORT_MD),
    },
    trusted,
    none,
  )
  expect(o?.kind).toBe('export')
  expect(o?.ids).toEqual({
    sessionId: 'read-only-auditor_audit-pass',
    personaId: 'read-only-auditor',
    directiveId: 'audit-pass',
  })
  expect(o?.kind === 'export' && o.details !== undefined).toBe(true)
})

test('untrusted server is ignored', async () => {
  const o = await observe(
    { tool: 'mcp__evil__personakit_resolve_contract', input: {}, result: mcp(CONTRACT_JSON) },
    trusted,
    none,
  )
  expect(o).toBe(undefined)
})

test('CLI contract and export are recognized', async () => {
  const c = await run('personakit contract --session x', CONTRACT_JSON)
  expect(c?.kind).toBe('contract')
  expect(c?.source).toBe('cli')

  const e1 = await run('/usr/local/bin/personakit export --session x --stats', EXPORT_MD)
  expect(e1?.kind).toBe('export')
  expect(e1?.ids.sessionId).toBe('x')

  const e2 = await run('swift run personakit export --session x', EXPORT_MD)
  expect(e2?.kind).toBe('export')

  const e3 = await observe(
    {
      tool: 'Bash',
      input: { command: 'cd /p && FOO=1 personakit export --persona p --directive d | head' },
      result: bash('', { persistedOutputPath: '/tmp/gone.txt' }),
    },
    trusted,
    none,
  )
  expect(e3).toEqual({ kind: 'export', source: 'cli', ids: { personaId: 'p', directiveId: 'd' } })

  const e4 = await runTruncated('personakit export --session=y --persona=p2')
  expect(e4?.ids).toEqual({ sessionId: 'y', personaId: 'p2' })
})

test('commands that only mention personakit are not observed', async () => {
  expect(await run('git commit -m "personakit export fix"', 'x')).toBe(undefined)
  expect(await run('cat personakit contract.md', 'x')).toBe(undefined)
  expect(await run('echo personakit contract', 'x')).toBe(undefined)
})

test('--copy and --output exports are not observed', async () => {
  expect(await run('personakit export --session x --copy', EXPORT_MD)).toBe(undefined)
  expect(await run('personakit export --session x --output /tmp/a.md', EXPORT_MD)).toBe(undefined)
})

test('persisted Bash output is read', async () => {
  const o = await observe(
    {
      tool: 'Bash',
      input: { command: 'personakit export --session x' },
      result: bash('', { persistedOutputPath: '/tmp/out.txt' }),
    },
    trusted,
    async (path) => (path === '/tmp/out.txt' ? EXPORT_MD : undefined),
  )
  expect(o?.kind === 'export' && o.details?.personaId).toBe('read-only-auditor')
})

test('truncated or unavailable output keeps ids', async () => {
  const o = await observe(
    {
      tool: 'Bash',
      input: { command: 'personakit export --session x' },
      result: bash('', { persistedOutputPath: '/tmp/gone.txt' }),
    },
    trusted,
    none,
  )
  expect(o).toEqual({ kind: 'export', source: 'cli', ids: { sessionId: 'x' } })
})

test('errored or unparseable output fails', async () => {
  const errored = await observe(
    {
      tool: 'Bash',
      input: { command: 'personakit contract --session x' },
      result: { isError: true, result: 'boom', text: 'boom' } as never,
    },
    trusted,
    none,
  )
  expect(errored).toEqual({ kind: 'failed', source: 'cli', ids: { sessionId: 'x' } })
  expect((await run('personakit contract --session x', 'garbage'))?.kind).toBe('failed')
  expect((await run('personakit export --session x', 'garbage'))?.kind).toBe('failed')
})

test('isPersonaKitCall covers trusted MCP tools and CLI commands', () => {
  expect(isPersonaKitCall('mcp__personakit__personakit_export', {}, trusted)).toBe(true)
  expect(isPersonaKitCall('mcp__evil__personakit_export', {}, trusted)).toBe(false)
  expect(isPersonaKitCall('Bash', { command: 'personakit export --session x --copy' }, trusted)).toBe(true)
  expect(isPersonaKitCall('Bash', { command: 'echo personakit export' }, trusted)).toBe(false)
  expect(isPersonaKitCall('Read', { file_path: 'personakit export' }, trusted)).toBe(false)
})

test('persisted output wins over a truncated stdout preview', async () => {
  const call = {
    tool: 'Bash',
    input: { command: 'personakit contract --session x' },
    result: bash(CONTRACT_JSON.slice(0, 200), { persistedOutputPath: '/tmp/c.txt' }),
  }
  const full = await observe(call, trusted, async () => CONTRACT_JSON)
  expect(full?.kind === 'contract' && full.contract?.personaId).toBe('read-only-auditor')
  const gone = await observe(call, trusted, none)
  expect(gone).toEqual({ kind: 'contract', source: 'cli', ids: { sessionId: 'x' } })
})

test('contract accepts --session=x', async () => {
  expect((await runTruncated('personakit contract --session=x'))?.ids).toEqual({ sessionId: 'x' })
})

test('MCP result with no text fails', async () => {
  const o = await observe(
    { tool: 'mcp__personakit__personakit_export', input: { sessionId: 'x' }, result: { result: {} } as never },
    trusted,
    none,
  )
  expect(o).toEqual({ kind: 'failed', source: 'mcp', ids: { sessionId: 'x' } })
})

test('a quoted operator does not start a command', async () => {
  expect(await run('echo "a && personakit export --session x"', 'x')).toBe(undefined)
})

test('output that never reached the agent is not observed', async () => {
  expect(await run('personakit export --session x > out.md', '')).toBe(undefined)
  expect(await run('personakit export --session x | pbcopy', '')).toBe(undefined)
})
