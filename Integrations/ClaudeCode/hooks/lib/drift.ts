import type { DriftEvent, Enforcement } from '../../types'
import { CLAUDE_HOST, TOOL_ACTION_CLASSES } from './host'
import type { Host } from './host'
import { isPersonaKitCall } from './observe'

export { TOOL_ACTION_CLASSES }

/** Classes an unclassifiable MCP tool could plausibly perform (mirrors `mcpRelevantActionClasses`). */
const MCP_RELEVANT = ['file-mutation', 'command-execution', 'network-egress']

const DENY_MARKERS = ['Blocked by PersonaKit contract:', 'PersonaKit enforcement could not']

type Call = {
  tool: string
  input: Record<string, unknown>
  // `text` is the result's plain-text rendering; `isError` marks a failed or hook-denied call.
  result: { isError?: boolean; text?: string }
  agentId?: string
}

/** Whether the installed hook's matcher routes the tool. Entries are regex alternatives anchored to the whole name. */
function routed(tool: string, matcherTools: string[]): boolean {
  return matcherTools.some((entry) => {
    try {
      return new RegExp(`^(?:${entry})$`).test(tool)
    } catch {
      return entry === tool
    }
  })
}

/** Classifies a completed tool call as drift against the contract, or undefined when it is not. Observe-only. */
export function classifyDrift(
  call: Call,
  deniedActionClasses: string[],
  enforcement: Enforcement,
  trustedServers: string[],
  turn: number,
  host: Host = CLAUDE_HOST,
): DriftEvent | undefined {
  const { tool, agentId } = call
  // An MCP key shadows a built-in of the same name, and only a tool's own entry is a class (never `constructor`).
  const actionClass =
    !host.isMCPTool(tool) && Object.hasOwn(host.toolActionClasses, tool) ? host.toolActionClasses[tool] : undefined
  const event = (kind: DriftEvent['kind'], withClass = true): DriftEvent => ({
    tool,
    ...(withClass && actionClass !== undefined ? { actionClass } : {}),
    kind,
    ...(agentId !== undefined ? { agentId } : {}),
    turn,
  })
  const personaKit = isPersonaKitCall(tool, call.input, trustedServers, host)

  if (enforcement.kind !== 'advisory') {
    const text = call.result.text ?? ''
    const denied =
      call.result.isError === true &&
      routed(tool, enforcement.matcherTools) &&
      DENY_MARKERS.some((marker) => text.includes(marker))
    return denied ? event(personaKit ? 'reground-blocked' : 'blocked', !personaKit) : undefined
  }

  if (personaKit || call.result.isError === true) return undefined
  if (actionClass !== undefined) return deniedActionClasses.includes(actionClass) ? event('advisory') : undefined
  if (host.isMCPTool(tool) && MCP_RELEVANT.some((c) => deniedActionClasses.includes(c))) return event('advisory', false)
  return undefined
}
