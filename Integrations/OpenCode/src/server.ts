import type { Plugin, PluginModule } from '@opencode-ai/plugin'
import { createHash } from 'node:crypto'
import { readdirSync, readFileSync } from 'node:fs'
import { personakitBinary } from '../../ClaudeCode/hooks/lib/runner.ts'
import {
  enforceCall,
  findManifest,
  manyReason,
  resolveExecutable,
  unreadableReason,
  unresolvedReason,
  type Enforcement,
} from './enforce.ts'
import { createSpawnRunner } from './tui/spawnRunner.ts'

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

/** Finds the manifest, hashes it, and resolves `personakit`, once, when OpenCode starts the plugin. */
function startupEnforcement(directory: string, worktree: string, binaryName: string): Enforcement {
  let found
  let listing = directory
  try {
    found = findManifest(directory, worktree, {
      list: (dir) => {
        listing = dir
        return listDir(dir)
      },
    })
  } catch {
    // `listing` is the absolute directory whose listing threw.
    return { kind: 'blockRouted', reason: unreadableReason(listing) }
  }
  if (found.kind === 'none') return { kind: 'off' }
  if (found.kind === 'many') return { kind: 'blockAll', reason: manyReason(found.paths) }
  let sha256: string
  try {
    sha256 = createHash('sha256').update(readFileSync(found.path)).digest('hex')
  } catch {
    return { kind: 'blockRouted', reason: unreadableReason(found.path) }
  }
  const binary = resolveExecutable(binaryName, process.env.PATH ?? '')
  if (binary === undefined) return { kind: 'blockRouted', reason: unresolvedReason(binaryName) }
  return { kind: 'on', manifest: { path: found.path, sha256 }, binary }
}

/**
 * The enforcement hook: every tool call except a known read-only built-in goes to `personakit hook-check`, and a
 * deny throws its reason, which blocks the call and reaches the model. Options: `personakitPath` (the executable,
 * `personakit` on PATH by default); `mcpServerName` is accepted for messages and changes nothing here. It is not
 * exported by name: a loader that walks named exports must not find a second plugin.
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

const plugin: PluginModule & { id: string } = { id: 'opencode-personakit', server }
export default plugin
