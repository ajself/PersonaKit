import type { AgentHooks, Reload } from '@opencode-ai/plugin/v2/promise'
import { lstatSync, realpathSync } from 'node:fs'
import { homedir as accountHome } from 'node:os'
import path from 'node:path'
import { isMissing, type ManifestFind } from './enforce.ts'

// OpenCode 1.19.5's v2 session runner (`/api/session/*`) calls no plugin hooks. Its built-ins assert the agent's
// permission rules instead (`PermissionV2.assert`): `bash` under `bash`, `edit`/`write`/`apply_patch` under `edit`,
// `webfetch` and `websearch` under their own names. The last rule whose action and resource both match wins, and a
// tool whose last matching rule is a deny on `*` is dropped from the model's tool list. Matching is a case-sensitive
// whole-string glob after `\` becomes `/`: `*` is any run of characters, `/` included, and `?` is any one character.
//
// `edit` asserts the write target as OpenCode resolves it: the realpath of the target, or of its deepest existing
// ancestor with the rest as spelled; relative to the session's directory (also realpathed) when inside it, else
// absolute. MCP and plugin tools are not registered with the v2 runner, so there is nothing more to deny.
//
// The rules are derived once, at startup, from the manifest the server plugin reads. Nothing here writes a file.

export type V2Rule = { action: string; resource: string; effect: 'deny' }

const deny = (action: string, resource: string): V2Rule => ({ action, resource, effect: 'deny' })

/** The v2 permission actions each action class covers. */
const CLASS_ACTIONS: readonly (readonly [actionClass: string, actions: readonly string[]])[] = [
  ['command-execution', ['bash']],
  ['file-mutation', ['edit']],
  ['network-egress', ['webfetch', 'websearch']],
]

const ALL_ACTIONS = CLASS_ACTIONS.flatMap(([, actions]) => actions)

/** The config names OpenCode reads in any directory of the worktree, and the directory it loads plugins from. */
const PROTECTED_NAMES = ['opencode.json', 'opencode.jsonc', 'tui.json', 'tui.jsonc']
const PROTECTED_DIRECTORY = '.opencode'

// `edit` resources for the worktree's enforcement files, at the session's directory or below it. The forms with a
// leading `*` and `/` also match an absolute resource, so these names are protected outside the worktree too.
const WORKTREE_RESOURCES = [PROTECTED_DIRECTORY, `${PROTECTED_DIRECTORY}/*`, ...PROTECTED_NAMES].flatMap((resource) => [
  resource,
  `*/${resource}`,
])

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value)

/**
 * The action classes the manifest's hook checks deny, as `ChecksManifest.hookCheck(denying:)` reads them; `undefined`
 * for text that is not a manifest (not JSON, no `personaId` or `checks`, or a check without a `maxClass` and a
 * `rule` with a `kind`, or with `deniedActionClasses` that are not strings).
 */
function deniedClasses(text: string): Set<string> | undefined {
  let parsed: unknown
  try {
    parsed = JSON.parse(text)
  } catch {
    return undefined
  }
  if (!isRecord(parsed) || typeof parsed.personaId !== 'string' || !Array.isArray(parsed.checks)) return undefined
  const denied = new Set<string>()
  for (const check of parsed.checks) {
    if (!isRecord(check) || typeof check.maxClass !== 'string') return undefined
    const rule = check.rule
    if (!isRecord(rule) || typeof rule.kind !== 'string') return undefined
    const classes = rule.deniedActionClasses
    if (classes === undefined || classes === null) continue
    if (!Array.isArray(classes) || !classes.every((name) => typeof name === 'string')) return undefined
    if (check.maxClass === 'hook') for (const name of classes) denied.add(name)
  }
  return denied
}

/**
 * `edit` resources for absolute protected paths: an entry ending in `/` is a directory and everything in it.
 * OpenCode's matcher has no escape syntax, so a literal `*` or `?` in a real path only widens the match (fail-safe):
 * do not try to escape it.
 */
function pathResources(entries: readonly string[]): string[] {
  return entries.flatMap((entry) => {
    if (!entry.endsWith('/')) return [entry]
    const directory = entry.replace(/\/+$/, '') || '/'
    return [directory, path.join(directory, '*')]
  })
}

const byActionThenResource = (a: V2Rule, b: V2Rule) =>
  a.action < b.action ? -1 : a.action > b.action ? 1 : a.resource < b.resource ? -1 : a.resource > b.resource ? 1 : 0

/**
 * The deny rules v2 sessions get from the manifest, sorted and deduplicated. No manifest gives none. Several
 * manifests, or one that cannot be read or parsed, deny every contract tool. Otherwise each denied class denies its
 * actions on `*`, and when file mutation is allowed, `edit` is denied on the enforcement files: the worktree's
 * `.opencode` trees and config files, and `protectedPaths` (absolute; an entry ending in `/` is a directory).
 */
