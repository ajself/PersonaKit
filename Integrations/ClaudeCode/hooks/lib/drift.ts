import type { Call, DriftEvent, Enforcement } from '../../types'
import { CLAUDE_HOST, PERSONAKIT_MCP_TOOL_NAMES } from './host'
import type { Host } from './host'
import { isPersonaKitCall } from './observe'

/** Classes a tool PersonaKit cannot classify could plausibly perform (mirrors `unclassifiedToolActionClasses`). */
const UNCLASSIFIED_RELEVANT = ['file-mutation', 'command-execution', 'network-egress']

// The last marks an operator prompt that was refused, as in a headless run where no one can answer it.
const DENY_MARKERS = [
  'Blocked by PersonaKit contract:',
  'PersonaKit enforcement could not',
  'PersonaKit could not check this tool call',
  'PersonaKit contract needs approval:',
]

/** An input field as the checker reads it: absent or null is none, and a value that is not a string is unknown. */
function presentString(value: unknown): string | undefined {
  if (value === undefined || value === null) return undefined
  return typeof value === 'string' ? value : '(not a string)'
}

/**
 * Whether the checker would let an unclassified call through, as it judges one: a read-only built-in (a subagent only
 * of a built-in local type with no `isolation`), a resource read from a trusted server, or PersonaKit's own MCP tool
 * from one. A built-in type that an agent definition on disk replaces is not seen here: that takes a folder read.
 */
function checkerAllows(call: Call, trustedServers: string[], host: Host): boolean {
  const { tool, input } = call
  if (host.isMCPTool(tool)) {
    return trustedServers.some(
      (server) =>
        host.trustsMCPKey(tool, server) && PERSONAKIT_MCP_TOOL_NAMES.some((name) => tool === host.mcpToolName(server, name)),
    )
  }
  if (host.subagentTools.includes(tool)) {
    const isolation = presentString(input.isolation)
    const type = presentString(input.subagent_type)
    if (isolation !== undefined && isolation !== '') return false
    if (type !== undefined && type !== '' && !host.localSubagentTypes.includes(type)) return false
  }
  if (host.readOnlyTools.includes(tool)) return true
  const server = input.server
  return host.mcpResourceTools.includes(tool) && typeof server === 'string' && trustedServers.includes(server)
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

  // A manifest whose plugin is not loaded enforces nothing, so its drift is judged as advisory.
  if (enforcement.kind !== 'advisory' && !enforcement.pluginMissing) {
    const text = call.result.text ?? ''
    const denied =
      call.result.isError === true &&
      routed(tool, enforcement.matcherTools) &&
      DENY_MARKERS.some((marker) => text.includes(marker))
    return denied ? event(personaKit ? 'reground-blocked' : 'blocked', !personaKit) : undefined
  }

  if (personaKit || call.result.isError === true) return undefined
  if (actionClass !== undefined) return deniedActionClasses.includes(actionClass) ? event('advisory') : undefined
  // An unclassified call the checker would not let through could do anything the contract forbids.
  if (!checkerAllows(call, trustedServers, host) && UNCLASSIFIED_RELEVANT.some((c) => deniedActionClasses.includes(c))) {
    return event('advisory', false)
  }
  return undefined
}
