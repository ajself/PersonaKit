import type { ContractIds, Enforcement } from '../../../ClaudeCode/types'
import { enforcementFor } from '../../../ClaudeCode/hooks/lib/enforcement.ts'
import { homedir as accountHome } from 'node:os'
import path from 'node:path'

/**
 * Where `make opencode-install` puts the plugin: `${XDG_CACHE_HOME:-$HOME/.cache}/opencode/personakit/plugin`, made
 * absolute with `.` and `..` applied. Empty values count as unset. Without `HOME`, the home directory is `homedir()`
 * (the account's), as `globalConfigPaths` does. Undefined when neither gives a directory.
 */
export function installedPluginDirectory(
  env: Readonly<Record<string, string | undefined>>,
  homedir: () => string = accountHome,
): string | undefined {
  const value = (key: string) => (env[key] === undefined || env[key] === '' ? undefined : env[key])
  const home = value('HOME') ?? (homedir() || undefined)
  const cacheHome = value('XDG_CACHE_HOME') ?? (home === undefined ? undefined : path.join(home, '.cache'))
  return cacheHome === undefined ? undefined : path.resolve(cacheHome, 'opencode', 'personakit', 'plugin')
}

/**
 * Whether the resolved config's `plugin` list names the plugin `make opencode-install` installs: exactly
 * `file://<installedPluginDirectory>`, as a string entry or the first element of a `[spec, options]` entry, compared
 * by code units. Any other spec, an npm `opencode-personakit` or `opencode-personakit@<version>` included, does not
 * count.
 */
export function pluginListed(
  plugins: readonly (string | readonly [string, unknown])[] | undefined,
  env: Readonly<Record<string, string | undefined>> = process.env,
  homedir: () => string = accountHome,
): boolean {
  const directory = installedPluginDirectory(env, homedir)
  if (directory === undefined) return false
  const expected = `file://${directory}`
  return (plugins ?? []).some((entry) => (Array.isArray(entry) ? entry[0] : entry) === expected)
}

/**
 * What the status line may claim. No manifest is advisory. A manifest is `enforced` only when the server plugin is
 * listed, the manifest parses and it belongs to the resolved contract, the same test the Claude mod applies. Several
 * manifests arrive as `{ path: <paths joined>, text: undefined }`, which reads as an unreadable manifest, never as
 * enforced. A manifest without the plugin listed enforces nothing: it is `enforcing-other` and carries `pluginMissing`,
 * which the status line shows as a warning, and the shared core judges its drift as advisory and never re-judges it
 * to `enforced`.
 */
export function openCodeEnforcement(
  resolved: ContractIds | undefined,
  manifest: { path: string; text: string | undefined } | undefined,
  listed: boolean,
): Enforcement {
  if (manifest === undefined) return { kind: 'advisory' }
  const found = enforcementFor(resolved, { manifestPath: manifest.path, matcherTools: ['.*'] }, manifest.text)
  if (found.kind === 'advisory' || listed) return found
  return { ...found, kind: 'enforcing-other', pluginMissing: true }
}
