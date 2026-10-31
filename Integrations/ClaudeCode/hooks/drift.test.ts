import { expect, test } from 'claude-code/testing'

import type { Enforcement } from '../types'
import { TOOL_ACTION_CLASSES, classifyDrift } from './lib/drift'
import { TOOL_ACTION_CLASSES_JSON } from './fixtures/golden'
import { openCodeHost } from './lib/host'

const trusted = ['personakit']
const advisory: Enforcement = { kind: 'advisory' }
const enforced = (matcherTools = ['Edit', 'Write', 'NotebookEdit', 'Bash', 'mcp__.*'], extra: Record<string, unknown> = {}): Enforcement =>
  ({ kind: 'enforced', manifestPath: '/p/.claude/personakit/s.checks.json', ids: { sessionId: 's' }, deniedActionClasses: ['file-mutation'], matcherTools, ...extra }) as Enforcement

const DENY = 'Blocked by PersonaKit contract: capability-deny.edit-files'
const ok = (text = '') => ({ result: text, text }) as never
const err = (text: string) => ({ result: text, text, isError: true }) as never
const classify = (
  call: { tool: string; input?: Record<string, unknown>; result: never; agentId?: string },
  denied: string[],
  enforcement: Enforcement,
) => classifyDrift({ input: {}, ...call }, denied, enforcement, trusted, 4)

test('TOOL_ACTION_CLASSES mirrors the Swift map', () => {
  expect(TOOL_ACTION_CLASSES).toEqual(JSON.parse(TOOL_ACTION_CLASSES_JSON))
})

test('enforced denial is blocked', () => {
  expect(classify({ tool: 'Edit', result: err(DENY) }, [], enforced())).toEqual({
    tool: 'Edit', kind: 'blocked', actionClass: 'file-mutation', turn: 4,
  })
  expect(
    classify({ tool: 'Edit', result: err('PersonaKit enforcement could not parse the tool call') }, [], enforced())?.kind,
  ).toBe('blocked')
})

test('a refused operator prompt under the route-every-tool matcher is blocked', () => {
  const ask = "PersonaKit contract needs approval: PersonaKit cannot classify tool 'CronCreate'"
  expect(classify({ tool: 'CronCreate', result: err(ask) }, [], enforced(['.*']))).toEqual({
    tool: 'CronCreate', kind: 'blocked', turn: 4,
  })
  expect(classify({ tool: 'Bash', result: err(DENY) }, [], enforced(['.*']))?.kind).toBe('blocked')
  expect(classify({ tool: 'CronCreate', result: ok('done') }, [], enforced(['.*']))).toBeUndefined()
})

test('enforcing-other with an unreadable manifest is still blocked', () => {
  const e = enforced(['Edit', 'Write'], { kind: 'enforcing-other', ids: {}, deniedActionClasses: [], manifestUnreadable: true })
  expect(
    classify({ tool: 'Edit', result: err('PersonaKit enforcement could not read its manifest') }, [], e),
  ).toEqual({ tool: 'Edit', kind: 'blocked', actionClass: 'file-mutation', turn: 4 })
})

test('blocked matcher entries are anchored regex alternatives', () => {
  expect(classify({ tool: 'mcp__github__x', result: err(DENY) }, [], enforced())).toEqual({
    tool: 'mcp__github__x', kind: 'blocked', turn: 4,
  })
  expect(classify({ tool: 'mcp__github__x', result: err(DENY) }, [], enforced(['Edit']))).toBeUndefined()
  expect(classify({ tool: 'MultiEdit', result: err(DENY) }, [], enforced(['Edit']))).toBeUndefined()
})

test('deny text outside an installed hook is not drift', () => {
  expect(classify({ tool: 'Bash', result: err(DENY) }, [], advisory)).toBeUndefined()
  expect(classify({ tool: 'Bash', result: ok(DENY) }, [], enforced())).toBeUndefined()
  expect(classify({ tool: 'Bash', result: err(DENY) }, [], enforced(['Edit']))).toBeUndefined()
  expect(classify({ tool: 'Bash', result: err('exit 1') }, [], enforced())).toBeUndefined()
})

