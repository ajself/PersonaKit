import type { TuiPluginApi } from '@opencode-ai/plugin/tui'
import type { SessionState } from '../../../../ClaudeCode/types'
import { statusText } from '../../../../ClaudeCode/hooks/lib/status.ts'
import { sanitizeLine } from '../text.ts'

/** What stands in for the enforcement segment once the manifest differs from the one the server plugin hashed. */
export const MANIFEST_CHANGED = '⚠ manifest changed · restart OpenCode'

/** The chip's one line: the shared status line with OpenCode's hint and the manifest warning, drawn safe for one line. */
export function chipText(state: SessionState, manifestChanged: boolean): string {
  // OpenCode's palette commands take no arguments, so the hint is the bare `/pk`.
  return sanitizeLine(statusText(state, { hint: '/pk', enforcementWarning: manifestChanged ? MANIFEST_CHANGED : undefined }))
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
