import type {
  DirectiveEntity,
  Library,
  LibraryError,
  LibraryLoad,
  LibrarySession,
  KitEntity,
  PersonaEntity,
  Provenance,
  Scope,
  SkillEntity,
} from '../../types'

type Obj = Record<string, unknown>
type Parsed = Exclude<LibraryLoad, { kind: 'idle' | 'loading' | 'no-process' | 'missing' | 'outdated' }>

const obj = (v: unknown): Obj | undefined => (typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Obj) : undefined)
const str = (v: unknown): string | undefined => (typeof v === 'string' ? v : undefined)
const strs = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : [])
const scopeOf = (v: unknown): Scope | undefined => (v === 'project' || v === 'global' ? v : undefined)

/** Keeps the records `parse` accepts; a malformed record is dropped, not the document. */
function records<T>(raw: unknown, parse: (o: Obj) => T | undefined): T[] {
  if (!Array.isArray(raw)) return []
  const out: T[] = []
  for (const item of raw) {
    const o = obj(item)
    const parsed = o && parse(o)
    if (parsed !== undefined) out.push(parsed)
  }
  return out
}

function provenance(o: Obj): Provenance | undefined {
  const id = str(o.id)
  const scope = scopeOf(o.scope)
  const path = str(o.path)
  if (id === undefined || scope === undefined || path === undefined) return undefined
  return { id, scope, path, shadows: scopeOf(o.shadows) ?? null, shadowedPath: str(o.shadowedPath) ?? null }
}

/** A provenance record carrying an entity that `parseEntity` accepts. */
function withEntity<E>(parseEntity: (o: Obj) => E | undefined) {
  return (o: Obj): (Provenance & { entity: E }) | undefined => {
    const base = provenance(o)
    const entityObj = obj(o.entity)
    const entity = entityObj && parseEntity(entityObj)
    return base && entity !== undefined ? { ...base, entity } : undefined
  }
}

function persona(o: Obj): PersonaEntity | undefined {
  const id = str(o.id)
  const name = str(o.name)
  const summary = str(o.summary)
  if (id === undefined || name === undefined || summary === undefined) return undefined
  return {
    id,
    name,
    summary,
    responsibilities: strs(o.responsibilities),
    values: strs(o.values),
    nonGoals: strs(o.nonGoals),
    defaultKitIds: strs(o.defaultKitIds),
    allowedSkillIds: strs(o.allowedSkillIds),
    forbiddenSkillIds: strs(o.forbiddenSkillIds),
    ...(Array.isArray(o.forbiddenCapabilities) ? { forbiddenCapabilities: strs(o.forbiddenCapabilities) } : {}),
  }
}

function directive(o: Obj): DirectiveEntity | undefined {
  const id = str(o.id)
  const title = str(o.title)
  const goal = str(o.goal)
  if (id === undefined || title === undefined || goal === undefined) return undefined
  return {
    id,
    title,
    goal,
    steps: records(o.steps, (s) => {
      const text = str(s.text)
      if (text === undefined) return undefined
      return typeof s.requiresReview === 'boolean' ? { text, requiresReview: s.requiresReview } : { text }
    }),
    acceptanceCriteria: strs(o.acceptanceCriteria),
    requiresSkillIds: strs(o.requiresSkillIds),
  }
}

function kit(o: Obj): KitEntity | undefined {
  const id = str(o.id)
  const name = str(o.name)
  const summary = str(o.summary)
  if (id === undefined || name === undefined || summary === undefined) return undefined
  return { id, name, summary, ...(Array.isArray(o.skillIds) ? { skillIds: strs(o.skillIds) } : {}) }
}

function skill(o: Obj): SkillEntity | undefined {
  const id = str(o.id)
  const name = str(o.name)
  const description = str(o.description)
  if (id === undefined || name === undefined || description === undefined) return undefined
  return { id, name, description }
}

function session(o: Obj): LibrarySession | undefined {
  const base = provenance(o)
  const personaId = str(o.personaId)
  const directiveId = str(o.directiveId)
  if (!base || personaId === undefined || directiveId === undefined) return undefined
  return { ...base, personaId, directiveId, kitOverrides: strs(o.kitOverrides) }
}

function libraryError(o: Obj): LibraryError | undefined {
  const entityType = str(o.entityType)
  if (entityType === undefined) return undefined
  return {
    scope: scopeOf(o.scope) ?? null,
    path: str(o.path) ?? null,
    entityType,
    id: str(o.id) ?? null,
    message: str(o.message) ?? '',
  }
}

function unavailable(stdout: string, exitCode: number, binary: string, why: string): Parsed {
  const firstLine = stdout.trim().split('\n')[0]?.slice(0, 120) ?? ''
  const status = exitCode === 0 ? why : `exit ${exitCode}`
  return { kind: 'unavailable', binary, detail: firstLine === '' ? status : `${status}: ${firstLine}` }
}

/** Parses `personakit list all --json` output. Anything that is not that document reads as unavailable. */
export function parseLibrary(stdout: string, exitCode: number, binary: string): Parsed {
  let raw: unknown
  try {
    raw = JSON.parse(stdout)
  } catch {
    return unavailable(stdout, exitCode, binary, 'output was not JSON')
  }
  const doc = obj(raw)
  if (doc === undefined) return unavailable(stdout, exitCode, binary, 'output was not a library document')
  if (doc.noLibrary === true) return { kind: 'no-library' }
  const errors = records(doc.errors, libraryError)
  if (errors.length > 0) return { kind: 'errors', errors }
  if (exitCode !== 0) return unavailable(stdout, exitCode, binary, 'failed')
  const scopes = obj(doc.scopes)
  if (scopes === undefined) return unavailable(stdout, exitCode, binary, 'output was not a library document')
  const project = str(scopes.project)
  const global = str(scopes.global)
  return {
    kind: 'loaded',
    library: {
      scopes: { ...(project !== undefined ? { project } : {}), ...(global !== undefined ? { global } : {}) },
      sessions: records(doc.sessions, session),
      personas: records(doc.personas, withEntity(persona)),
      directives: records(doc.directives, withEntity(directive)),
      kits: records(doc.kits, withEntity(kit)),
      skills: records(doc.skills, withEntity(skill)),
    } satisfies Library,
  }
}
