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

  const hardCut = statusText(withNames(long(200), 'P', 'D'))
  expect(hardCut.length).toBe(120)
  expect(hardCut.endsWith('…')).toBe(true)
})
