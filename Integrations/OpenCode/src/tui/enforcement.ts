import type { ContractIds, Enforcement } from '../../../ClaudeCode/types'
import { enforcementFor } from '../../../ClaudeCode/hooks/lib/enforcement.ts'

const PACKAGE = 'opencode-personakit'
// What may follow `@`: a version or a dist-tag, never an alias, path, URL or git spec.
const VERSION_OR_TAG = /^[A-Za-z0-9][A-Za-z0-9.+_-]*$/

/**
 * Whether the resolved config's `plugin` list names this package: the bare name or `name@<version or dist-tag>`, as a
 * string entry or the first element of a `[spec, options]` entry. A `file://` path, a scoped name and a longer name
 * that merely starts with this one (`opencode-personakit-evil`) do not count.
 */
export function pluginListed(plugins: readonly (string | readonly [string, unknown])[] | undefined): boolean {
  return (plugins ?? []).some((entry) => {
    const spec: unknown = Array.isArray(entry) ? entry[0] : entry
    return typeof spec === 'string' && (spec === PACKAGE || (spec.startsWith(`${PACKAGE}@`) && VERSION_OR_TAG.test(spec.slice(PACKAGE.length + 1))))
  })
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
