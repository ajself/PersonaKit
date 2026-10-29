import { expect, test } from 'claude-code/testing'

import type { ContractIds, DriftEvent, Enforcement, Resolution, SessionState } from '../types'
import { parseContract } from './lib/contract'
import { parseExport } from './lib/export'
import { statusText } from './lib/status'
import { CONTRACT_JSON, EXPORT_MD } from './fixtures/golden'

const contract = parseContract(CONTRACT_JSON)!
const details = parseExport(EXPORT_MD)!
const IDS = { sessionId: 'read-only-auditor_audit-pass', personaId: 'read-only-auditor', directiveId: 'audit-pass' }
const LEAD = '◆ read-only-auditor_audit-pass'
const NAMES = 'Read-Only Auditor › Read-only audit pass'
// What a warning that would pass 120 characters leaves: the directive dropped from the end.
const PERSONA = 'Read-Only Auditor'

const advisory: Enforcement = { kind: 'advisory' }
const hooked = (kind: 'enforced' | 'enforcing-other', ids: ContractIds = IDS, extra: Record<string, unknown> = {}): Enforcement =>
  ({ kind, manifestPath: '/m.json', ids, deniedActionClasses: [], matcherTools: ['Edit'], ...extra }) as Enforcement
const unreadable = hooked('enforcing-other', {}, { manifestUnreadable: true })

const resolution = (extra: Partial<Resolution> = {}): Resolution => ({ ids: IDS, contract, details, source: 'mcp', turn: 1, ...extra })
const state = (extra: Partial<SessionState> = {}): SessionState => ({
  main: resolution(), subagents: {}, enforcement: advisory, compactions: 0, drift: [], turn: 1, ...extra,
})
const empty = (extra: Partial<SessionState> = {}) => state({ main: undefined, ...extra })
const write: DriftEvent = { tool: 'Write', actionClass: 'file-mutation', kind: 'advisory', turn: 2 }

test('no contract, advisory', () => {
  expect(statusText(empty())).toBe('◇ no contract · /pk use <session>')
})

test('no contract while another contract is enforced', () => {
  expect(statusText(empty({ enforcement: hooked('enforcing-other', { sessionId: 'other-session', personaId: 'p' }) }))).toBe(
    '◇ no contract · ⚠ enforcing other-session',
  )
  expect(statusText(empty({ enforcement: hooked('enforcing-other', { personaId: 'p' }) }))).toBe(
    '◇ no contract · ⚠ enforcing p',
  )
})

test('no contract with an unreadable manifest', () => {
  expect(statusText(empty({ enforcement: unreadable }))).toBe('◇ no contract · ⚠ enforcement manifest unreadable')
})

test('golden contract and export, advisory', () => {
  expect(statusText(state())).toBe(`${LEAD} · advisory · project-only · ${NAMES}`)
})

test('golden contract and export, enforced', () => {
  expect(statusText(state({ enforcement: hooked('enforced') }))).toBe(`${LEAD} · enforced · project-only · ${NAMES}`)
})

test('enforcing another contract replaces the steady enforcement segment', () => {
  expect(statusText(state({ enforcement: hooked('enforcing-other', { sessionId: 'other-session' }) }))).toBe(
    `${LEAD} · ⚠ enforcing other-session · project-only · ${NAMES}`,
  )
  expect(statusText(state({ enforcement: unreadable }))).toBe(`${LEAD} · ⚠ enforcement manifest unreadable · project-only · ${PERSONA}`)
})

test('export only drops the scope segment', () => {
  expect(statusText(state({ main: resolution({ contract: undefined }) }))).toBe(
    `${LEAD} · advisory · ${NAMES}`,
  )
})

test('persona-only ids lead with the persona name or id', () => {
  const ids = { personaId: 'read-only-auditor' }
  expect(statusText(state({ main: resolution({ ids, contract: undefined, details: { ...details, directiveId: undefined, directiveTitle: undefined } }) }))).toBe(
    '◆ Read-Only Auditor · advisory',
  )
  expect(statusText(state({ main: resolution({ ids, contract: undefined, details: undefined }) }))).toBe(
    '◆ read-only-auditor · advisory',
  )
  expect(statusText(state({ main: resolution({ ids: { personaId: 'p', directiveId: 'd' }, contract: undefined, details: undefined }) }))).toBe(
    '◆ p · advisory · d',
  )
})

