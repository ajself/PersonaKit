import { expect, test } from 'bun:test'
import type { TuiPluginApi, TuiPromptRef, TuiToast } from '@opencode-ai/plugin/tui'
import { prefill } from '../src/tui/prefill'

/** Only what `prefill` may touch: `client.tui.appendPrompt`, `client.app.log` and `ui.toast`. A prompt ref whose submit throws. */
function fakeApi(append: (input: { text?: string }) => Promise<unknown>) {
  const toasts: TuiToast[] = []
  const logged: { level?: string; message?: string }[] = []
  const prompt = {
    submit() {
      throw new Error('prefill must never submit')
    },
  } as unknown as TuiPromptRef
  const api = {
    client: { tui: { appendPrompt: append }, app: { log: async (entry: (typeof logged)[number]) => void logged.push(entry) } },
    ui: { toast: (toast: TuiToast) => void toasts.push(toast) },
    prompt,
  } as unknown as TuiPluginApi
  return { api, toasts, logged }
}

test('prefillAppendsTextAsIs', async () => {
  const calls: unknown[] = []
  const { api, toasts } = fakeApi(async (input) => {
    calls.push(input)
    return { data: true, error: undefined }
  })
  expect(await prefill(api, 'x')).toBe(true)
  expect(calls).toEqual([{ text: 'x' }])
  expect(toasts).toEqual([])
})

test('prefillNeverSubmits', async () => {
  const recorded: string[] = []
  const { api } = fakeApi(async (input) => {
    recorded.push(input.text ?? '')
    return { data: true, error: undefined }
  })
  const text = 'Ground this session in the contract for PersonaKit session `solo-dev`.'
  expect(await prefill(api, text)).toBe(true)
  expect(recorded).toEqual([text])
})

test('prefillToastsTheTextWhenTheRequestFails', async () => {
  const { api, toasts } = fakeApi(async () => ({ data: undefined, error: { message: 'no tui' } }))
  expect(await prefill(api, 'ground me')).toBe(false)
  expect(toasts).toEqual([{ variant: 'warning', message: 'ground me' }])
})

test('prefillToastsTheTextWhenTheRequestRejects', async () => {
  const { api, toasts, logged } = fakeApi(async () => {
    throw new Error('connection refused')
  })
  expect(await prefill(api, 'ground\u001b[2J me')).toBe(false)
  expect(toasts).toEqual([{ variant: 'warning', message: 'ground[2J me' }])
  expect(logged.map((entry) => [entry.level, entry.message])).toEqual([['debug', 'personakit: prompt append failed: connection refused']])
})
