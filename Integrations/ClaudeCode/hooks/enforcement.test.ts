import { expect, test } from 'claude-code/testing'

import { enforcementFor, installedHook, sameContract, unquotePOSIX } from './lib/enforcement'

const COMMAND = `'/usr/local/bin/personakit' hook-check --manifest '/p/.claude/personakit/it'\\''s.checks.json'`
const MATCHER = 'Edit|Write|NotebookEdit|Bash|mcp__.*'
const settings = (command: string, matcher = MATCHER) =>
  JSON.stringify({ hooks: { PreToolUse: [{ matcher, hooks: [{ type: 'command', command }] }] } })

const manifest = (extra: Record<string, unknown> = {}) =>
  JSON.stringify({
    sessionId: 's1',
    personaId: 'p1',
    directiveId: 'd1',
    checks: [
      { id: 'a', maxClass: 'hook', rule: { kind: 'capability-deny', deniedActionClasses: ['network-egress', 'file-mutation'] } },
      { id: 'b', maxClass: 'hook', rule: { kind: 'capability-deny', deniedActionClasses: ['file-mutation'] } },
      { id: 'c', maxClass: 'command', rule: { kind: 'command', command: 'make test' } },
      { id: 'd', maxClass: 'review', rule: { kind: 'review', criterion: 'x' } },
    ],
    ...extra,
  })

const hook = { manifestPath: '/m.json', matcherTools: ['Edit', 'Bash'] }

test('sameContract matches by sessionId', () => {
  expect(sameContract({ sessionId: 'a', personaId: 'x' }, { sessionId: 'a', personaId: 'y' })).toBe(true)
})

test('sameContract differs when both have different sessionIds', () => {
  expect(sameContract({ sessionId: 'a', personaId: 'x', directiveId: 'd' }, { sessionId: 'b', personaId: 'x', directiveId: 'd' })).toBe(false)
})

test('sameContract falls back to persona and directive', () => {
  expect(sameContract({ personaId: 'x', directiveId: 'd' }, { personaId: 'x', directiveId: 'd' })).toBe(true)
  expect(sameContract({ personaId: 'x', directiveId: 'd' }, { personaId: 'x', directiveId: 'e' })).toBe(false)
  expect(sameContract({ sessionId: 'a', personaId: 'x', directiveId: 'd' }, { personaId: 'x', directiveId: 'd' })).toBe(true)
})

test('unquotePOSIX handles single quotes and escaped quotes', () => {
  expect(unquotePOSIX(`'a b'`)).toBe('a b')
  expect(unquotePOSIX(`'it'\\''s'`)).toBe("it's")
  expect(unquotePOSIX('plain')).toBe('plain')
})

test('finds the PersonaKit hook, unquotes its path, splits its matcher', () => {
  const h = installedHook(settings(COMMAND))
  expect(h?.manifestPath).toBe("/p/.claude/personakit/it's.checks.json")
  expect(h?.matcherTools).toEqual(['Edit', 'Write', 'NotebookEdit', 'Bash', 'mcp__.*'])
})

test('ignores foreign hooks containing hook-check', () => {
  expect(installedHook(settings('run-hook-check-lint'))).toBeUndefined()
})

test('missing, unreadable, or invalid settings are advisory', () => {
  for (const s of [undefined, '', '{', '[]', 'null', '{"hooks":{"PreToolUse":"x"}}']) {
    expect(installedHook(s)).toBeUndefined()
    expect(enforcementFor({ sessionId: 's1' }, installedHook(s), manifest())).toEqual({ kind: 'advisory' })
  }
})

test('a hook with a missing or invalid manifest is enforcing-other and unreadable', () => {
  const expected = {
    kind: 'enforcing-other',
    manifestPath: '/m.json',
    ids: {},
    deniedActionClasses: [],
    matcherTools: ['Edit', 'Bash'],
    manifestUnreadable: true,
  }
  for (const m of [undefined, '{', '[]']) expect(enforcementFor({ sessionId: 's1' }, hook, m)).toEqual(expected)
})

test('matching contract is enforced with hook-class denied action classes', () => {
  expect(enforcementFor({ sessionId: 's1' }, hook, manifest())).toEqual({
    kind: 'enforced',
    manifestPath: '/m.json',
    ids: { sessionId: 's1', personaId: 'p1', directiveId: 'd1' },
    deniedActionClasses: ['file-mutation', 'network-egress'],
    matcherTools: ['Edit', 'Bash'],
  })
})

test('persona-only contract matches by persona and directive', () => {
  const m = manifest({ sessionId: undefined })
  expect(enforcementFor({ personaId: 'p1', directiveId: 'd1' }, hook, m)?.kind).toBe('enforced')
})

test('different contract is enforcing-other', () => {
  expect(enforcementFor({ sessionId: 'other' }, hook, manifest()).kind).toBe('enforcing-other')
})

test('no resolved contract with an installed hook is enforcing-other', () => {
  expect(enforcementFor(undefined, hook, manifest()).kind).toBe('enforcing-other')
})

test('recorded mcpServerName is carried', () => {
  const e = enforcementFor({ sessionId: 's1' }, hook, manifest({ mcpServerName: 'pk' }))
  expect(e.kind === 'enforced' && e.mcpServerName).toBe('pk')
})
