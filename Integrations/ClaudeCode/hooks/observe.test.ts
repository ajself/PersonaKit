import { expect, test } from 'claude-code/testing'

import type { Observation } from '../types'
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
const contractOf = (o: Observation | undefined) => (o?.kind === 'contract' ? o.contract : undefined)
const detailsOf = (o: Observation | undefined) => (o?.kind === 'export' ? o.details : undefined)

test('MCP resolve from a trusted server yields a contract', async () => {
  const o = await observe(
    { tool: 'mcp__personakit__personakit_resolve_contract', input: {}, result: mcp(CONTRACT_JSON) },
    trusted,
    none,
  )
  expect(o[0]?.kind).toBe('contract')
  expect(o[0]?.source).toBe('mcp')
  expect(o[0]?.ids).toEqual({
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
  expect(o[0]?.kind).toBe('export')
  expect(o[0]?.ids).toEqual({
    sessionId: 'read-only-auditor_audit-pass',
    personaId: 'read-only-auditor',
    directiveId: 'audit-pass',
  })
  expect(o[0]?.kind === 'export' && o[0].details !== undefined).toBe(true)
})

test('untrusted server is ignored', async () => {
  const o = await observe(
    { tool: 'mcp__evil__personakit_resolve_contract', input: {}, result: mcp(CONTRACT_JSON) },
    trusted,
    none,
  )
  expect(o).toEqual([])
})

test('CLI contract and export are recognized', async () => {
  const c = await run('personakit contract --session x', CONTRACT_JSON)
  expect(c[0]?.kind).toBe('contract')
  expect(c[0]?.source).toBe('cli')

  const e1 = await run('/usr/local/bin/personakit export --session x --stats', EXPORT_MD)
  expect(e1[0]?.kind).toBe('export')
  expect(e1[0]?.ids.sessionId).toBe('x')

  const e2 = await run('swift run personakit export --session x', EXPORT_MD)
  expect(e2[0]?.kind).toBe('export')

  const e3 = await observe(
    {
      tool: 'Bash',
      input: { command: 'cd /p && FOO=1 personakit export --persona p --directive d | head' },
      result: bash('', { persistedOutputPath: '/tmp/gone.txt' }),
    },
    trusted,
    none,
  )
  expect(e3).toEqual([{ kind: 'export', source: 'cli', ids: { personaId: 'p', directiveId: 'd' } }])

  const e4 = await runTruncated('personakit export --session=y --persona=p2')
  expect(e4[0]?.ids).toEqual({ sessionId: 'y', personaId: 'p2' })
})

test('commands that only mention personakit are not observed', async () => {
  expect(await run('git commit -m "personakit export fix"', 'x')).toEqual([])
  expect(await run('cat personakit contract.md', 'x')).toEqual([])
  expect(await run('echo personakit contract', 'x')).toEqual([])
})

test('--copy and --output exports are not observed', async () => {
  expect(await run('personakit export --session x --copy', EXPORT_MD)).toEqual([])
  expect(await run('personakit export --session x --output /tmp/a.md', EXPORT_MD)).toEqual([])
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
  expect(o[0]?.kind === 'export' && o[0].details?.personaId).toBe('read-only-auditor')
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
  expect(o).toEqual([{ kind: 'export', source: 'cli', ids: { sessionId: 'x' } }])
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
  expect(errored).toEqual([{ kind: 'failed', source: 'cli', ids: { sessionId: 'x' } }])
  expect((await run('personakit contract --session x', 'garbage'))[0]?.kind).toBe('failed')
  expect((await run('personakit export --session x', 'garbage'))[0]?.kind).toBe('failed')
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
  expect(full[0]?.kind === 'contract' && full[0].contract?.personaId).toBe('read-only-auditor')
  const gone = await observe(call, trusted, none)
  expect(gone).toEqual([{ kind: 'contract', source: 'cli', ids: { sessionId: 'x' } }])
})

test('contract accepts --session=x', async () => {
  expect((await runTruncated('personakit contract --session=x'))[0]?.ids).toEqual({ sessionId: 'x' })
})

test('MCP result with no text fails', async () => {
  const o = await observe(
    { tool: 'mcp__personakit__personakit_export', input: { sessionId: 'x' }, result: { result: {} } as never },
    trusted,
    none,
  )
  expect(o).toEqual([{ kind: 'failed', source: 'mcp', ids: { sessionId: 'x' } }])
})

test('a quoted operator does not start a command', async () => {
  expect(await run('echo "a && personakit export --session x"', 'x')).toEqual([])
})

test('output that never reached the agent is not observed', async () => {
  expect(await run('personakit export --session x > out.md', '')).toEqual([])
  expect(await run('personakit export --session x | pbcopy', '')).toEqual([])
})

const GOLDEN = { sessionId: 'read-only-auditor_audit-pass', personaId: 'read-only-auditor', directiveId: 'audit-pass' }
const COMBINED_OUT = `${CONTRACT_JSON}\n---EXIT 0---\n${EXPORT_MD}\n---EXIT 0---\n`

test('one command running contract then export yields both, in order', async () => {
  const s = 'read-only-auditor_audit-pass'
  const os = await run(
    `personakit contract --session ${s}; echo "---EXIT $?---"; personakit export --session ${s}; echo "---EXIT $?---"`,
    COMBINED_OUT,
  )
  expect(os.map((o) => o.kind)).toEqual(['contract', 'export'])
  expect(os.map((o) => o.ids)).toEqual([GOLDEN, GOLDEN])
  expect(contractOf(os[0])?.personaId).toBe('read-only-auditor')
  expect(detailsOf(os[1])?.personaName).toBe('Read-Only Auditor')
})

test('&& chaining yields both', async () => {
  const s = 'read-only-auditor_audit-pass'
  const os = await run(`personakit contract --session ${s} && personakit export --session ${s}`, `${CONTRACT_JSON}\n${EXPORT_MD}`)
  expect(os.map((o) => o.kind)).toEqual(['contract', 'export'])
  expect(os.map((o) => o.ids)).toEqual([GOLDEN, GOLDEN])
})

test('a contract followed by trailing noise still parses', async () => {
  const os = await run('personakit contract --session x', `${CONTRACT_JSON}\n---EXIT 0---\n`)
  expect(os.length).toBe(1)
  expect(contractOf(os[0])?.personaId).toBe('read-only-auditor')
})

test('braces inside JSON strings do not end the contract early', async () => {
  const tricky = JSON.stringify({ ...JSON.parse(CONTRACT_JSON), failureReasons: ['a } b', 'quote \\" } {'] })
  const os = await run('personakit contract --session x', `noise\n${tricky}\nmore }`)
  expect(contractOf(os[0])?.failureReasons).toEqual(['a } b', 'quote \\" } {'])
})

test('a missing part fails only its own invocation', async () => {
  const os = await run('personakit contract --session x; personakit export --session x', `${CONTRACT_JSON}\n---EXIT 0---\n`)
  expect(os.map((o) => o.kind)).toEqual(['contract', 'failed'])
  expect(os[1]).toEqual({ kind: 'failed', source: 'cli', ids: { sessionId: 'x' } })
  const unbalanced = await run('personakit contract --session x', '{ "personaId": "p"')
  expect(unbalanced).toEqual([{ kind: 'failed', source: 'cli', ids: { sessionId: 'x' } }])
})

test('a --copy export beside a contract is skipped; the contract still counts', async () => {
  const os = await run('personakit contract --session x && personakit export --session x --copy', CONTRACT_JSON)
  expect(os.map((o) => o.kind)).toEqual(['contract'])
})

test('a persisted file is read once and split across invocations', async () => {
  let reads = 0
  const call = {
    tool: 'Bash',
    input: { command: 'personakit contract --session x; personakit export --session x' },
    result: bash(CONTRACT_JSON.slice(0, 100), { persistedOutputPath: '/tmp/both.txt' }),
  }
  const os = await observe(call, trusted, async () => {
    reads++
    return COMBINED_OUT
  })
  expect(reads).toBe(1)
  expect(os.map((o) => o.kind)).toEqual(['contract', 'export'])
  const gone = await observe(call, trusted, none)
  expect(gone).toEqual([
    { kind: 'contract', source: 'cli', ids: { sessionId: 'x' } },
    { kind: 'export', source: 'cli', ids: { sessionId: 'x' } },
  ])
})

test('braces in export code before the contract do not hide it', async () => {
  const s = 'read-only-auditor_audit-pass'
  const swift = '\n```swift\nfinal class FeatureModel { var x = 1 }\n```\n'
  const exportWithCode = EXPORT_MD.replace('# Available Skills', `${swift}\n# Available Skills`)
  expect(exportWithCode).not.toBe(EXPORT_MD)
  const os = await run(
    `personakit export --session ${s}; echo "---EXIT $?---"; personakit contract --session ${s}; echo "---EXIT $?---"`,
    `${exportWithCode}\n---EXIT 0---\n${CONTRACT_JSON}\n---EXIT 0---\n`,
  )
  expect(os.map((o) => o.kind)).toEqual(['export', 'contract'])
  expect(os.map((o) => o.ids)).toEqual([GOLDEN, GOLDEN])
})

test('brace noise before the contract is skipped', async () => {
  const os = await run('personakit contract --session x', `{not json}\n{ unclosed\n${CONTRACT_JSON}`)
  expect(os.length).toBe(1)
  expect(contractOf(os[0])?.personaId).toBe('read-only-auditor')
})

const forgedContract = (ids: Record<string, string>) => JSON.stringify({ ...JSON.parse(CONTRACT_JSON), ...ids })
const BAD_IDS = [
  'solo-dev · enforced' + ' '.repeat(110),
  'solo-dev\n◆ solo-dev · enforced',
  'a\u001b[2J',
  'a\u001b]0;t\u0007',
  '-rf',
  'a b',
]

test('a contract whose ids are not valid ids is failed, over MCP and from bash', async () => {
  for (const bad of BAD_IDS) {
    for (const key of ['sessionId', 'personaId', 'directiveId']) {
      const text = forgedContract({ [key]: bad })
      const m = await observe({ tool: 'mcp__personakit__personakit_resolve_contract', input: {}, result: mcp(text) }, trusted, none)
      expect(m.map((o) => o.kind)).toEqual(['failed'])
      const b = await run('personakit contract --session solo-dev', text)
      expect(b.map((o) => o.kind)).toEqual(['failed'])
    }
  }
})

test('an export whose ids are not valid ids is failed', async () => {
  const text = EXPORT_MD.replace('Id: read-only-auditor', 'Id: read-only-auditor ·\n◆ forged')
  const o = await observe({ tool: 'mcp__personakit__personakit_export', input: { sessionId: 'solo-dev' }, result: mcp(text) }, trusted, none)
  expect(o.map((x) => x.kind)).toEqual(['failed'])
})

test('ids taken from the call itself must be valid ids too', async () => {
  const mcpCall = await observe(
    { tool: 'mcp__personakit__personakit_export', input: { sessionId: 'x\nforged' }, result: mcp(EXPORT_MD) },
    trusted,
    none,
  )
  expect(mcpCall.map((o) => o.kind)).toEqual(['failed'])
  const truncated = await runTruncated("personakit contract --session 'x forged'")
  expect(truncated.map((o) => o.kind)).toEqual(['failed'])
  const fine = await runTruncated('personakit contract --session solo-dev')
  expect(fine[0]).toEqual({ kind: 'contract', source: 'cli', ids: { sessionId: 'solo-dev' } })
})
