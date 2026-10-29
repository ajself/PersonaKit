import { accessSync, constants, statSync } from 'node:fs'
import path from 'node:path'
import { OPENCODE_READ_ONLY_TOOLS, openCodeHost } from '../../ClaudeCode/hooks/lib/host.ts'
import type { ProcessRunResult, RunnerDollar } from '../../ClaudeCode/hooks/lib/runner.ts'

// The enforcement logic of the server plugin, with the file system, the process runner and the MCP status lookup
// injected. `server.ts` wires the real ones. Nothing here writes a file or logs a tool call's arguments.

const MANIFEST_DIR = path.join('.opencode', 'personakit')
const MANIFEST_SUFFIX = '.checks.json'
const PREFIX = 'Blocked by PersonaKit contract:'

export type ManifestFind = { kind: 'none' } | { kind: 'one'; path: string; projectDir: string } | { kind: 'many'; paths: string[] }

/** What the plugin enforces, settled once at startup. */
export type Enforcement =
  | { kind: 'off' } // no manifest: the plugin does nothing
  | { kind: 'blockAll'; reason: string } // more than one manifest: every call is denied
  | { kind: 'blockRouted'; reason: string } // a manifest that cannot be checked: every routed call is denied
  | { kind: 'on'; manifest: { path: string; sha256: string }; binary: string }

export type Decision = { deny: string } | { allow: true }

export type HookCheckBody = { tool: string; paths: string[]; mcpServers: string[]; directory: string; worktree: string }

/** What `mcp.status()` resolves to: the SDK's `{ data, error }` result, typed loosely so a fake can stand in. */
export type StatusLookup = () => Promise<unknown>

const sortedUnique = (names: Iterable<string>) => [...new Set(names)].sort()

/** C0, C1 and DEL removed, so a file name cannot draw or move anything where the reason is shown. */
const printable = (text: string) => text.replace(/[\u0000-\u001f\u007f-\u009f]/g, '')

/**
 * Every `*.checks.json` in each `.opencode/personakit/` from `directory` up to `worktree` (or the file system root),
 * the same walk OpenCode makes for its config directories. A listing error other than "not there" propagates.
 */
export function findManifest(directory: string, worktree: string, fs: { list(dir: string): string[] }): ManifestFind {
  const stop = path.resolve(worktree)
  const found: { path: string; projectDir: string }[] = []
  let dir = path.resolve(directory)
  for (;;) {
    const manifestDir = path.join(dir, MANIFEST_DIR)
    for (const name of fs.list(manifestDir)) {
      if (name.endsWith(MANIFEST_SUFFIX)) found.push({ path: path.join(manifestDir, name), projectDir: dir })
    }
    const parent = path.dirname(dir)
    if (dir === stop || parent === dir) break
    dir = parent
  }
  if (found.length === 0) return { kind: 'none' }
  if (found.length === 1) return { kind: 'one', ...found[0]! }
  return { kind: 'many', paths: found.map((entry) => entry.path).sort() }
}

/** The deny reason for more than one manifest, naming each one. */
export const manyReason = (paths: readonly string[]): string =>
  `${PREFIX} more than one enforcement manifest in .opencode/personakit/: ${paths.map(printable).join(', ')}`

const PATCH_HEADERS = ['*** Add File:', '*** Update File:', '*** Delete File:', '*** Move to:']

/**
 * The file paths an `apply_patch` touches: each Add, Update and Delete File header and each Move to, in order.
 * Lines split on LF only, as OpenCode splits them: a lone CR stays inside the path, where OpenCode keeps it too.
 * Every line is read trimmed (which also drops a CRLF's CR), finding at least the headers OpenCode applies (it
 * strips a heredoc wrapper and matches headers by prefix).
 */
export function patchPaths(patchText: string): string[] {
  const paths: string[] = []
  for (const raw of patchText.split('\n')) {
    const line = raw.trim()
    const header = PATCH_HEADERS.find((prefix) => line.startsWith(prefix))
    if (header === undefined) continue
    const target = line.slice(header.length).trim()
    if (target !== '') paths.push(target)
  }
  return paths
}

const field = (args: unknown, key: string): unknown =>
  typeof args === 'object' && args !== null ? (args as Record<string, unknown>)[key] : undefined

/** The paths a call touches, absolute the way OpenCode makes them. */
function callPaths(tool: string, args: unknown, directory: string): string[] {
  if (tool === 'edit' || tool === 'write') {
    const filePath = field(args, 'filePath')
    if (typeof filePath !== 'string') return []
    // An absolute path stays raw: the kernel follows a symlink before `..`, and so does the evaluator.
    return [path.isAbsolute(filePath) ? filePath : path.join(directory, filePath)]
  }
  if (tool === 'apply_patch') {
    const patchText = field(args, 'patchText')
    return typeof patchText === 'string' ? patchPaths(patchText).map((p) => path.resolve(directory, p)) : []
  }
  return []
}

/** The JSON `hook-check --host opencode` reads. A call whose parsing finds nothing still goes, with no paths. */
export function payload(
  tool: string,
  args: unknown,
  mcpServers: readonly string[],
  directory: string,
  worktree: string,
): HookCheckBody {
  return { tool, paths: callPaths(tool, args, directory), mcpServers: sortedUnique(mcpServers), directory, worktree }
}

