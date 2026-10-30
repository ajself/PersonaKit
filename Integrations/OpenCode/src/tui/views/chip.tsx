import type { TuiPluginApi } from '@opencode-ai/plugin/tui'
import type { SessionState } from '../../../../ClaudeCode/types'
import { statusText } from '../../../../ClaudeCode/hooks/lib/status.ts'
import { sanitizeLine } from '../text.ts'

/** What stands in for the enforcement segment once the manifest differs from the one the server plugin hashed. */
export const MANIFEST_CHANGED = '⚠ manifest changed · restart OpenCode'

// The shared line's hint names the mod's `/pk use <session>`; OpenCode's palette commands take no arguments.
const MOD_HINT = '◇ no contract · /pk use <session>'
const HINT = '◇ no contract · /pk'
const ENFORCING = '⚠ enforcing '

/**
 * The shared status line with `MANIFEST_CHANGED` in place of its enforcement segment. The line is drawn twice with a
 * stand-in contract id of the warning's length, once in `a`s and once in `b`s: the two differ only inside the
 * stand-in, so the first difference locates the segment exactly, whatever observed text surrounds it, and the line
 * fits or is cut the same as it would with the warning itself.
 */
function withManifestChanged(state: SessionState): string {
  const width = MANIFEST_CHANGED.length - ENFORCING.length
  const drawn = (letter: string) =>
    statusText({
      ...state,
      enforcement: { kind: 'enforcing-other', manifestPath: '', ids: { sessionId: letter.repeat(width) }, deniedActionClasses: [], matcherTools: [] },
    })
  const a = drawn('a')
  const b = drawn('b')
  let at = 0
  while (at < a.length && a[at] === b[at]) at += 1
  // The shared line always keeps its enforcement segment; should that ever fail, the warning stands alone.
  if (at === a.length) return MANIFEST_CHANGED
  return `${a.slice(0, at - ENFORCING.length)}${MANIFEST_CHANGED}${a.slice(at + width)}`
}

/** The chip's one line: the shared status line, OpenCode's hint, the manifest warning, drawn safe for one line. */
export function chipText(state: SessionState, manifestChanged: boolean): string {
  const line = manifestChanged ? withManifestChanged(state) : statusText(state)
  return sanitizeLine(line.startsWith(MOD_HINT) ? `${HINT}${line.slice(MOD_HINT.length)}` : line)
}

/** The status chip beside the prompt: warning-colored while it carries a `⚠`, muted otherwise. */
export function Chip(props: { api: TuiPluginApi; text: string }) {
  const theme = () => props.api.theme.current
  return (
    <text fg={props.text.includes('⚠') ? theme().warning : theme().textMuted} wrapMode="none">
      {props.text}
    </text>
  )
}
