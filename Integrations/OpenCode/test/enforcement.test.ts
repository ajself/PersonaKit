import { expect, test } from 'bun:test'
import { openCodeEnforcement, pluginListed } from '../src/tui/enforcement'
import { sanitizeLine, sanitizeText } from '../src/tui/text'

const SOLO = { sessionId: 'solo-dev' }
const manifest = (body: unknown = { sessionId: 'solo-dev', checks: [] }) => ({
  path: '/w/.opencode/personakit/solo-dev.checks.json',
  text: JSON.stringify(body),
})

test('noManifestIsAdvisory', () => {
  expect(openCodeEnforcement(SOLO, undefined, true)).toEqual({ kind: 'advisory' })
  expect(openCodeEnforcement(SOLO, undefined, false)).toEqual({ kind: 'advisory' })
})

test('enforcedWhenListedAndSameContract', () => {
  const e = openCodeEnforcement(SOLO, manifest(), true)
  expect(e).toEqual({
    kind: 'enforced',
    manifestPath: '/w/.opencode/personakit/solo-dev.checks.json',
    ids: SOLO,
    deniedActionClasses: [],
    matcherTools: ['.*'],
  })
})

test('enforcingOtherWhenContractDiffers', () => {
  const e = openCodeEnforcement({ sessionId: 'other' }, manifest(), true)
  expect(e.kind).toBe('enforcing-other')
  expect(e.kind === 'advisory' ? undefined : e.pluginMissing).toBeUndefined()
})

test('enforcingOtherWhenNothingResolved', () => {
  expect(openCodeEnforcement(undefined, manifest(), true).kind).toBe('enforcing-other')
})

test('deniedClassesAndMcpServerReadFromManifest', () => {
  const e = openCodeEnforcement(
    SOLO,
    manifest({
      sessionId: 'solo-dev',
      mcpServerName: 'pk',
      checks: [{ maxClass: 'hook', rule: { deniedActionClasses: ['network-egress', 'file-mutation'] } }],
    }),
    true,
  )
  expect(e.kind === 'advisory' ? undefined : e.deniedActionClasses).toEqual(['file-mutation', 'network-egress'])
  expect(e.kind === 'advisory' ? undefined : e.mcpServerName).toBe('pk')
})

test('pluginMissingWhenNotListed', () => {
  const e = openCodeEnforcement(SOLO, manifest(), false)
  expect(e.kind).not.toBe('enforced')
  expect(e.kind === 'advisory' ? undefined : e.pluginMissing).toBe(true)
})

test('pluginMissingWhenNotListedAndUnreadable', () => {
  const e = openCodeEnforcement(SOLO, { path: '/m', text: undefined }, false)
  expect(e.kind === 'advisory' ? undefined : e.pluginMissing).toBe(true)
  expect(e.kind === 'advisory' ? undefined : e.manifestUnreadable).toBe(true)
})

test('manyManifestsNeverEnforced', () => {
  const paths = ['/b/.opencode/personakit/b.checks.json', '/a/.opencode/personakit/a.checks.json'].sort()
  const e = openCodeEnforcement(SOLO, { path: paths.join(', '), text: undefined }, true)
  expect(e.kind).toBe('enforcing-other')
  expect(e.kind === 'advisory' ? undefined : e.manifestUnreadable).toBe(true)
  expect(e.kind === 'advisory' ? undefined : e.manifestPath).toBe(paths.join(', '))
})

test('unparseableManifestNeverEnforced', () => {
  for (const text of ['{ not json', '[]', 'null', '"s"', '']) {
    const e = openCodeEnforcement(SOLO, { path: '/m', text }, true)
    expect(e.kind).toBe('enforcing-other')
    expect(e.kind === 'advisory' ? undefined : e.manifestUnreadable).toBe(true)
  }
})

test('pluginListedMatchesOnlyThePackageSpec', () => {
  expect(pluginListed(['opencode-personakit'])).toBe(true)
  expect(pluginListed(['opencode-personakit@2.1.0'])).toBe(true)
  expect(pluginListed(['opencode-personakit@latest'])).toBe(true)
  expect(pluginListed([['opencode-personakit', { x: 1 }]])).toBe(true)
  expect(pluginListed([['opencode-personakit@2.1.0', {}]])).toBe(true)
  expect(pluginListed(['other', 'opencode-personakit'])).toBe(true)
})

test('pluginListedRejectsLookalikes', () => {
  expect(pluginListed(['opencode-personakit-evil'])).toBe(false)
  expect(pluginListed(['opencode-personakit-evil@1.0.0'])).toBe(false)
  expect(pluginListed(['xopencode-personakit'])).toBe(false)
  expect(pluginListed(['@scope/opencode-personakit'])).toBe(false)
  expect(pluginListed(['file:///Users/me/opencode-personakit'])).toBe(false)
  expect(pluginListed(['file:///x/opencode-personakit/src/server.ts'])).toBe(false)
  expect(pluginListed([['opencode-personakit-evil', {}]])).toBe(false)
  expect(pluginListed([])).toBe(false)
  expect(pluginListed(undefined)).toBe(false)
})

test('pluginListedToleratesMalformedEntries', () => {
  expect(pluginListed([[] as never, 3 as never, null as never, [3, 'opencode-personakit'] as never])).toBe(false)
})

test('sanitizeTextStripsEscapes', () => {
  expect(sanitizeText('a\u001b[2Jb')).toBe('a[2Jb')
  expect(sanitizeText('a\tb\nc')).toBe('a\tb\nc')
  expect(sanitizeText('a\rb\u0000c\u007fd\u009be\u0085f')).toBe('abcdef')
})

test('pluginListedAcceptsOnlyVersionOrTagAfterTheAt', () => {
  for (const spec of ['@2.1.0', '@latest', '@2.1.0-beta.1', '@1.0.0+build_5'])
    expect(pluginListed([`opencode-personakit${spec}`])).toBe(true)
  for (const spec of ['@', '@npm:evil@1.0.0', '@file:../x', '@github:a/b', '@https://x/y.tgz', '@-x', '@a b', '@a/b', '@2.1.0\n'])
    expect(pluginListed([`opencode-personakit${spec}`])).toBe(false)
})

test('sanitizeLineStripsEverythingThatMovesOrHidesText', () => {
  expect(sanitizeLine('a\u001b[2Jb')).toBe('a[2Jb')
  expect(sanitizeLine('a\nb\tc\rd')).toBe('abcd')
  expect(sanitizeLine('a\u2028b\u2029c')).toBe('abc')
  expect(sanitizeLine('a\u202ab\u202ec\u2066d\u2069e\u200ef\u200fg\u061ch')).toBe('abcdefgh')
  expect(sanitizeLine('a\u200bb\u200cc\u200dd\u2060e\ufefff')).toBe('abcdef')
  expect(sanitizeLine('plain text 1.2 é')).toBe('plain text 1.2 é')
})
