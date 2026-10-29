import type { ContractIds, Observation } from '../../types'
import { parseContract } from './contract'
import { parseExport } from './export'
import { CLAUDE_HOST } from './host'
import type { Host } from './host'

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
    const c = command.charAt(i)
    if (quote) {
      // An open quote always holds a word: the opening quote started one.
      if (c === quote) quote = undefined
      else if (c === '\\' && quote === '"' && i + 1 < command.length) word = (word ?? '') + command.charAt(++i)
      else word = (word ?? '') + c
    } else if (c === '"' || c === "'") {
      quote = c
      word ??= ''
    } else if (c === '\\' && i + 1 < command.length) {
      word = (word ?? '') + command.charAt(++i)
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

/** Every `personakit contract|export` invocation in a Bash command, in order. */
function parseCli(command: string): CliCommand[] {
  const out: CliCommand[] = []
  for (const words of segments(command)) {
    let i = 0
    while (/^[A-Za-z_][A-Za-z0-9_]*=/.test(words[i] ?? '')) i++
    if (words[i] === 'swift' && words[i + 1] === 'run') i += 2
    const program = words[i]
    if (program === undefined || basename(program) !== 'personakit') continue
    const sub = words[i + 1]
    if (sub === 'contract' || sub === 'export') out.push({ subcommand: sub, args: words.slice(i + 2) })
  }
  return out
}

function cliCommands(tool: string, input: Record<string, unknown>, host: Host): CliCommand[] {
  if (tool !== host.shellTool || typeof input.command !== 'string') return []
  return parseCli(input.command)
}

function flagValue(args: string[], flag: string): string | undefined {
  for (const [i, arg] of args.entries()) {
    if (arg === flag) return args[i + 1]
    if (arg.startsWith(`${flag}=`)) return arg.slice(flag.length + 1)
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

function mcpKind(tool: string, trustedServers: string[], host: Host): 'contract' | 'export' | undefined {
  for (const server of trustedServers) {
    if (tool === host.mcpToolName(server, MCP_RESOLVE)) return 'contract'
    if (tool === host.mcpToolName(server, MCP_EXPORT)) return 'export'
  }
  return undefined
}

/** True for a trusted MCP resolve/export tool or a recognized `personakit contract|export` command. */
export function isPersonaKitCall(
  tool: string,
  input: Record<string, unknown>,
  trustedServers: string[],
  host: Host = CLAUDE_HOST,
): boolean {
  return mcpKind(tool, trustedServers, host) !== undefined || cliCommands(tool, input, host).length > 0
}

const compact = (ids: ContractIds): ContractIds => {
  const out: ContractIds = {}
  if (ids.sessionId) out.sessionId = ids.sessionId
  if (ids.personaId) out.personaId = ids.personaId
  if (ids.directiveId) out.directiveId = ids.directiveId
  return out
}

/** The end of the brace-balanced span opening at `start`, skipping JSON strings; undefined when it never closes. */
function balancedEnd(text: string, start: number): number | undefined {
  let depth = 0
  let inString = false
  for (let i = start; i < text.length; i++) {
    const c = text[i]
    if (inString) {
      if (c === '\\') i++
      else if (c === '"') inString = false
    } else if (c === '"') inString = true
    else if (c === '{') depth++
    else if (c === '}' && --depth === 0) return i + 1
  }
  return undefined
}

/** The first balanced `{…}` span that parses as a contract; braces in other output (export code, noise) are skipped. */
function contractPart(text: string): string | undefined {
  for (let start = text.indexOf('{'); start >= 0; start = text.indexOf('{', start + 1)) {
    const end = balancedEnd(text, start)
    if (end === undefined) continue
    const span = text.slice(start, end)
    if (parseContract(span) !== undefined) return span
  }
  return undefined
}

/** Export Markdown from its `PersonaKit-Output-Version:` line to the end of the output. */
function exportPart(text: string): string | undefined {
  const at = text.search(/^PersonaKit-Output-Version:/m)
  return at < 0 ? undefined : text.slice(at)
}

/** A contract or export read from `text`; undefined text is truncated output, which keeps the input ids. */
function interpret(kind: 'contract' | 'export', source: 'mcp' | 'cli', inputIds: ContractIds, text: string | undefined): Observation {
  const failed: Observation = { kind: 'failed', source, ids: inputIds }
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

/**
 * Interprets one tool call as PersonaKit contract and export observations, in invocation order:
 * one for a trusted MCP call, one per `personakit contract|export` in a Bash command, else none.
 */
export async function observe(
  call: Call,
  trustedServers: string[],
  readPersisted: (path: string) => Promise<string | undefined>,
  host: Host = CLAUDE_HOST,
): Promise<Observation[]> {
  const result = (call.result ?? {}) as { isError?: boolean; text?: unknown; result?: unknown }
  const mcp = mcpKind(call.tool, trustedServers, host)
  if (mcp !== undefined) {
    const ids: ContractIds = typeof call.input.sessionId === 'string' && call.input.sessionId ? { sessionId: call.input.sessionId } : {}
    const text = typeof result.text === 'string' ? result.text : undefined
    if (result.isError === true || text === undefined) return [{ kind: 'failed', source: 'mcp', ids }]
    return [interpret(mcp, 'mcp', ids, text)]
  }

  // The agent never saw the contract text for `--copy` / `--output` exports.
  const clis = cliCommands(call.tool, call.input, host).filter(
    (c) => c.subcommand !== 'export' || !(hasFlag(c.args, '--copy') || hasFlag(c.args, '--output')),
  )
  if (clis.length === 0) return []
  if (result.isError === true) return clis.map((c) => ({ kind: 'failed', source: 'cli', ids: cliIds(c.args) }))

  const raw = (result.result ?? {}) as { stdout?: unknown; persistedOutputPath?: unknown }
  let text: string | undefined
  // With a persisted file, stdout is only a truncated preview: never parse it.
  if (typeof raw.persistedOutputPath === 'string') text = await readPersisted(raw.persistedOutputPath)
  else if (typeof raw.stdout === 'string' && raw.stdout.length > 0) text = raw.stdout
  // Empty stdout and nothing persisted: the output never reached the agent (redirect, pipe to pbcopy).
  else return []

  // One output holds every invocation's part; each is cut out of it, and a missing part fails its invocation.
  return clis.map((c) => {
    const ids = cliIds(c.args)
    if (text === undefined) return interpret(c.subcommand, 'cli', ids, undefined)
    const part = c.subcommand === 'contract' ? contractPart(text) : exportPart(text)
    return part === undefined ? { kind: 'failed', source: 'cli', ids } : interpret(c.subcommand, 'cli', ids, part)
  })
}