test('a persona lead too long for the line shrinks to its id', () => {
  const ids = { personaId: 'p', directiveId: 'd' }
  const named = { ...details, personaName: 'P'.repeat(130) }
  expect(statusText(state({ main: resolution({ ids, contract: undefined, details: named }) }))).toBe('◆ p · advisory')
})

test('counted compactions append re-ground?', () => {
  expect(statusText(state({ compactions: 1 }))).toBe(`${LEAD} · ⚠ re-ground? · advisory · project-only · ${NAMES}`)
})

test('drift appends the latest event with a count', () => {
  expect(statusText(state({ drift: [write] }))).toBe(`${LEAD} · ⚠ drift: Write (file-mutation) · advisory · project-only · ${PERSONA}`)
  const bash: DriftEvent = { tool: 'Bash', actionClass: 'command-execution', kind: 'advisory', turn: 3 }
  expect(statusText(state({ drift: [bash, write] }))).toBe(`${LEAD} · ⚠ drift: Write (file-mutation) ×2 · advisory · project-only · ${PERSONA}`)
  const mcp: DriftEvent = { tool: 'mcp__x__y', kind: 'advisory', turn: 3 }
  expect(statusText(state({ drift: [mcp] }))).toBe(`${LEAD} · ⚠ drift: mcp__x__y · advisory · project-only · ${NAMES}`)
})

test('drift before the current main resolution is not shown', () => {
  const regrounded = resolution({ turn: 5, driftMark: 1 })
  expect(statusText(state({ main: regrounded, drift: [write] }))).toBe(`${LEAD} · advisory · project-only · ${NAMES}`)
  const after: DriftEvent = { ...write, turn: 6 }
  expect(statusText(state({ main: regrounded, drift: [write, after] }))).toBe(`${LEAD} · ⚠ drift: Write (file-mutation) · advisory · project-only · ${PERSONA}`)
  const sameTurn: DriftEvent = { ...write, turn: 5 }
  expect(statusText(state({ main: regrounded, drift: [write, sameTurn] }))).toBe(`${LEAD} · ⚠ drift: Write (file-mutation) · advisory · project-only · ${PERSONA}`)
})

test('drift earlier in the resolve\'s own turn is not shown; drift after it is', () => {
  const before: DriftEvent = { ...write, turn: 5 }
  const regrounded = resolution({ turn: 5, driftMark: 1 })
  expect(statusText(state({ main: regrounded, drift: [before] }))).toBe(`${LEAD} · advisory · project-only · ${NAMES}`)
  expect(statusText(state({ main: regrounded, drift: [before, { ...before }] }))).toBe(
    `${LEAD} · ⚠ drift: Write (file-mutation) · advisory · project-only · ${PERSONA}`,
  )
})

test('re-ground blocked earlier in the resolve\'s own turn is not shown; one after it is', () => {
  const blocked: DriftEvent = { tool: 'Bash', kind: 'reground-blocked', turn: 5 }
  const regrounded = resolution({ turn: 5, driftMark: 1 })
  expect(statusText(state({ main: regrounded, enforcement: hooked('enforced'), drift: [blocked] }))).toBe(
    `${LEAD} · enforced · project-only · ${NAMES}`,
  )
  expect(statusText(state({ main: regrounded, enforcement: hooked('enforced'), drift: [blocked, { ...blocked }] }))).toBe(
    `${LEAD} · ⚠ re-ground blocked · enforced · project-only · ${PERSONA}`,
  )
})

test('a resolution without a mark counts all drift; no contract counts all drift', () => {
  const old: DriftEvent = { ...write, turn: 0 }
  expect(statusText(state({ main: resolution({ turn: 5 }), drift: [old] }))).toBe(
    `${LEAD} · ⚠ drift: Write (file-mutation) · advisory · project-only · ${PERSONA}`,
  )
  expect(statusText(empty({ drift: [old] }))).toBe('◇ no contract · /pk use <session> · ⚠ drift: Write (file-mutation)')
})

