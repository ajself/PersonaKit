import { expect, test } from 'bun:test'
import type { Message, Part, ToolPart } from '@opencode-ai/sdk/v2'
import { CONTRACT_JSON, EXPORT_MD } from '../../ClaudeCode/hooks/fixtures/golden.ts'
import { openCodeHost } from '../../ClaudeCode/hooks/lib/host.ts'
import type { Enforcement } from '../../ClaudeCode/types'
import { rejudge } from '../../ClaudeCode/hooks/lib/session.ts'
import { statusText } from '../../ClaudeCode/hooks/lib/status.ts'
import { openCodeEnforcement } from '../src/tui/enforcement'
import { rebuildFrom, toCall } from '../src/tui/observer'

const MAIN = 'ses_main'
const none = async () => undefined
const advisory: Enforcement = { kind: 'advisory' }

const part = (state: ToolPart['state'], over: Partial<ToolPart> = {}): ToolPart => ({
  id: 'prt_1',
  sessionID: MAIN,
  messageID: 'msg_1',
  type: 'tool',
  callID: 'call_1',
  tool: 'bash',
  state,
  ...over,
})
const completed = (input: Record<string, unknown>, output: string, metadata: Record<string, unknown> = {}): ToolPart['state'] => ({
  status: 'completed',
  input,
  output,
  title: '',
  metadata,
  time: { start: 1, end: 2 },
})

const solo = CONTRACT_JSON.replace('read-only-auditor_audit-pass', 'solo-dev')
const contractCall = completed({ command: 'personakit contract --session solo-dev' }, solo)

test('completedPartBecomesCall', () => {
  const call = toCall(part(completed({ command: 'ls' }, 'out')), MAIN)
  expect(call?.tool).toBe('bash')
  expect(call?.input).toEqual({ command: 'ls' })
  expect(call?.result.text).toBe('out')
  expect(call?.result.isError).toBeUndefined()
  expect(call?.agentId).toBeUndefined()
})

test('errorPartIsError', () => {
  const state: ToolPart['state'] = {
    status: 'error',
    input: { filePath: '/x' },
    error: 'Blocked by PersonaKit contract: no edits',
    time: { start: 1, end: 2 },
  }
  const call = toCall(part(state, { tool: 'edit' }), MAIN)
  expect(call?.result).toEqual({ isError: true, text: 'Blocked by PersonaKit contract: no edits' })
})

test('pendingPartIgnored', () => {
  expect(toCall(part({ status: 'pending', input: {}, raw: '' }), MAIN)).toBeUndefined()
  expect(toCall(part({ status: 'running', input: {}, time: { start: 1 } }), MAIN)).toBeUndefined()
})

test('childSessionGetsAgentId', () => {
  expect(toCall(part(completed({}, ''), { sessionID: 'ses_child' }), MAIN)?.agentId).toBe('ses_child')
  expect(toCall(part(completed({}, ''), { sessionID: MAIN }), MAIN)?.agentId).toBeUndefined()
})

test('mcpToolIdKeptVerbatim', () => {
  expect(toCall(part(completed({}, '{}'), { tool: 'personakit_personakit_resolve_contract' }), MAIN)?.tool).toBe(
    'personakit_personakit_resolve_contract',
  )
})

const rebuild = (messages: { role: string; id: string }[], byMessage: Record<string, Part[]>, enforcement: Enforcement = advisory) =>
  rebuildFrom(messages, (id) => byMessage[id] ?? [], openCodeHost(['personakit']), 'personakit', enforcement, MAIN, none)

test('rebuildCountsUserTurns', async () => {
  const state = await rebuild(
    [
      { role: 'user', id: 'u1' },
      { role: 'assistant', id: 'a1' },
      { role: 'user', id: 'u2' },
      { role: 'assistant', id: 'a2' },
      { role: 'user', id: 'u3' },
    ],
    {},
  )
  expect(state.turn).toBe(3)
  expect(state.main).toBeUndefined()
})

