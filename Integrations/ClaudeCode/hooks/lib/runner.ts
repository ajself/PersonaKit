import type { ContractIds, LibraryLoad, Preview } from '../../types'
import { parseContract } from './contract'
import { parseExport } from './export'
import { isValidId, presentIds } from './ids'
import { parseLibrary } from './library'

/** What the loaders read of a finished process; a host's richer result is assignable. */
export type ProcessRunResult = { stdout: string; stderr: string; exitCode: number; isStdoutTruncated?: boolean }

/** Only what the loaders need of `$`: the one-shot process call, which rejects when it cannot run. */
export type RunnerDollar = { process: { run: (argv: readonly string[], opts?: { stdin?: string }) => Promise<ProcessRunResult> } }

const TRUNCATED = 'output passed 4 MiB'
// The API documents no error type for "cannot start", so a start failure and a timeout are told by their message.
const CANNOT_START = /ENOENT|ENOTDIR|EACCES|ENOEXEC|no such file|not found|permission denied|cannot (start|run|execute|spawn)|failed to (start|spawn|launch)/i
const TIMED_OUT = /timed out|timeout|still running/i

/** The `personakitPath` option: the executable the pane runs, `personakit` unless one is configured. */
export const personakitBinary = (options: Readonly<Record<string, unknown>>): string =>
  typeof options.personakitPath === 'string' && options.personakitPath !== '' ? options.personakitPath : 'personakit'

const messageOf = (error: unknown) => (error instanceof Error ? error.message : String(error))
const firstLine = (text: string) => text.trim().split('\n')[0]?.slice(0, 200) ?? ''

/**
 * Runs `personakit list all --json` and reads it. A binary that cannot start, or timed out, is unavailable; any
 * other rejection means the host cannot run processes at all. `$.process` itself is never inspected.
 */
export async function loadLibrary($: RunnerDollar, binary: string): Promise<LibraryLoad> {
  let result: ProcessRunResult
  try {
    result = await $.process.run([binary, 'list', 'all', '--json'])
  } catch (error) {
    const detail = messageOf(error)
    return CANNOT_START.test(detail) || TIMED_OUT.test(detail) ? { kind: 'unavailable', binary, detail } : { kind: 'no-process' }
  }
  if (result.isStdoutTruncated) return { kind: 'unavailable', binary, detail: TRUNCATED }
  return parseLibrary(result.stdout, result.exitCode, binary)
}

/** The CLI flags for `ids`: `--session=<id>`, else `--persona=<id>` and `--directive=<id>`. */
const flagsOf = ({ sessionId, personaId, directiveId }: ContractIds): string[] =>
  sessionId !== undefined
    ? [`--session=${sessionId}`]
    : [...(personaId ? [`--persona=${personaId}`] : []), ...(directiveId ? [`--directive=${directiveId}`] : [])]

/** Where a contract's preview is kept in the pane: `session:<id>`, else `pd:<persona>/<directive>`. */
export const previewKey = ({ sessionId, personaId, directiveId }: ContractIds): string =>
  sessionId !== undefined ? `session:${sessionId}` : `pd:${personaId ?? ''}/${directiveId ?? ''}`

/** The stdout of a command that exited 0 untruncated, else why it did not. */
async function output($: RunnerDollar, argv: string[]): Promise<{ stdout: string } | { message: string }> {
  let result: ProcessRunResult
  try {
    result = await $.process.run(argv)
  } catch (error) {
    return { message: messageOf(error) }
  }
  if (result.exitCode !== 0) {
    return { message: firstLine(result.stderr) || firstLine(result.stdout) || `exit ${result.exitCode}` }
  }
  return result.isStdoutTruncated ? { message: TRUNCATED } : { stdout: result.stdout }
}

/** Runs `contract` then `export` for `ids` and reads both; either failing fails the preview. */
export async function loadPreview($: RunnerDollar, binary: string, ids: ContractIds): Promise<Preview> {
  // An id the CLI could read as a flag never reaches argv.
  if (!presentIds(ids).every(isValidId)) return { kind: 'failed', message: 'unsupported id' }
  const flags = flagsOf(ids)
  const contractOut = await output($, [binary, 'contract', ...flags])
  if ('message' in contractOut) return { kind: 'failed', message: contractOut.message }
  const exportOut = await output($, [binary, 'export', ...flags])
  if ('message' in exportOut) return { kind: 'failed', message: exportOut.message }
  const contract = parseContract(contractOut.stdout)
  if (contract === undefined) return { kind: 'failed', message: 'contract output was not a contract' }
  const details = parseExport(exportOut.stdout)
  if (details === undefined) return { kind: 'failed', message: 'export output was not an export' }
  return { kind: 'loaded', contract, details }
}
