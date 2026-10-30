import type { Plugin, PluginModule } from '@opencode-ai/plugin'
import type { PluginContext } from '@opencode-ai/plugin/v2/promise'
import { createHash } from 'node:crypto'
import { readdirSync } from 'node:fs'
import { personakitBinary } from '../../ClaudeCode/hooks/lib/runner.ts'
import {
  enforceCall,
  findManifest,
  manyReason,
  resolveExecutable,
  unreadableReason,
  unresolvedReason,
  type Enforcement,
  type ManifestFind,
} from './enforce.ts'
import { readRegularFileSync } from './regularFile.ts'
import { createSpawnRunner } from './tui/spawnRunner.ts'
import { applyV2Rules, globalConfigPaths, physicalForms, v2Rules, worktreeOf } from './v2.ts'

/** The names in `dir`; none when it is missing or not a directory. Any other error propagates. */
function listDir(dir: string): string[] {
  try {
    return readdirSync(dir)
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code
    if (code === 'ENOENT' || code === 'ENOTDIR') return []
    throw error
  }
}

/**
 * The manifest as `server` and `setup` both read it at startup: what was found, and the bytes of the one manifest.
 * A directory whose listing fails is reported as one manifest at that directory with no bytes, so it reads as
 * unreadable.
 */
function startupManifest(directory: string, worktree: string): { find: ManifestFind; bytes: Buffer | undefined } {
  let listing = directory
  let find: ManifestFind
  try {
    find = findManifest(directory, worktree, {
      list: (dir) => {
        listing = dir
        return listDir(dir)
      },
    })
  } catch {
    // `listing` is the absolute directory whose listing threw.
    return { find: { kind: 'one', path: listing, projectDir: directory }, bytes: undefined }
  }
  return { find, bytes: find.kind === 'one' ? readRegularFileSync(find.path) : undefined }
}

/** Finds the manifest, hashes it, and resolves `personakit`, once, when OpenCode starts the plugin. */
function startupEnforcement(directory: string, worktree: string, binaryName: string): Enforcement {
  const { find, bytes } = startupManifest(directory, worktree)
  if (find.kind === 'none') return { kind: 'off' }
  if (find.kind === 'many') return { kind: 'blockAll', reason: manyReason(find.paths) }
  if (bytes === undefined) return { kind: 'blockRouted', reason: unreadableReason(find.path) }
  const sha256 = createHash('sha256').update(bytes).digest('hex')
  const binary = resolveExecutable(binaryName, process.env.PATH ?? '')
  if (binary === undefined) return { kind: 'blockRouted', reason: unresolvedReason(binaryName) }
  return { kind: 'on', manifest: { path: find.path, sha256 }, binary }
}

/**
 * The enforcement hook: every tool call except a known read-only built-in goes to `personakit hook-check`, and a
 * deny throws its reason, which blocks the call and reaches the model. Options: `personakitPath` (the executable,
 * `personakit` on PATH by default). The server plugin does not use `mcpServerName`; the manifest names the trusted
 * server. It is not exported by name: a loader that walks named exports must not find a second plugin.
 */
const server: Plugin = async (input, options) => {
  const state = startupEnforcement(input.directory, input.worktree, personakitBinary(options ?? {}))
  // OpenCode's own environment (inherited) and working directory, so hook-check sees the same HOME, XDG_* and
  // OPENCODE_* values.
  const runner = createSpawnRunner({ cwd: process.cwd() })
  let configServers: string[] = []
  return {
    config: async (config) => {
      configServers = Object.keys(config.mcp ?? {})
    },
    'tool.execute.before': async (call, output) => {
      const decision = await enforceCall(state, { tool: call.tool, args: output.args }, {
        configServers: () => configServers,
        status: () => input.client.mcp.status(),
        run: runner.process.run,
        directory: input.directory,
        worktree: input.worktree,
      })
      if ('deny' in decision) throw new Error(decision.deny)
    },
  }
}

/**
 * The v2 session runner's startup hook: v2 sessions call no `tool.execute.before`, so the manifest's denials become
 * agent permission rules, read once from the directory OpenCode serves (v2 passes no directory). When edits are
 * allowed, they cover the global OpenCode config and the `personakit` executable too. A manifest change after startup
 * is not seen.
 */
const setup = async (context: PluginContext): Promise<void> => {
  const directory = process.cwd()
  const { find, bytes } = startupManifest(directory, worktreeOf(directory))
  const binary = resolveExecutable(personakitBinary(context.options ?? {}), process.env.PATH ?? '')
  const protectedPaths = [...globalConfigPaths(process.env), ...(binary === undefined ? [] : [binary])].flatMap((entry) =>
    physicalForms(entry),
  )
  await applyV2Rules(context.agent, v2Rules(find, bytes?.toString('utf8'), protectedPaths))
}

// OpenCode's v1 loader runs `server`; its v2 loader takes a default export with an `id` and a `setup`.
const plugin: PluginModule & { id: string; setup: typeof setup } = { id: 'opencode-personakit', server, setup }
export default plugin
