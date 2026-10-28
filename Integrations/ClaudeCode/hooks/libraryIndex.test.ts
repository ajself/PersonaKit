import { expect, test } from 'claude-code/testing'

import type { Library, LibrarySession, Scope } from '../types'
import { filterLibrary, people, usedBy } from './lib/libraryIndex'

const prov = (id: string, scope: Scope = 'global', shadows: Scope | null = null) => ({
  id,
  scope,
  path: `${id}.json`,
  shadows,
  shadowedPath: null,
})

const persona = (id: string, name: string, extra: { defaultKitIds?: string[]; allowedSkillIds?: string[] } = {}, scope: Scope = 'global') => ({
  ...prov(id, scope),
  entity: {
    id,
    name,
    summary: '',
    responsibilities: [],
    values: [],
    nonGoals: [],
    defaultKitIds: extra.defaultKitIds ?? [],
    allowedSkillIds: extra.allowedSkillIds ?? [],
    forbiddenSkillIds: [],
  },
})

const directive = (id: string, title: string, scope: Scope = 'global') => ({
  ...prov(id, scope),
  entity: { id, title, goal: '', steps: [], acceptanceCriteria: [], requiresSkillIds: [] },
})

const kit = (id: string, name: string, skillIds: string[] = [], scope: Scope = 'global') => ({
  ...prov(id, scope),
  entity: { id, name, summary: '', skillIds },
})

const skill = (id: string, name: string, scope: Scope = 'global') => ({
  ...prov(id, scope),
  entity: { id, name, description: '' },
})

const session = (id: string, personaId: string, directiveId: string, kitOverrides: string[] = [], scope: Scope = 'global'): LibrarySession => ({
  ...prov(id, scope),
  personaId,
  directiveId,
  kitOverrides,
})

const library = (parts: Partial<Library>): Library => ({
  scopes: {},
  sessions: [],
  personas: [],
  directives: [],
  kits: [],
  skills: [],
  ...parts,
})

test('peopleGroupsSessionsUnderPersona', () => {
  const rows = people(
    library({
      personas: [persona('pm', 'Product Manager')],
      directives: [directive('plan', 'Plan the release'), directive('triage', 'Triage issues')],
      sessions: [session('pm_triage', 'pm', 'triage'), session('pm_plan', 'pm', 'plan')],
    }),
  )
  expect(rows).toHaveLength(1)
  expect(rows[0]?.personaId).toBe('pm')
  expect(rows[0]?.name).toBe('Product Manager')
  expect(rows[0]?.scope).toBe('global')
  expect(rows[0]?.sessions.map((s) => [s.id, s.directiveTitle])).toEqual([
    ['pm_plan', 'Plan the release'],
    ['pm_triage', 'Triage issues'],
  ])
})

test('peopleListsUnusedPersona', () => {
  const rows = people(library({ personas: [persona('pm', 'Product Manager')] }))
  expect(rows).toEqual([{ personaId: 'pm', name: 'Product Manager', scope: 'global', shadows: null, sessions: [] }])
})

test('peopleKeepsDanglingSession', () => {
  const rows = people(
    library({
      personas: [persona('pm', 'Product Manager')],
      sessions: [session('ghost_missing', 'ghost', 'gone', [], 'project')],
    }),
  )
  expect(rows.map((r) => r.personaId)).toEqual(['ghost', 'pm'])
  expect(rows[0]).toEqual({
    personaId: 'ghost',
    name: 'ghost',
    scope: null,
    shadows: null,
    sessions: [{ id: 'ghost_missing', directiveTitle: 'gone', scope: 'project', shadows: null, inForce: false }],
  })
})

test('peopleSortsByNameThenId', () => {
  const rows = people(
    library({ personas: [persona('b', 'Same'), persona('a', 'Same'), persona('z', 'Alpha')] }),
  )
  expect(rows.map((r) => r.personaId)).toEqual(['z', 'a', 'b'])
})

test('peopleMarksInForce', () => {
  const rows = people(
    library({
      personas: [persona('pm', 'Product Manager')],
      directives: [directive('d', 'Do it')],
      sessions: [session('a', 'pm', 'd'), session('b', 'pm', 'd')],
    }),
    'a',
  )
  expect(rows[0]?.sessions.map((s) => [s.id, s.inForce])).toEqual([
    ['a', true],
    ['b', false],
  ])
})

test('usedByIndexesKitsAndSkills', () => {
  const index = usedBy(
    library({
      personas: [
        persona('pm', 'Product Manager', { defaultKitIds: ['k'], allowedSkillIds: ['s'] }),
        persona('eng', 'Engineer', { defaultKitIds: ['k'] }),
      ],
      directives: [directive('d', 'Do it')],
      kits: [kit('k', 'Kit', ['s'])],
      skills: [skill('s', 'Skill')],
      sessions: [session('b', 'pm', 'd', ['k']), session('a', 'pm', 'd', ['k']), session('c', 'ghost', 'd')],
    }),
  )
  expect(index.personasByKit).toEqual({ k: ['eng', 'pm'] })
  expect(index.kitsBySkill).toEqual({ s: ['k'] })
  expect(index.personasBySkill).toEqual({ s: ['pm'] })
  expect(index.sessionsByKit).toEqual({ k: ['a', 'b'] })
  expect(index.sessionsByPersona).toEqual({ ghost: ['c'], pm: ['a', 'b'] })
  expect(index.sessionsByDirective).toEqual({ d: ['a', 'b', 'c'] })
})

