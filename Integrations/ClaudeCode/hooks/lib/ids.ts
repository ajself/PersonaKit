import type { ContractIds } from '../../types'

/**
 * The id rule, the same as the CLI's `WorkspaceEntityIDPolicy`: ASCII letters, digits, `.`, `_` and `-`, not empty and
 * not starting with `.`. Ids reach argv only as `--session=<id>`, `--persona=<id>` and `--directive=<id>`, so a
 * leading `-` cannot read as a flag.
 */
export const isValidId = (id: string): boolean => /^[A-Za-z0-9_-][A-Za-z0-9._-]*$/.test(id)

/** Every id `ids` carries, in session, persona, directive order. */
export const presentIds = ({ sessionId, personaId, directiveId }: ContractIds): string[] =>
  [sessionId, personaId, directiveId].filter((id): id is string => id !== undefined)

/** True when at least one id is present and every present id is valid. */
export const canUse = (ids: ContractIds): boolean => {
  const present = presentIds(ids)
  return present.length > 0 && present.every(isValidId)
}
