import { expect, test } from 'claude-code/testing'

import type { DriftEvent, Enforcement, Resolution, SessionState } from '../types'
import { parseContract } from './lib/contract'
import { parseExport } from './lib/export'
import { statusText } from './lib/status'
import { CONTRACT_JSON, EXPORT_MD } from './fixtures/golden'

const contract = parseContract(CONTRACT_JSON)!
const details = parseExport(EXPORT_MD)!
const IDS = { sessionId: 'read-only-auditor_audit-pass', personaId: 'read-only-auditor', directiveId: 'audit-pass' }
const STEADY = '◆ read-only-auditor_audit-pass · Read-Only Auditor › Read-only audit pass · project-only'
// The golden line with the directive dropped: what a warning that would pass 120 characters leaves.
const SHORT = '◆ read-only-auditor_audit-pass · Read-Only Auditor · project-only'

const advisory: Enforcement = { kind: 'advisory' }
const hooked = (kind: 'enforced' | 'enforcing-other', ids = IDS, extra: Record<string, unknown> = {}): Enforcement =>
  ({ kind, manifestPath: '/m.json', ids, deniedActionClasses: [], matcherTools: ['Edit'], ...extra }) as Enforcement
const unreadable = hooked('enforcing-other', {} as typeof IDS, { manifestUnreadable: true })

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
  expect(statusText(empty({ enforcement: hooked('enforcing-other', { personaId: 'p' } as typeof IDS) }))).toBe(
    '◇ no contract · ⚠ enforcing p',
  )
})

test('no contract with an unreadable manifest', () => {
  expect(statusText(empty({ enforcement: unreadable }))).toBe('◇ no contract · ⚠ enforcement manifest unreadable')
})

test('golden contract and export, advisory', () => {
  expect(statusText(state())).toBe(`${STEADY} · advisory`)
})

test('golden contract and export, enforced', () => {
  expect(statusText(state({ enforcement: hooked('enforced') }))).toBe(`${STEADY} · enforced`)
})

test('enforcing another contract replaces the steady enforcement segment', () => {
  expect(statusText(state({ enforcement: hooked('enforcing-other', { sessionId: 'other-session' } as typeof IDS) }))).toBe(
    `${STEADY} · ⚠ enforcing other-session`,
  )
  expect(statusText(state({ enforcement: unreadable }))).toBe(`${SHORT} · ⚠ enforcement manifest unreadable`)
})

test('export only drops the scope segment', () => {
  expect(statusText(state({ main: resolution({ contract: undefined }) }))).toBe(
    '◆ read-only-auditor_audit-pass · Read-Only Auditor › Read-only audit pass · advisory',
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
    '◆ p › d · advisory',
  )
})

test('counted compactions append re-ground?', () => {
  expect(statusText(state({ compactions: 1 }))).toBe(`${STEADY} · advisory · ⚠ re-ground?`)
})

test('drift appends the latest event with a count', () => {
  expect(statusText(state({ drift: [write] }))).toBe(`${SHORT} · advisory · ⚠ drift: Write (file-mutation)`)
  const bash: DriftEvent = { tool: 'Bash', actionClass: 'command-execution', kind: 'advisory', turn: 3 }
  expect(statusText(state({ drift: [bash, write] }))).toBe(`${SHORT} · advisory · ⚠ drift: Write (file-mutation) ×2`)
  const mcp: DriftEvent = { tool: 'mcp__x__y', kind: 'advisory', turn: 3 }
  expect(statusText(state({ drift: [mcp] }))).toBe(`${STEADY} · advisory · ⚠ drift: mcp__x__y`)
})

test('drift before the current main resolution is not shown', () => {
  const regrounded = resolution({ turn: 5 })
  expect(statusText(state({ main: regrounded, drift: [write] }))).toBe(`${STEADY} · advisory`)
  const after: DriftEvent = { ...write, turn: 6 }
  expect(statusText(state({ main: regrounded, drift: [write, after] }))).toBe(`${SHORT} · advisory · ⚠ drift: Write (file-mutation)`)
  const sameTurn: DriftEvent = { ...write, turn: 5 }
  expect(statusText(state({ main: regrounded, drift: [sameTurn] }))).toBe(`${SHORT} · advisory · ⚠ drift: Write (file-mutation)`)
})

test('re-ground blocked appends its warning and is not counted as drift', () => {
  const blocked: DriftEvent = { tool: 'mcp__personakit__personakit_export', kind: 'reground-blocked', turn: 2 }
  expect(statusText(state({ enforcement: hooked('enforced'), drift: [blocked] }))).toBe(`${SHORT} · enforced · ⚠ re-ground blocked`)
  const short = resolution({ ids: { sessionId: 's' }, details: undefined })
  expect(statusText(state({ main: short, enforcement: hooked('enforced'), drift: [blocked, { ...write, kind: 'blocked' }], compactions: 2 }))).toBe(
    '◆ s · project-only · enforced · ⚠ re-ground? · ⚠ drift: Write (file-mutation) · ⚠ re-ground blocked',
  )
})

test('never longer than 120 characters: directive first, then persona', () => {
  const long = (n: number) => 'x'.repeat(n)
  const withNames = (sessionId: string, personaName: string, directiveTitle: string) =>
    state({ main: resolution({ ids: { ...IDS, sessionId }, details: { ...details, personaName, directiveTitle } }) })

  const noDirective = statusText(withNames('s', long(40), long(80)))
  expect(noDirective).toBe(`◆ s · ${long(40)} · project-only · advisory`)

  const noPersona = statusText(withNames('s', long(100), long(80)))
  expect(noPersona).toBe('◆ s · project-only · advisory')

  const hardCut = statusText(withNames(long(200), 'P', 'D'))
  expect(hardCut.length).toBe(120)
  expect(hardCut.endsWith('…')).toBe(true)
})