test('usedByDeduplicatesAndSkipsUnused', () => {
  const index = usedBy(
    library({
      personas: [persona('pm', 'PM', { defaultKitIds: ['k', 'k'] })],
      kits: [kit('k', 'Kit', ['s', 's']), kit('lonely', 'Lonely')],
    }),
  )
  expect(index.personasByKit).toEqual({ k: ['pm'] })
  expect(index.kitsBySkill).toEqual({ s: ['k'] })
  expect(index.sessionsByKit).toEqual({})
})

// Mirrors the mockup: one item of each kind matches "prod".
const mockup = library({
  personas: [persona('pm', 'Product Manager', {}, 'project'), persona('eng', 'Engineer', {}, 'global')],
  directives: [directive('release', 'Prepare production release', 'project'), directive('cli', 'Fix the cli', 'global')],
  kits: [kit('prod-kit', 'Production kit', [], 'project'), kit('swift', 'Swift style', [], 'global')],
  skills: [skill('prod-deploy', 'Deploy', 'global'), skill('lint', 'Lint', 'project')],
  sessions: [session('eng_cli', 'eng', 'cli', [], 'global')],
})

test('filterMatchesAcrossKinds', () => {
  const results = filterLibrary(mockup, 'prod')
  expect(results.people.map((p) => p.personaId)).toEqual(['pm'])
  expect(results.directives).toEqual([{ kind: 'directive', id: 'release', label: 'Prepare production release', scope: 'project', shadows: null }])
  expect(results.kits).toEqual([{ kind: 'kit', id: 'prod-kit', label: 'Production kit', scope: 'project', shadows: null }])
  expect(results.skills).toEqual([{ kind: 'skill', id: 'prod-deploy', label: 'Deploy', scope: 'global', shadows: null }])
})

test('filterMatchesPersonThroughSession', () => {
  const bySessionId = filterLibrary(mockup, 'ENG_CLI')
  expect(bySessionId.people.map((p) => p.personaId)).toEqual(['eng'])
  expect(bySessionId.people[0]?.sessions).toHaveLength(1)
  const byDirectiveTitle = filterLibrary(mockup, 'fix the')
  expect(byDirectiveTitle.people.map((p) => p.personaId)).toEqual(['eng'])
  expect(byDirectiveTitle.directives.map((d) => d.id)).toEqual(['cli'])
})

test('filterKeepsWholePersonRowOnSessionMatch', () => {
  const lib = library({
    personas: [persona('eng', 'Engineer')],
    directives: [directive('a', 'Alpha'), directive('b', 'Beta')],
    sessions: [session('eng_a', 'eng', 'a'), session('eng_b', 'eng', 'b')],
  })
  const results = filterLibrary(lib, 'alpha')
  expect(results.people[0]?.sessions.map((s) => s.id)).toEqual(['eng_a', 'eng_b'])
})

test('filterByScopeWord', () => {
  const projectOnly = filterLibrary(mockup, 'project')
  expect(projectOnly.people.map((p) => p.personaId)).toEqual(['pm'])
  expect(projectOnly.directives.map((d) => d.id)).toEqual(['release'])
  expect(projectOnly.kits.map((k) => k.id)).toEqual(['prod-kit'])
  expect(projectOnly.skills.map((s) => s.id)).toEqual(['lint'])
  const projectCli = filterLibrary(mockup, 'project cli')
  expect(projectCli.people).toEqual([])
  expect(projectCli.directives).toEqual([])
  const globalCli = filterLibrary(mockup, 'global cli')
  expect(globalCli.directives.map((d) => d.id)).toEqual(['cli'])
  expect(globalCli.people.map((p) => p.personaId)).toEqual(['eng'])
})

test('filterScopeWordMatchesThroughSessionScope', () => {
  const lib = library({
    personas: [persona('eng', 'Engineer', {}, 'global')],
    directives: [directive('cli-x', 'Run cli-x', 'project')],
    sessions: [session('eng_cli-x', 'eng', 'cli-x', [], 'project')],
  })
  expect(filterLibrary(lib, 'project').people.map((p) => p.personaId)).toEqual(['eng'])
  expect(filterLibrary(lib, 'project cli').people.map((p) => p.personaId)).toEqual(['eng'])
  expect(filterLibrary(lib, 'global cli').people).toEqual([])
  expect(filterLibrary(lib, 'global').people.map((p) => p.personaId)).toEqual(['eng'])
})

test('filterScopeWordMatchesDanglingPersonThroughSession', () => {
  const lib = library({ sessions: [session('ghost_x', 'ghost', 'gone', [], 'project')] })
  expect(filterLibrary(lib, 'project').people.map((p) => p.personaId)).toEqual(['ghost'])
  expect(filterLibrary(lib, 'global').people).toEqual([])
})

test('filterScopeWordIsNotMatchedAsText', () => {
  const lib = library({ skills: [skill('project-notes', 'Notes', 'global')] })
  expect(filterLibrary(lib, 'project').skills).toEqual([])
  expect(filterLibrary(lib, 'project-notes').skills).toHaveLength(1)
})

test('filterBlankQueryReturnsEverything', () => {
  const results = filterLibrary(mockup, '   ')
  expect(results.people).toHaveLength(2)
  expect(results.directives).toHaveLength(2)
  expect(results.kits).toHaveLength(2)
  expect(results.skills).toHaveLength(2)
})

test('filterEmptyResult', () => {
  expect(filterLibrary(mockup, 'zzz')).toEqual({ people: [], directives: [], kits: [], skills: [] })
})