/** Every tool goes to `hook-check` except a known read-only built-in that no MCP server's prefix claims. */
export const routes = (tool: string, mcpServers: readonly string[]): boolean =>
  !OPENCODE_READ_ONLY_TOOLS.includes(tool) || openCodeHost(mcpServers).isMCPTool(tool)

/**
 * The configured MCP server names joined with the live ones from `mcp.status()`, sorted; `undefined` when the
 * lookup rejects, reports an error, or gives no object of servers.
 */
export async function liveServers(configServers: readonly string[], status: StatusLookup): Promise<string[] | undefined> {
  let result: unknown
  try {
    result = await status()
  } catch {
    return undefined
  }
  if (typeof result !== 'object' || result === null) return undefined
  const { data, error } = result as { data?: unknown; error?: unknown }
  if (error !== undefined || typeof data !== 'object' || data === null || Array.isArray(data)) return undefined
  return sortedUnique([...configServers, ...Object.keys(data)])
}

const firstLine = (text: string) => printable(text.trim().split('\n')[0]?.slice(0, 200) ?? '')

/** Reads `{"decision":"deny","reason":"…"}` exactly; anything else is `undefined`. */
function denyReason(stdout: string): string | undefined {
  let parsed: unknown
  try {
    parsed = JSON.parse(stdout)
  } catch {
    return undefined
  }
  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) return undefined
  const keys = Object.keys(parsed).sort()
  const { decision, reason } = parsed as { decision?: unknown; reason?: unknown }
  if (keys.length !== 2 || keys[0] !== 'decision' || keys[1] !== 'reason') return undefined
  return decision === 'deny' && typeof reason === 'string' && reason !== '' ? reason : undefined
}

/**
 * Runs `hook-check` on `body` against the manifest hashed at startup. It allows only on exit 0 with empty stdout;
 * a run that rejects, a nonzero exit (a signal included), truncated or unreadable output is a deny.
 */
export async function check(
  run: RunnerDollar['process']['run'],
  binary: string,
  manifest: { path: string; sha256: string },
  body: HookCheckBody,
): Promise<Decision> {
  const argv = [binary, 'hook-check', '--host', 'opencode', '--manifest', manifest.path, '--expect-sha256', manifest.sha256]
  let result: ProcessRunResult
  try {
    // A plain object through JSON.stringify: Foundation keeps the first duplicate key and JS the last, so the body
    // is never built by concatenation.
    result = await run(argv, { stdin: JSON.stringify(body) })
  } catch (error) {
    const detail = firstLine(error instanceof Error ? error.message : String(error))
    return { deny: `${PREFIX} could not run personakit hook-check (${detail})` }
  }
  if (result.exitCode !== 0) return { deny: `${PREFIX} could not run personakit hook-check (exit ${result.exitCode})` }
  if (result.isStdoutTruncated) return { deny: `${PREFIX} personakit hook-check gave an unreadable answer` }
  if (result.stdout.trim() === '') return { allow: true }
  const reason = denyReason(result.stdout)
  return { deny: reason ?? `${PREFIX} personakit hook-check gave an unreadable answer` }
}

/** One `tool.execute.before` call, decided. */
export async function enforceCall(
  state: Enforcement,
  call: { tool: string; args: unknown },
  ctx: {
    configServers: () => readonly string[]
    status: StatusLookup
    run: RunnerDollar['process']['run']
    directory: string
    worktree: string
  },
): Promise<Decision> {
  if (state.kind === 'off') return { allow: true }
  if (state.kind === 'blockAll') return { deny: state.reason }
  // The server list decides routing (an MCP tool can shadow a read-only built-in), so it is read first, every call.
  const servers = await liveServers(ctx.configServers(), ctx.status)
  if (servers === undefined) return { deny: `${PREFIX} could not list MCP servers, so no tool call can be checked` }
  if (!routes(call.tool, servers)) return { allow: true }
  if (state.kind === 'blockRouted') return { deny: state.reason }
  return check(ctx.run, state.binary, state.manifest, payload(call.tool, call.args, servers, ctx.directory, ctx.worktree))
}

/** True for an existing regular file (after symlinks) this process may execute. */
export function isExecutableFile(file: string): boolean {
  try {
    if (!statSync(file).isFile()) return false
    accessSync(file, constants.X_OK)
    return true
  } catch {
    return false
  }
}

/**
 * The absolute executable `name` names: itself when absolute, else the first match on `pathEnv`'s absolute entries.
 * A relative name with a separator is not looked up, and nothing resolves against the current directory.
 */
export function resolveExecutable(
  name: string,
  pathEnv: string,
  isExecutable: (file: string) => boolean = isExecutableFile,
): string | undefined {
  if (path.isAbsolute(name)) return isExecutable(name) ? name : undefined
  if (name === '' || name.includes('/')) return undefined
  for (const dir of pathEnv.split(path.delimiter)) {
    if (!path.isAbsolute(dir)) continue
    const candidate = path.join(dir, name)
    if (isExecutable(candidate)) return candidate
  }
  return undefined
}

/** The reason every routed call gets when the `personakitPath` option does not name a runnable executable. */
export const unresolvedReason = (name: string): string =>
  `${PREFIX} could not run personakit: ${printable(name)} is not an executable file or on PATH; restart OpenCode after fixing it`

/** The reason every routed call gets when the manifest could not be read or hashed at startup. */
export const unreadableReason = (where: string): string =>
  `${PREFIX} could not read the enforcement manifest at ${printable(where)} when OpenCode started; restart OpenCode`
