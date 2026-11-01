import { expect, test } from 'bun:test'
import { installedPluginDirectory, openCodeEnforcement, pluginListed } from '../src/tui/enforcement'
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

const ENV = { HOME: '/Users/me' }
const SPEC = 'file:///Users/me/.cache/opencode/personakit/plugin'
const noHome = () => ''
const listed = (plugins: Parameters<typeof pluginListed>[0], env: Record<string, string | undefined> = ENV) =>
  pluginListed(plugins, env, noHome)

test('installedPluginDirectoryFollowsTheCacheHome', () => {
  expect(installedPluginDirectory(ENV, noHome)).toBe('/Users/me/.cache/opencode/personakit/plugin')
  expect(installedPluginDirectory({ HOME: '/Users/me', XDG_CACHE_HOME: '/c' }, noHome)).toBe('/c/opencode/personakit/plugin')
  expect(installedPluginDirectory({ HOME: '/Users/me', XDG_CACHE_HOME: '' }, noHome)).toBe('/Users/me/.cache/opencode/personakit/plugin')
  expect(installedPluginDirectory({ XDG_CACHE_HOME: '/c/x/../y/' }, noHome)).toBe('/c/y/opencode/personakit/plugin')
  expect(installedPluginDirectory({ HOME: '' }, () => '/Users/acct')).toBe('/Users/acct/.cache/opencode/personakit/plugin')
  expect(installedPluginDirectory({}, noHome)).toBeUndefined()
})

test('pluginListedMatchesOnlyTheInstalledSpec', () => {
  expect(listed([SPEC])).toBe(true)
  expect(listed([[SPEC, { personakitPath: '/x' }]])).toBe(true)
  expect(listed(['other', SPEC])).toBe(true)
  expect(listed(['file:///c/opencode/personakit/plugin'], { HOME: '/Users/me', XDG_CACHE_HOME: '/c' })).toBe(true)
  // The cache home moved, so the listed spec is no longer the installed plugin.
  expect(listed([SPEC], { HOME: '/Users/me', XDG_CACHE_HOME: '/c' })).toBe(false)
})

test('pluginListedRejectsEveryOtherSpec', () => {
  for (const spec of [
    'opencode-personakit',
    'opencode-personakit@2.1.0',
    'opencode-personakit@latest',
    '@scope/opencode-personakit',
    'file:///Users/me/Code/PersonaKit/Integrations/OpenCode',
    `${SPEC}/`,
    `${SPEC}/Integrations/OpenCode/src/server.ts`,
    `${SPEC}-evil`,
    'file:///Users/me/.cache/opencode/personakit/plugin/../plugin',
    'file://localhost/Users/me/.cache/opencode/personakit/plugin',
    'FILE:///Users/me/.cache/opencode/personakit/plugin',
    '/Users/me/.cache/opencode/personakit/plugin',
    'file:///users/me/.cache/opencode/personakit/plugin',
    ` ${SPEC}`,
    `${SPEC}\n`,
  ])
    expect(listed([spec])).toBe(false)
  expect(listed([['opencode-personakit', {}]])).toBe(false)
  expect(listed([])).toBe(false)
  expect(listed(undefined)).toBe(false)
  // No home and no cache home: nothing can be the installed plugin.
  expect(pluginListed(['file://undefined/opencode/personakit/plugin', SPEC], {}, noHome)).toBe(false)
})

test('pluginListedToleratesMalformedEntries', () => {
  expect(listed([[] as never, 3 as never, null as never, [3, SPEC] as never, [[SPEC]] as never])).toBe(false)
})

test('sanitizeTextStripsEscapes', () => {
  expect(sanitizeText('a\u001b[2Jb')).toBe('a[2Jb')
  expect(sanitizeText('a\tb\nc')).toBe('a\tb\nc')
  expect(sanitizeText('a\rb\u0000c\u007fd\u009be\u0085f')).toBe('abcdef')
})

test('sanitizeTextStripsBidiControls', () => {
  expect(sanitizeText('a\u202ab\u202bc\u202cd\u202de\u202ef')).toBe('abcdef')
  expect(sanitizeText('a\u2066b\u2067c\u2068d\u2069e\u200ef\u200fg\u061ch')).toBe('abcdefgh')
  expect(sanitizeText('line one\nline two')).toBe('line one\nline two')
})

test('sanitizeLineStripsEverythingThatMovesOrHidesText', () => {
  expect(sanitizeLine('a\u001b[2Jb')).toBe('a[2Jb')
  expect(sanitizeLine('a\nb\tc\rd')).toBe('abcd')
  expect(sanitizeLine('a\u2028b\u2029c')).toBe('abc')
  expect(sanitizeLine('a\u202ab\u202ec\u2066d\u2069e\u200ef\u200fg\u061ch')).toBe('abcdefgh')
  expect(sanitizeLine('a\u200bb\u200cc\u200dd\u2060e\ufefff')).toBe('abcdef')
  expect(sanitizeLine('plain text 1.2 é')).toBe('plain text 1.2 é')
})

test('sanitizeLineStripsInvisibleFillersAndTags', () => {
  expect(sanitizeLine('a\u00adb\u180ec\u2061d\u2062e\u2063f\u2064g')).toBe('abcdefg')
  expect(sanitizeLine('a\u3164b\u115fc\u1160d')).toBe('abcd')
  expect(sanitizeLine('a\ufe00b\ufe0fc')).toBe('abc')
  expect(sanitizeLine('a\u{E0000}b\u{E0041}c\u{E007F}d')).toBe('abcd')
  // Neighbours of the stripped ranges stay.
  expect(sanitizeLine('\u{E0080}\ufe10\u2060x\u2065')).toBe('\u{E0080}\ufe10x\u2065')
  expect(sanitizeLine('emoji 👍 ok')).toBe('emoji 👍 ok')
})
