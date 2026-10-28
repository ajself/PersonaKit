import { expect, test } from 'claude-code/testing'

import { parseLibrary } from './lib/library'
import { LIST_ERRORS_JSON, LIST_JSON, LIST_MERGED_JSON } from './fixtures/golden'

function loaded(stdout: string) {
  const load = parseLibrary(stdout, 0, 'personakit')
  if (load.kind !== 'loaded') throw new Error(`expected loaded, got ${load.kind}`)
  return load.library
}

test('parseLoaded', () => {
  const library = loaded(LIST_JSON)
  expect(library.sessions[0]?.id).toBe('read-only-auditor_audit-pass')
  expect(library.sessions[0]?.scope).toBe('project')
  expect(library.sessions[0]?.personaId).toBe('read-only-auditor')
  expect(library.sessions[0]?.directiveId).toBe('audit-pass')
  expect(library.sessions[0]?.shadows).toBe(null)
  expect(library.sessions[0]?.shadowedPath).toBe(null)
  expect(library.personas[0]?.entity.name).toBe('Read-Only Auditor')
  expect(library.personas[0]?.entity.forbiddenCapabilities).toEqual(['edit-files', 'run-commands', 'network-access'])
  expect(library.directives[0]?.entity.title).toBe('Read-only audit pass')
  expect(library.directives[0]?.entity.steps[1]).toEqual({ text: 'Report confirmed issues before suggestions.', requiresReview: true })
  expect(library.directives[0]?.entity.steps[0]).toEqual({ text: 'Inspect the diff and the surrounding code.' })
  expect(library.kits).toEqual([])
  expect(library.skills).toEqual([])
  expect(library.scopes.project).toBe('<ROOT>')
  expect(library.scopes.global).toBe(undefined)
})

test('parseMergedShadows', () => {
  const library = loaded(LIST_MERGED_JSON)
  const kit = library.kits.find((k) => k.id === 'swift-style')
  expect(kit?.scope).toBe('project')
  expect(kit?.shadows).toBe('global')
  expect(kit?.shadowedPath).toBe('Packs/kits/swift-style.kit.json')
  expect(kit?.entity.skillIds).toEqual(['swift-style-guide-reference'])
  expect(library.scopes).toEqual({ global: '<GLOBAL>', project: '<PROJECT>' })
  expect(library.personas.find((p) => p.id === 'senior-swiftui-engineer')?.scope).toBe('global')
  expect(library.skills.find((s) => s.id === 'codex-cli')?.entity.description).toBe(
    'Edits files and produces PR-sized diffs (outside PersonaKit).',
  )
})

test('parseErrors', () => {
  const load = parseLibrary(LIST_ERRORS_JSON, 1, 'personakit')
  if (load.kind !== 'errors') throw new Error(`expected errors, got ${load.kind}`)
  expect(load.errors).toHaveLength(1)
  expect(load.errors[0]?.entityType).toBe('persona')
  expect(load.errors[0]?.scope).toBe('project')
  expect(load.errors[0]?.path).toBe('Packs/personas/broken.persona.json')
  expect(load.errors[0]?.id).toBe(null)
})

test('parseNoLibrary', () => {
  expect(parseLibrary('{"errors":[],"noLibrary":true}', 0, 'personakit')).toEqual({ kind: 'no-library' })
})

test('parseRejectsNonJSON', () => {
  const load = parseLibrary('Usage: personakit list <kind>', 64, 'personakit')
  if (load.kind !== 'unavailable') throw new Error(`expected unavailable, got ${load.kind}`)
  expect(load.binary).toBe('personakit')
  expect(load.detail).toContain('exit 64')
})

test('parseOldBinaryUsage', () => {
  expect(parseLibrary('', 64, 'personakit').kind).toBe('unavailable')
})

test('parseTruncated', () => {
  const load = parseLibrary(LIST_JSON.slice(0, 100), 0, 'personakit')
  expect(load.kind).toBe('unavailable')
  if (load.kind === 'unavailable') expect(load.binary).toBe('personakit')
})

test('parseMissingArrays', () => {
  const library = loaded('{"scopes":{}}')
  expect(library.scopes).toEqual({})
  expect(library.sessions).toEqual([])
  expect(library.personas).toEqual([])
  expect(library.directives).toEqual([])
  expect(library.kits).toEqual([])
  expect(library.skills).toEqual([])
})

test('parseDropsMalformedRecords', () => {
  const library = loaded(
    JSON.stringify({
      scopes: { project: '/p' },
      kits: [
        { id: 'ok', scope: 'project', path: 'Packs/kits/ok.kit.json', entity: { id: 'ok', name: 'Ok', summary: 's' } },
        { id: 'no-entity', scope: 'project', path: 'x' },
        { id: 'bad-scope', scope: 'nowhere', path: 'x', entity: { id: 'bad-scope', name: 'B', summary: 's' } },
        { id: 'bad-entity', scope: 'global', path: 'x', entity: { id: 'bad-entity', name: 7 } },
        'junk',
      ],
    }),
  )
  expect(library.kits.map((k) => k.id)).toEqual(['ok'])
  expect(library.kits[0]?.shadows).toBe(null)
  expect(library.kits[0]?.shadowedPath).toBe(null)
  expect(library.kits[0]?.entity.skillIds).toBe(undefined)
})

test('parseRejectsNonObjectJSON', () => {
  expect(parseLibrary('[]', 0, 'personakit').kind).toBe('unavailable')
  expect(parseLibrary('null', 0, 'personakit').kind).toBe('unavailable')
})

test('parseRejectsJSONWithoutScopes', () => {
  for (const stdout of ['{}', '{"error":"x"}']) {
    const load = parseLibrary(stdout, 0, 'personakit')
    expect(load.kind).toBe('unavailable')
    if (load.kind === 'unavailable') expect(load.binary).toBe('personakit')
  }
})
