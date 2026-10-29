import type { Part, ToolPart } from '@opencode-ai/sdk/v2'
import type { Enforcement, SessionState } from '../../../ClaudeCode/types'
import type { Host } from '../../../ClaudeCode/hooks/lib/host.ts'
import { observe } from '../../../ClaudeCode/hooks/lib/observe.ts'
import { applyCall, initial, trustedServers } from '../../../ClaudeCode/hooks/lib/session.ts'
import type { Call } from '../../../ClaudeCode/hooks/lib/session.ts'

/**
 * A finished tool part as the shared core's call, or undefined while it is pending or running. The tool id is kept
 * as OpenCode names it; the host classifies it. A part from another session than `parentSessionID` is a subagent's.
 * A completed call's output is also offered as `result.stdout`, where `observe` reads a shell command's output. When
 * OpenCode truncated that output and saved the whole of it (`metadata.truncated` with `metadata.outputPath`), the
 * path is offered as `persistedOutputPath` so `observe` reads the full output from it, never the preview.
 */
export function toCall(part: ToolPart, parentSessionID: string): Call | undefined {
  type Result = Call['result'] & { result?: { stdout: string; persistedOutputPath?: string } }
  const { state } = part
  if (state.status !== 'completed' && state.status !== 'error') return undefined
  let result: Result
  if (state.status === 'completed') {
    result = { text: state.output, result: { stdout: state.output } }
    const { truncated, outputPath } = state.metadata
    if (truncated === true && typeof outputPath === 'string') result.result!.persistedOutputPath = outputPath
  } else {
    result = { isError: true, text: state.error }
  }
  const call: Call = { tool: part.tool, input: state.input, result }
  if (part.sessionID !== parentSessionID) call.agentId = part.sessionID
  return call
}

/**
 * The session state rebuilt from its messages, oldest first: each user message starts a turn, and each finished tool
 * part on the others is observed and applied in order. Pure apart from `read`; the same messages give the same state.
 */
export async function rebuildFrom(
  messages: readonly { role: string; id: string }[],
  parts: (messageID: string) => readonly Part[],
  host: Host,
  configured: string,
  enforcement: Enforcement,
  sessionID: string,
  read: (path: string) => Promise<string | undefined>,
): Promise<SessionState> {
  const trusted = trustedServers(configured, enforcement)
  let state: SessionState = { ...initial, enforcement }
  for (const message of messages) {
    if (message.role === 'user') {
      state = { ...state, turn: state.turn + 1 }
      continue
    }
    for (const part of parts(message.id)) {
      if (part.type !== 'tool') continue
      const call = toCall(part, sessionID)
      if (call === undefined) continue
      state = applyCall(state, call, await observe(call, trusted, read, host), trusted, host)
    }
  }
  return state
}