test('re-ground blocked appends its warning and is not counted as drift', () => {
  const blocked: DriftEvent = { tool: 'mcp__personakit__personakit_export', kind: 'reground-blocked', turn: 2 }
  expect(statusText(state({ enforcement: hooked('enforced'), drift: [blocked] }))).toBe(`${LEAD} · ⚠ re-ground blocked · enforced · project-only · ${PERSONA}`)
  const short = resolution({ ids: { sessionId: 's' }, details: undefined })
  expect(statusText(state({ main: short, enforcement: hooked('enforced'), drift: [blocked, { ...write, kind: 'blocked' }], compactions: 2 }))).toBe(
    '◆ s · ⚠ re-ground? · ⚠ drift: Write (file-mutation) · ⚠ re-ground blocked · enforced · project-only',
  )
})

test('never longer than 120 characters: directive first, then persona', () => {
  const long = (n: number) => 'x'.repeat(n)
  const withNames = (sessionId: string, personaName: string, directiveTitle: string) =>
    state({ main: resolution({ ids: { ...IDS, sessionId }, details: { ...details, personaName, directiveTitle } }) })

  const noDirective = statusText(withNames('s', long(40), long(80)))
  expect(noDirective).toBe(`◆ s · advisory · project-only · ${long(40)}`)

  const noPersona = statusText(withNames('s', long(100), long(80)))
  expect(noPersona).toBe('◆ s · advisory · project-only')

  // A lead that cannot fit is ellipsized to its budget before the hard cut, so what follows it stays visible.
  expect(statusText(withNames(long(200), 'P', 'D'))).toBe(`◆ ${long(31)}… · advisory · project-only`)
})

test('a missing plugin leads the enforcement segment with its warning', () => {
  const missing = hooked('enforced', IDS, { pluginMissing: true })
  expect(statusText(empty({ enforcement: missing }))).toBe('◇ no contract · ⚠ manifest present · plugin not loaded')
  expect(statusText(state({ enforcement: missing }))).toBe(`${LEAD} · ⚠ manifest present · plugin not loaded · project-only · ${PERSONA}`)
  expect(statusText(state({ enforcement: hooked('enforced', IDS, { pluginMissing: true, manifestUnreadable: true }) }))).toContain('⚠ manifest present · plugin not loaded')
})

const LONG_IDS = ['solo-dev.enforced' + '.'.repeat(110), 'enforced_' + '_'.repeat(115), 'solo-dev-' + 'x'.repeat(200)]

test('a long observed id is ellipsized, so the enforcement segment stays visible', () => {
  const segments: [Enforcement, string][] = [
    [advisory, 'advisory'],
    [hooked('enforced', IDS, { pluginMissing: true }), '⚠ manifest present · plugin not loaded'],
    [hooked('enforcing-other', { sessionId: 'other' }), '⚠ enforcing other'],
    [hooked('enforced', IDS), 'enforced'],
  ]
  for (const [enforcement, segment] of segments) {
    for (const sessionId of LONG_IDS) {
      const text = statusText(state({ main: resolution({ ids: { sessionId } }), enforcement }))
      expect(text.length).toBeLessThanOrEqual(120)
      expect(text.split(' · ')).toContain(segment.split(' · ')[0])
      expect(text).toContain(segment)
      expect(text.split(' · ')[0]).toBe(`◆ ${sessionId.slice(0, 31)}…`)
    }
  }
})

test('a long persona that leads, a long enforced id and a long tool name are ellipsized', () => {
  const long = 'N'.repeat(300)
  const text = statusText(
    state({
      main: resolution({ ids: {}, details: { personaName: long, steps: [], deniedActionClasses: [] } }),
      enforcement: hooked('enforcing-other', { sessionId: long }),
      drift: [{ tool: long, kind: 'blocked', turn: 1 }],
    }),
  )
  expect(text.length).toBe(120)
  expect(text.startsWith(`◆ ${'N'.repeat(31)}… · ⚠ enforcing ${'N'.repeat(31)}… · ⚠ drift: ${'N'.repeat(23)}…`)).toBe(true)
  // while the line fits, observed text is shown whole
  expect(statusText(state({ main: resolution({ ids: { sessionId: 'a'.repeat(50) } }), drift: [{ tool: 'T'.repeat(30), kind: 'blocked', turn: 1 }] }))).toBe(
    `◆ ${'a'.repeat(50)} · ⚠ drift: ${'T'.repeat(30)} · advisory · project-only`,
  )
  expect(statusText(empty({ enforcement: hooked('enforcing-other', { sessionId: long }) }))).toBe(
    `◇ no contract · ⚠ enforcing ${'N'.repeat(31)}…`,
  )
})

