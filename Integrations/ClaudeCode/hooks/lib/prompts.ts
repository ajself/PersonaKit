import type { ContractIds } from '../../types'

/** A shell word: bare when safe, otherwise POSIX single-quoted. */
const sh = (word: string) => (/^[A-Za-z0-9._\/:@+-]+$/.test(word) ? word : `'${word.replace(/'/g, `'\\''`)}'`)

/**
 * The prompt `/pk use` and Re-ground pre-fill: resolve the contract, then export it, by the ids it was
 * resolved with (session id when there is one, else persona and directive), then adopt it. Both, so the
 * mod sees the contract JSON (kits, skills, scope) as well as the export (names, steps, boundaries).
 */
export function usePrompt(ids: ContractIds): string {
  const { sessionId, personaId, directiveId } = ids
  const what = sessionId !== undefined
    ? `session \`${sessionId}\``
    : [personaId && `personaId \`${personaId}\``, directiveId && `directiveId \`${directiveId}\``].filter(Boolean).join(' and ')
  const flags = sessionId !== undefined
    ? `--session=${sh(sessionId)}`
    : [personaId && `--persona=${sh(personaId)}`, directiveId && `--directive=${sh(directiveId)}`].filter(Boolean).join(' ')
  return (
    `Ground this session in the PersonaKit contract for ${what}. ` +
    `Resolve and then export it through PersonaKit: if the PersonaKit MCP server is connected, call its personakit_resolve_contract tool and then its personakit_export tool, each with ${what}; ` +
    `otherwise run \`personakit contract ${flags}\` and then \`personakit export ${flags}\`. ` +
    `Then adopt the exported contract as your operating contract for this session: its persona, its directive's steps and stop points, and its boundaries.`
  )
}
