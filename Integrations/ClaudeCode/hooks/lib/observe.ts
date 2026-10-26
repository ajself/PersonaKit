import type { ContractIds, Observation } from '../../types'
import { parseContract } from './contract'
import { parseExport } from './export'

type Call = { tool: string; input: Record<string, unknown>; result: unknown }
type CliCommand = { subcommand: 'contract' | 'export'; args: string[] }

const MCP_RESOLVE = 'personakit_resolve_contract'
const MCP_EXPORT = 'personakit_export'

/** Splits a shell command into segments of words on unquoted `|`, `&&`, `||`, `;`, `&` and newlines. */
function segments(command: string): string[][] {
  const out: string[][] = []
  let words: string[] = []
  let word: string | undefined
  let quote: '"' | "'" | undefined
  const endWord = () => {
    if (word !== undefined) words.push(word)
    word = undefined
  }
  const endSegment = () => {
    endWord()
    if (words.length > 0) out.push(words)
    words = []
  }
  for (let i = 0; i < command.length; i++) {
    const c = command[i]
    if (quote) {
      if (c === quote) quote = undefined
      else if (c === '\\' && quote === '"' && i + 1 < command.length) word += command[++i]
      else word += c
    } else if (c === '"' || c === "'") {
      quote = c
      word ??= ''
    } else if (c === '\\' && i + 1 < command.length) {
      word = (word ?? '') + command[++i]
    } else if (c === ' ' || c === '\t') {
      endWord()
    } else if (c === '|' || c === '&' || c === ';' || c === '\n') {
      endSegment()
    } else {
      word = (word ?? '') + c
    }
  }
  endSegment()
  return out
}

const basename = (path: string) => path.slice(path.lastIndexOf('/') + 1)

/** The first `personakit contract|export` invocation in a Bash command, if any. */
function parseCli(command: string): CliCommand | undefined {
  for (const words of segments(command)) {
    let i = 0
    while (i < words.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(words[i])) i++
    if (words[i] === 'swift' && words[i + 1] === 'run') i += 2
    else if (words[i] === undefined) continue
    if (words[i] === undefined || basename(words[i]) !== 'personakit') continue
    i += 1
    const sub = words[i]
    if (sub === 'contract' || sub === 'export') return { subcommand: sub, args: words.slice(i + 1) }
  }
  return undefined
}

function cliCommand(tool: string, input: Record<string, unknown>): CliCommand | undefined {
  if (tool !== 'Bash' || typeof input.command !== 'string') return undefined
  return parseCli(input.command)
}

function flagValue(args: string[], flag: string): string | undefined {
  for (let i = 0; i < args.length; i++) {
    if (args[i] === flag) return args[i + 1]
    if (args[i].startsWith(`${flag}=`)) return args[i].slice(flag.length + 1)
  }
  return undefined
}

const hasFlag = (args: string[], flag: string) => args.some((a) => a === flag || a.startsWith(`${flag}=`))

function cliIds(args: string[]): ContractIds {
  const ids: ContractIds = {}
  const session = flagValue(args, '--session')
  const persona = flagValue(args, '--persona')
  const directive = flagValue(args, '--directive')
  if (session) ids.sessionId = session
  if (persona) ids.personaId = persona
  if (directive) ids.directiveId = directive
  return ids
}

function mcpKind(tool: string, trustedServers: string[]): 'contract' | 'export' | undefined {
  for (const server of trustedServers) {
    if (tool === `mcp__${server}__${MCP_RESOLVE}`) return 'contract'
    if (tool === `mcp__${server}__${MCP_EXPORT}`) return 'export'
  }
  return undefined
}

/** True for a trusted MCP resolve/export tool or a recognized `personakit contract|export` command. */
export function isPersonaKitCall(tool: string, input: Record<string, unknown>, trustedServers: string[]): boolean {
  return mcpKind(tool, trustedServers) !== undefined || cliCommand(tool, input) !== undefined
}

const compact = (ids: ContractIds): ContractIds => {
  const out: ContractIds = {}
  if (ids.sessionId) out.sessionId = ids.sessionId
  if (ids.personaId) out.personaId = ids.personaId
  if (ids.directiveId) out.directiveId = ids.directiveId
  return out
}

/** Interprets one tool call as a PersonaKit contract or export observation; undefined when it is neither. */
export async function observe(
  call: Call,
  trustedServers: string[],
  readPersisted: (path: string) => Promise<string | undefined>,
): Promise<Observation | undefined> {
  const mcp = mcpKind(call.tool, trustedServers)
  const cli = mcp === undefined ? cliCommand(call.tool, call.input) : undefined
  const kind = mcp ?? cli?.subcommand
  if (kind === undefined) return undefined
  // The agent never saw the contract text for these.
  if (cli?.subcommand === 'export' && (hasFlag(cli.args, '--copy') || hasFlag(cli.args, '--output'))) return undefined

  const source = mcp !== undefined ? 'mcp' : 'cli'
  const inputIds: ContractIds = cli
    ? cliIds(cli.args)
    : typeof call.input.sessionId === 'string' && call.input.sessionId
      ? { sessionId: call.input.sessionId }
      : {}
  const failed: Observation = { kind: 'failed', source, ids: inputIds }

  const result = (call.result ?? {}) as { isError?: boolean; text?: unknown; result?: unknown }
  if (result.isError === true) return failed

  let text: string | undefined
  if (mcp !== undefined) {
    text = typeof result.text === 'string' ? result.text : undefined
    if (text === undefined) return failed
  } else {
    const raw = (result.result ?? {}) as { stdout?: unknown; persistedOutputPath?: unknown }
    // With a persisted file, stdout is only a truncated preview: never parse it.
    if (typeof raw.persistedOutputPath === 'string') text = await readPersisted(raw.persistedOutputPath)
    else if (typeof raw.stdout === 'string' && raw.stdout.length > 0) text = raw.stdout
    // Empty stdout and nothing persisted: the output never reached the agent (redirect, pipe to pbcopy).
    else return undefined
  }

  if (kind === 'contract') {
    if (text === undefined) return { kind: 'contract', source, ids: inputIds }
    const contract = parseContract(text)
    if (contract === undefined) return failed
    return {
      kind: 'contract',
      source,
      ids: compact({ sessionId: contract.sessionId, personaId: contract.personaId, directiveId: contract.directiveId }),
      contract,
    }
  }
  if (text === undefined) return { kind: 'export', source, ids: inputIds }
  const details = parseExport(text)
  if (details === undefined) return failed
  return {
    kind: 'export',
    source,
    ids: compact({
      sessionId: inputIds.sessionId,
      personaId: details.personaId ?? inputIds.personaId,
      directiveId: details.directiveId ?? inputIds.directiveId,
    }),
    details,
  }
}
