import type { TuiPluginApi } from '@opencode-ai/plugin/tui'

/**
 * Logs a dropped failure at `debug` in OpenCode's log, for the maintainer; nothing reaches the person. `context`, when
 * given, says what failed. A log that fails, synchronously or not, is itself dropped.
 */
export function logFailure(api: TuiPluginApi, error: unknown, context?: string): void {
  try {
    const detail = error instanceof Error ? error.message : String(error)
    const message = `personakit: ${context === undefined ? '' : `${context}: `}${detail}`
    void api.client.app.log({ service: 'personakit', level: 'debug', message }).catch(() => {})
  } catch {}
}