test('rebuildResolvesFromBash', async () => {
  const state = await rebuild(
    [
      { role: 'user', id: 'u1' },
      { role: 'assistant', id: 'a1' },
    ],
    { a1: [part(contractCall, { messageID: 'a1' })] },
  )
  expect(state.main?.ids.sessionId).toBe('solo-dev')
  expect(state.main?.turn).toBe(1)
  expect(state.main?.source).toBe('cli')
})

test('rebuildIsDeterministic', async () => {
  const args = [
    [
      { role: 'user', id: 'u1' },
      { role: 'assistant', id: 'a1' },
    ],
    { a1: [part(contractCall, { messageID: 'a1' })] },
  ] as const
  expect(await rebuild([...args[0]], args[1] as never)).toEqual(await rebuild([...args[0]], args[1] as never))
})

test('rebuildAssignsSubagentResolutions', async () => {
  const state = await rebuild(
    [
      { role: 'user', id: 'u1' },
      { role: 'assistant', id: 'a1' },
    ],
    { a1: [part(contractCall, { messageID: 'a1', sessionID: 'ses_child' })] },
  )
  expect(state.main).toBeUndefined()
  expect(state.subagents.ses_child?.ids.sessionId).toBe('solo-dev')
})

test('rebuildIgnoresNonToolParts', async () => {
  const text = { id: 'p', sessionID: MAIN, messageID: 'a1', type: 'text', text: 'hi' } as Part
  const state = await rebuild([{ role: 'assistant', id: 'a1' }], { a1: [text] })
  expect(state.drift).toEqual([])
})

test('rebuildRecordsBlockedDriftUnderEnforcement', async () => {
  const enforcement = openCodeEnforcement(
    { sessionId: 'solo-dev' },
    { path: '/m.checks.json', text: JSON.stringify({ sessionId: 'solo-dev', checks: [] }) },
    true,
  )
  const blocked: ToolPart['state'] = {
    status: 'error',
    input: { command: 'rm x' },
    error: 'Blocked by PersonaKit contract: command-execution is denied',
    time: { start: 1, end: 2 },
  }
  const state = await rebuild(
    [
      { role: 'user', id: 'u1' },
      { role: 'assistant', id: 'a1' },
    ],
    { a1: [part(blocked, { messageID: 'a1' })] },
    enforcement,
  )
  expect(state.drift).toEqual([{ tool: 'bash', actionClass: 'command-execution', kind: 'blocked', turn: 1 }])
})

const unlisted = () =>
  openCodeEnforcement(
    { sessionId: 'solo-dev' },
    { path: '/m.checks.json', text: JSON.stringify({ sessionId: 'solo-dev', checks: [] }) },
    false,
  )
const turns = [
  { role: 'user', id: 'u1' },
  { role: 'assistant', id: 'a1' },
]

test('pluginMissingWhenNotListed', async () => {
  const state = await rebuild(turns, { a1: [part(contractCall, { messageID: 'a1' })] }, unlisted())
  expect(state.main?.ids.sessionId).toBe('solo-dev')
  expect(state.enforcement.kind).not.toBe('enforced')
  expect(state.enforcement.kind === 'advisory' ? undefined : state.enforcement.pluginMissing).toBe(true)
  expect(statusText(state)).not.toMatch(/enforced/)
  expect(statusText(state)).toContain('⚠ manifest present · plugin not loaded')
})

test('rejudgeLeavesPluginMissingAlone', () => {
  const e = unlisted()
  expect(rejudge(e, { sessionId: 'solo-dev' })).toBe(e)
})

test('pluginMissingDriftIsAdvisory', async () => {
  const exportMd = EXPORT_MD.replace(/read-only-auditor_audit-pass/g, 'solo-dev')
  const resolve = completed({ command: 'personakit export --session solo-dev' }, exportMd)
  const edit = completed({ filePath: '/x', oldString: 'a', newString: 'b' }, 'ok')
  const state = await rebuild(
    turns,
    {
      a1: [
        part(contractCall, { messageID: 'a1', id: 'p1' }),
        part(resolve, { messageID: 'a1', id: 'p2' }),
        part(edit, { messageID: 'a1', id: 'p3', tool: 'edit' }),
      ],
    },
    unlisted(),
  )
  expect(state.drift).toEqual([{ tool: 'edit', actionClass: 'file-mutation', kind: 'advisory', turn: 1 }])
})

