import type { ContractIds } from '../../types'

/** The only ids passed to the CLI: they cannot start with `-` or carry spaces or control characters. */
export const isValidId = (id: string): boolean => /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(id)

/** Every id `ids` carries, in session, persona, directive order. */
export const presentIds = ({ sessionId, personaId, directiveId }: ContractIds): string[] =>
  [sessionId, personaId, directiveId].filter((id): id is string => id !== undefined)

/** True when at least one id is present and every present id is valid. */
export const canUse = (ids: ContractIds): boolean => {
  const present = presentIds(ids)
  return present.length > 0 && present.every(isValidId)
}
