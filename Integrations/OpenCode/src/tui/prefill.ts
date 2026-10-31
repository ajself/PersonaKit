import type { TuiPluginApi } from '@opencode-ai/plugin/tui'
import { logFailure } from './log.ts'
import { sanitizeLine } from './text.ts'

/**
 * Appends `text` to the prompt box, exactly as given and with no separating newline, for the person to review and
 * send; it never submits. It never reads the draft: OpenCode exposes it only to whoever owns the `session_prompt`
 * slot. When the box takes nothing (the request fails or rejects), `text` is shown as a toast to copy.
 */
export async function prefill(api: TuiPluginApi, text: string): Promise<boolean> {
  let isFilled = false
  try {
    const result = await api.client.tui.appendPrompt({ text })
    isFilled = result.error === undefined
  } catch (error) {
    logFailure(api, error, 'prompt append failed')
  }
  if (!isFilled) api.ui.toast({ variant: 'warning', message: sanitizeLine(text) })
  return isFilled
}