test('an id of exactly 32 characters is shown whole', () => {
  const id = 'a'.repeat(32)
  expect(statusText(state({ main: resolution({ ids: { sessionId: id } }) })).startsWith(`◆ ${id} · advisory`)).toBe(true)
})

// The segment stands whole between separators (it always follows the lead, so it is never first).
const showsSegment = (text: string, segment: string) => `${text} · `.includes(` · ${segment} · `)
const PLUGIN_MISSING = '⚠ manifest present · plugin not loaded'
const patch = (kind: DriftEvent['kind']): DriftEvent => ({ tool: 'apply_patch', actionClass: 'file-mutation', kind, turn: 1 })
const regroundBlocked: DriftEvent = { tool: 'bash', kind: 'reground-blocked', turn: 1 }

test('a missing plugin stays visible behind a session id, re-ground? and one advisory drift', () => {
  const sessionId = 'read-only-auditor_audit-pass'
  const text = statusText(
    state({
      main: resolution({ ids: { sessionId } }),
      enforcement: hooked('enforcing-other', { sessionId }, { pluginMissing: true }),
      compactions: 1,
      drift: [patch('advisory')],
    }),
  )
  expect(text.length).toBeLessThanOrEqual(120)
  expect(showsSegment(text, PLUGIN_MISSING)).toBe(true)
  expect(text.startsWith(`${LEAD} · ${PLUGIN_MISSING} · `)).toBe(true)
})

test('an unreadable manifest stays visible behind a 32-character lead and every blocked warning', () => {
  const text = statusText(
    state({
      main: resolution({ ids: { sessionId: 'a'.repeat(32) } }),
      enforcement: unreadable,
      compactions: 1,
      drift: [patch('blocked'), regroundBlocked],
    }),
  )
  expect(text.length).toBeLessThanOrEqual(120)
  expect(showsSegment(text, '⚠ enforcement manifest unreadable')).toBe(true)
})

test('enforcing another contract stays visible behind a long lead and all three warnings', () => {
  for (const n of [25, 28, 32, 40]) {
    const text = statusText(
      state({
        main: resolution({ ids: { sessionId: 'a'.repeat(n) } }),
        enforcement: hooked('enforcing-other', { sessionId: 'other' }),
        compactions: 1,
        drift: [patch('blocked'), regroundBlocked],
      }),
    )
    expect(text.length).toBeLessThanOrEqual(120)
    expect(showsSegment(text, '⚠ enforcing other')).toBe(true)
  }
})

test('the enforcement segment is visible for every lead length and combination of warnings', () => {
  const states: [Enforcement, string][] = [
    [advisory, 'advisory'],
    [hooked('enforcing-other', { sessionId: 'solo-dev' }, { pluginMissing: true }), PLUGIN_MISSING],
    [unreadable, '⚠ enforcement manifest unreadable'],
    [hooked('enforcing-other', { sessionId: 'other-session' }), '⚠ enforcing other-session'],
    [hooked('enforcing-other', { sessionId: 'o'.repeat(200) }), `⚠ enforcing ${'o'.repeat(31)}…`],
  ]
  const tools = [
    (kind: DriftEvent['kind']) => patch(kind),
    (kind: DriftEvent['kind']): DriftEvent => ({ tool: `x_${'y'.repeat(200)}`, kind, turn: 1 }),
  ]
  let checked = 0
  for (const [enforcement, segment] of states) {
    for (let n = 1; n <= 40; n++) {
      for (let count = 0; count <= 12; count++) {
        for (const compactions of [0, 1]) {
          for (const blocked of [false, true]) {
            for (const reground of [false, true]) {
              for (const tool of tools) {
                const drift = [...Array.from({ length: count }, () => tool(blocked ? 'blocked' : 'advisory')), ...(reground ? [regroundBlocked] : [])]
                const text = statusText(state({ main: resolution({ ids: { sessionId: 'a'.repeat(n) } }), enforcement, compactions, drift }))
                if (text.length > 120 || !showsSegment(text, segment)) {
                  throw new Error(`segment ${JSON.stringify(segment)} not visible (lead ${n}, drift ${count}, compactions ${compactions}, blocked ${blocked}, reground ${reground}): ${JSON.stringify(text)}`)
                }
                checked++
              }
            }
          }
        }
      }
    }
  }
  expect(checked).toBe(5 * 40 * 13 * 2 * 2 * 2 * 2)
})
