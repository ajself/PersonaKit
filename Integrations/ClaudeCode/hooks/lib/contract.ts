import type { Contract } from '../../types'

const str = (v: unknown): string | undefined => (typeof v === 'string' ? v : undefined)
// The modes `personakit contract` prints (`ScopeSet.mode`); anything else is dropped rather than shown.
const SCOPE_MODES = ['project-only', 'global-only', 'merged', 'none']
const scopeMode = (v: unknown): string => (typeof v === 'string' && SCOPE_MODES.includes(v) ? v : '')
const strs = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : [])

/** Parses `personakit contract` JSON output; undefined when it is not a contract. */
export function parseContract(json: string): Contract | undefined {
  let raw: unknown
  try {
    raw = JSON.parse(json)
  } catch {
    return undefined
  }
  if (typeof raw !== 'object' || raw === null) return undefined
  const o = raw as Record<string, unknown>
  const personaId = str(o.personaId)
  if (personaId === undefined) return undefined
  const scope = (typeof o.scope === 'object' && o.scope !== null ? o.scope : {}) as Record<string, unknown>
  return {
    personaId,
    directiveId: str(o.directiveId),
    sessionId: str(o.sessionId),
    kitIds: strs(o.kitIds),
    allowedSkillIds: strs(o.allowedSkillIds),
    forbiddenSkillIds: strs(o.forbiddenSkillIds),
    authorizedSkillIds: strs(o.authorizedSkillIds),
    isAuthorized: o.isAuthorized === true,
    failureReasons: strs(o.failureReasons),
    unauthorizedRequestedSkillIds: strs(o.unauthorizedRequestedSkillIds),
    unauthorizedRequiredSkillIds: strs(o.unauthorizedRequiredSkillIds),
    undeclaredRequestedSkillIds: strs(o.undeclaredRequestedSkillIds),
    scope: {
      mode: scopeMode(scope.mode),
      projectRoot: str(scope.projectRoot),
      globalRoot: str(scope.globalRoot),
    },
  }
}