export function v2Rules(find: ManifestFind, manifestText: string | undefined, protectedPaths: readonly string[] = []): V2Rule[] {
  if (find.kind === 'none') return []
  const denied = find.kind === 'one' && manifestText !== undefined ? deniedClasses(manifestText) : undefined
  const rules =
    denied === undefined
      ? ALL_ACTIONS.map((action) => deny(action, '*'))
      : CLASS_ACTIONS.flatMap(([actionClass, actions]) => (denied.has(actionClass) ? actions.map((action) => deny(action, '*')) : []))
  if (denied !== undefined && !denied.has('file-mutation')) {
    for (const resource of [...WORKTREE_RESOURCES, ...pathResources(protectedPaths)]) rules.push(deny('edit', resource))
  }
  const unique = new Map(rules.map((rule) => [`${rule.action}\u0000${rule.resource}`, rule]))
  return [...unique.values()].sort(byActionThenResource)
}

/**
 * The global OpenCode config locations, as `OpenCodeEnforcement.globalConfigPaths` lists them: sorted, deduplicated,
 * made absolute; an entry ending in `/` is a directory. Empty values count as unset. Without `HOME`, the home
 * directory is `homedir()` (the account's, from the passwd database), which OpenCode uses then, as `hook-check` does.
 */
export function globalConfigPaths(
  env: Readonly<Record<string, string | undefined>>,
  homedir: () => string = accountHome,
): string[] {
  const value = (key: string) => (env[key] === undefined || env[key] === '' ? undefined : env[key])
  const directory = (dir: string) => `${path.resolve(dir).replace(/\/+$/, '')}/`
  const home = value('HOME') ?? (homedir() || undefined)
  const entries: string[] = []
  const configDir = value('OPENCODE_CONFIG_DIR')
  if (configDir !== undefined) entries.push(directory(configDir))
  for (const key of ['OPENCODE_CONFIG', 'OPENCODE_TUI_CONFIG']) {
    const file = value(key)
    if (file !== undefined) entries.push(path.resolve(file))
  }
  const configHome = value('XDG_CONFIG_HOME') ?? (home === undefined ? undefined : path.join(home, '.config'))
  if (configHome !== undefined) entries.push(directory(path.join(configHome, 'opencode')))
  const cacheHome = value('XDG_CACHE_HOME') ?? (home === undefined ? undefined : path.join(home, '.cache'))
  if (cacheHome !== undefined) entries.push(directory(path.join(cacheHome, 'opencode')))
  if (home !== undefined) entries.push(directory(path.join(home, '.opencode')))
  return [...new Set(entries)].sort()
}

/**
 * `entry` as spelled and as OpenCode resolves a write target there: the realpath of the deepest existing ancestor,
 * with the rest as spelled. Sorted, without repeats. Only the spelling when resolution fails another way (a loop).
 */
export function physicalForms(entry: string, realpath: (file: string) => string = realpathSync): string[] {
  const isDirectory = entry.endsWith('/')
  const spelled = path.resolve(entry)
  let ancestor = spelled
  let resolved: string | undefined
  for (;;) {
    try {
      resolved = path.join(realpath(ancestor), path.relative(ancestor, spelled))
      break
    } catch (error) {
      const parent = path.dirname(ancestor)
      if (!isMissing(error) || parent === ancestor) break
      ancestor = parent
    }
  }
  const forms = resolved === undefined ? [spelled] : [spelled, resolved]
  return [...new Set(forms.map((form) => (isDirectory ? `${form.replace(/\/+$/, '')}/` : form)))].sort()
}

/** The nearest ancestor of `directory` (itself included) holding a `.git` entry, OpenCode's worktree; else `/`. */
export function worktreeOf(directory: string, exists: (file: string) => boolean = entryExists): string {
  let dir = path.resolve(directory)
  for (;;) {
    if (exists(path.join(dir, '.git'))) return dir
    const parent = path.dirname(dir)
    if (parent === dir) return '/'
    dir = parent
  }
}

function entryExists(file: string): boolean {
  try {
    lstatSync(file)
    return true
  } catch {
    return false
  }
}

/**
 * Appends `rules` after every agent's own, so they win, and reloads the agents so sessions see them. OpenCode runs
 * the transform again on every later reload. No rules registers nothing.
 */
export async function applyV2Rules(agent: AgentHooks & Reload, rules: readonly V2Rule[]): Promise<void> {
  if (rules.length === 0) return
  await agent.transform((draft) => {
    for (const { id } of draft.list()) {
      draft.update(id, (info) => {
        info.permissions.push(...rules.map((rule) => ({ ...rule })))
      })
    }
  })
  await agent.reload()
}
