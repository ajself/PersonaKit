import type { Library, Provenance, Scope } from '../../types'

export type PersonRow = {
  personaId: string
  name: string
  scope: Scope | null
  shadows: Scope | null
  sessions: { id: string; directiveTitle: string; scope: Scope; shadows: Scope | null; inForce: boolean }[]
}

export type UsedBy = {
  sessionsByPersona: Record<string, string[]>
  sessionsByDirective: Record<string, string[]>
  personasByKit: Record<string, string[]>
  sessionsByKit: Record<string, string[]>
  kitsBySkill: Record<string, string[]>
  personasBySkill: Record<string, string[]>
}

export type FilterHit = {
  kind: 'person' | 'directive' | 'kit' | 'skill'
  id: string
  label: string
  scope: Scope
  shadows: Scope | null
}
export type FilterResults = { people: PersonRow[]; directives: FilterHit[]; kits: FilterHit[]; skills: FilterHit[] }

const compare = (a: string, b: string): number => (a < b ? -1 : a > b ? 1 : 0)
const compareNamed = (a: { name: string; id: string }, b: { name: string; id: string }): number =>
  compare(a.name.toLowerCase(), b.name.toLowerCase()) || compare(a.name, b.name) || compare(a.id, b.id)

/** Groups sessions under their persona, plus every persona no session uses; a dangling persona id gets its own row. */
export function people(library: Library, inForceSessionId?: string): PersonRow[] {
  const titles = new Map(library.directives.map((d) => [d.id, d.entity.title]))
  const rows = new Map<string, PersonRow>(
    library.personas.map((p) => [
      p.id,
      { personaId: p.id, name: p.entity.name, scope: p.scope, shadows: p.shadows, sessions: [] },
    ]),
  )
  for (const s of library.sessions) {
    let row = rows.get(s.personaId)
    if (row === undefined) {
      row = { personaId: s.personaId, name: s.personaId, scope: null, shadows: null, sessions: [] }
      rows.set(s.personaId, row)
    }
    row.sessions.push({
      id: s.id,
      directiveTitle: titles.get(s.directiveId) ?? s.directiveId,
      scope: s.scope,
      shadows: s.shadows,
      inForce: s.id === inForceSessionId,
    })
  }
  const result = [...rows.values()]
  for (const row of result) row.sessions.sort((a, b) => compare(a.id, b.id))
  return result.sort((a, b) => compareNamed({ name: a.name, id: a.personaId }, { name: b.name, id: b.personaId }))
}

/** Reverse references, keyed by the referenced id; each list is sorted and free of duplicates. */
export function usedBy(library: Library): UsedBy {
  const index = (pairs: [string, string][]): Record<string, string[]> => {
    const grouped = new Map<string, Set<string>>()
    for (const [key, value] of pairs) {
      const set = grouped.get(key) ?? new Set<string>()
      set.add(value)
      grouped.set(key, set)
    }
    return Object.fromEntries([...grouped].map(([key, set]) => [key, [...set].sort(compare)]))
  }
  return {
    sessionsByPersona: index(library.sessions.map((s) => [s.personaId, s.id])),
    sessionsByDirective: index(library.sessions.map((s) => [s.directiveId, s.id])),
    personasByKit: index(library.personas.flatMap((p) => p.entity.defaultKitIds.map((k): [string, string] => [k, p.id]))),
    sessionsByKit: index(library.sessions.flatMap((s) => s.kitOverrides.map((k): [string, string] => [k, s.id]))),
    kitsBySkill: index(library.kits.flatMap((k) => (k.entity.skillIds ?? []).map((s): [string, string] => [s, k.id]))),
    personasBySkill: index(library.personas.flatMap((p) => p.entity.allowedSkillIds.map((s): [string, string] => [s, p.id]))),
  }
}

/**
 * Case-insensitive AND over the query's words. `project` and `global` filter by scope and are not matched as text;
 * every other word is a substring of an id or display name. A person matches through its persona alone or through
 * any one of its sessions (session scope; session id, directive title, persona id and name), and then keeps the
 * whole row.
 */
export function filterLibrary(library: Library, query: string, inForceSessionId?: string): FilterResults {
  const words = query.toLowerCase().split(/\s+/).filter((w) => w !== '')
  const matches = (scope: Scope | null, texts: string[]): boolean => {
    const haystacks = texts.map((t) => t.toLowerCase())
    return words.every((w) =>
      w === 'project' || w === 'global' ? scope === w : haystacks.some((h) => h.includes(w)),
    )
  }
  const hits = <E>(kind: FilterHit['kind'], items: (Provenance & { entity: E })[], label: (entity: E) => string): FilterHit[] =>
    items
      .filter((item) => matches(item.scope, [item.id, label(item.entity)]))
      .map((item) => ({ kind, id: item.id, label: label(item.entity), scope: item.scope, shadows: item.shadows }))
      .sort((a, b) => compareNamed({ name: a.label, id: a.id }, { name: b.label, id: b.id }))
  return {
    people: people(library, inForceSessionId).filter(
      (row) =>
        matches(row.scope, [row.personaId, row.name]) ||
        row.sessions.some((s) => matches(s.scope, [s.id, s.directiveTitle, row.personaId, row.name])),
    ),
    directives: hits('directive', library.directives, (d) => d.title),
    kits: hits('kit', library.kits, (k) => k.name),
    skills: hits('skill', library.skills, (s) => s.name),
  }
}