test('advisory drift for a mapped tool', () => {
  expect(classify({ tool: 'Write', result: ok() }, ['file-mutation'], advisory)).toEqual({
    tool: 'Write', kind: 'advisory', actionClass: 'file-mutation', turn: 4,
  })
  expect(classify({ tool: 'Read', result: ok() }, ['file-mutation'], advisory)).toBeUndefined()
  expect(classify({ tool: 'Bash', result: ok() }, ['file-mutation'], advisory)).toBeUndefined()
  expect(classify({ tool: 'Write', result: err('nope') }, ['file-mutation'], advisory)).toBeUndefined()
})

test('advisory drift for unclassified MCP tools', () => {
  expect(classify({ tool: 'mcp__github__create_issue', result: ok() }, ['network-egress'], advisory)).toEqual({
    tool: 'mcp__github__create_issue', kind: 'advisory', turn: 4,
  })
  expect(classify({ tool: 'mcp__github__create_issue', result: ok() }, ['something-else'], advisory)).toBeUndefined()
})

test('PersonaKit calls are never drift', () => {
  const tool = 'mcp__personakit__personakit_export'
  expect(classify({ tool, result: ok() }, ['file-mutation'], advisory)).toBeUndefined()
  expect(classify({ tool, result: err(DENY) }, [], enforced())).toEqual({ tool, kind: 'reground-blocked', turn: 4 })
  expect(classify({ tool, result: ok() }, [], enforced())).toBeUndefined()
})

test('no denied classes means no advisory drift', () => {
  expect(classify({ tool: 'Write', result: ok() }, [], advisory)).toBeUndefined()
  expect(classify({ tool: 'mcp__x__y', result: ok() }, [], advisory)).toBeUndefined()
})

test('subagent drift carries agentId', () => {
  expect(classify({ tool: 'Bash', result: ok(), agentId: 'a1' }, ['command-execution'], advisory)).toEqual({
    tool: 'Bash', kind: 'advisory', actionClass: 'command-execution', agentId: 'a1', turn: 4,
  })
})

test('OpenCode: a configured server prefix makes a tool MCP even when a built-in shares its name', () => {
  const host = openCodeHost(['apply'])
  const patch = { input: {}, tool: 'apply_patch', result: ok() }
  // Not file-mutation: `apply` + `patch` is an MCP key, so it is an unclassified MCP tool, as in the Swift evaluator.
  expect(classifyDrift(patch, ['file-mutation'], advisory, trusted, 4, host)).toEqual({ tool: 'apply_patch', kind: 'advisory', turn: 4 })
  expect(classifyDrift(patch, ['command-execution'], advisory, trusted, 4, host)).toEqual({ tool: 'apply_patch', kind: 'advisory', turn: 4 })
  expect(classifyDrift(patch, ['something-else'], advisory, trusted, 4, host)).toBeUndefined()
  // Without that server configured it is the built-in.
  expect(classifyDrift(patch, ['file-mutation'], advisory, trusted, 4, openCodeHost([]))).toEqual({
    tool: 'apply_patch', actionClass: 'file-mutation', kind: 'advisory', turn: 4,
  })
  expect(classifyDrift({ input: {}, tool: 'bash', result: ok() }, ['command-execution'], advisory, trusted, 4, host)?.actionClass).toBe('command-execution')
})

test('tool names that are Object.prototype members are not classified', () => {
  for (const tool of ['constructor', '__proto__', 'toString', 'hasOwnProperty']) {
    expect(classify({ tool, result: ok() }, ['file-mutation', 'command-execution', 'network-egress'], advisory)).toBeUndefined()
    expect(classifyDrift({ input: {}, tool, result: ok() }, ['command-execution'], advisory, trusted, 4, openCodeHost([]))).toBeUndefined()
    // A denied one carries no inherited "class".
    expect(classify({ tool, result: err(DENY) }, [], enforced([tool]))).toEqual({ tool, kind: 'blocked', turn: 4 })
  }
})

test('a manifest whose plugin is not loaded is judged as advisory', () => {
  const missing = enforced(['.*'], { kind: 'enforcing-other', pluginMissing: true })
  expect(classify({ tool: 'Edit', result: ok() }, ['file-mutation'], missing)).toEqual({
    tool: 'Edit', kind: 'advisory', actionClass: 'file-mutation', turn: 4,
  })
  expect(classify({ tool: 'Edit', result: err(DENY) }, ['file-mutation'], missing)).toBeUndefined()
})