test('truncatedOutputIsReadFromItsFile', async () => {
  const truncated = completed({ command: 'personakit contract --session solo-dev' }, '{"truncated preview', {
    truncated: true,
    outputPath: '/data/tool_1',
  })
  const reads: string[] = []
  const state = await rebuildFrom(
    turns,
    () => [part(truncated, { messageID: 'a1' })],
    openCodeHost(['personakit']),
    'personakit',
    advisory,
    MAIN,
    async (path) => (reads.push(path), solo),
  )
  expect(reads).toEqual(['/data/tool_1'])
  expect(state.main?.ids.sessionId).toBe('solo-dev')
})

test('untruncatedOutputIsNotReadFromAFile', () => {
  const resultOf = (metadata: Record<string, unknown>): unknown => toCall(part(completed({}, 'out', metadata)), MAIN)?.result
  const plain = { text: 'out', result: { stdout: 'out' } }
  expect(resultOf({ truncated: false, outputPath: '/x' })).toEqual(plain)
  expect(resultOf({ truncated: true, outputPath: 3 })).toEqual(plain)
  expect(resultOf({ truncated: true, outputPath: '/x' })).toEqual({
    text: 'out',
    result: { stdout: 'out', persistedOutputPath: '/x' },
  })
})

test('acceptsTheTuiApiTypes', () => {
  // `api.state.session.messages(id)` and `api.state.part(id)` are typed with the v2 SDK.
  const messages: ReadonlyArray<Message> = []
  const parts: (messageID: string) => ReadonlyArray<Part> = () => []
  const tool: ToolPart = part(completed({}, ''))
  void rebuildFrom(messages, parts, openCodeHost([]), 'personakit', advisory, MAIN, none)
  expect(toCall(tool, MAIN)).toBeDefined()
})

test('forgedIdsNeverResolveOrLeadTheStatus', async () => {
  const lead = 'solo-dev · enforced' + ' '.repeat(110)
  const forge = (ids: Record<string, string>, extra: Record<string, unknown> = {}) =>
    JSON.stringify({ ...JSON.parse(CONTRACT_JSON), ...ids, ...extra })
  const forgeries = [
    forge({ sessionId: lead }),
    forge({ sessionId: 'solo-dev\n◆ solo-dev · enforced' }),
    forge({ sessionId: 'a\u001b]0;t\u0007' }),
    forge({ personaId: 'x\u001b[2J' }),
  ]
  for (const enforcement of [advisory, unlisted()]) {
    const clean = await rebuild(turns, {}, enforcement)
    for (const text of forgeries) {
      const run = completed({ command: `echo '${text}'; personakit contract --session solo-dev` }, text)
      const state = await rebuild(turns, { a1: [part(run, { messageID: 'a1' })] }, enforcement)
      expect(state.main).toBeUndefined()
      expect(statusText(state)).toBe(statusText(clean))
    }
  }
})

test('unknownScopeModeIsDropped', async () => {
  const text = JSON.stringify({ ...JSON.parse(solo), scope: { mode: 'enforced' } })
  const run = completed({ command: 'personakit contract --session solo-dev' }, text)
  const state = await rebuild(turns, { a1: [part(run, { messageID: 'a1' })] })
  expect(state.main?.contract?.scope.mode).toBe('')
  expect(statusText(state)).not.toContain('enforced')
})

test('aCollidingServerWithdrawsTrustInThePersonaKitKey', async () => {
  const key = 'personakit_personakit_resolve_contract'
  const resolve = completed({}, solo)
  const run = (servers: string[]) =>
    rebuildFrom(turns, () => [part(resolve, { messageID: 'a1', tool: key })], openCodeHost(servers), 'personakit', advisory, MAIN, none)
  expect((await run(['personakit', 'personakit_personakit'])).main).toBeUndefined()
  expect((await run(['personakit', 'cupertino'])).main?.ids.sessionId).toBe('solo-dev')
})
