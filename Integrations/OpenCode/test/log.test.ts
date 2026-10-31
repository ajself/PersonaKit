import { expect, test } from 'bun:test'
import type { TuiPluginApi } from '@opencode-ai/plugin/tui'
import { logFailure } from '../src/tui/log'

const apiWith = (log: (entry: unknown) => Promise<unknown>) => ({ client: { app: { log } } }) as unknown as TuiPluginApi

test('logFailureLogsAtDebugWithItsContext', () => {
  const entries: unknown[] = []
  const api = apiWith(async (entry) => void entries.push(entry))
  logFailure(api, new Error('store gone'), 'rebuild failed')
  logFailure(api, 'plain')
  expect(entries).toEqual([
    { service: 'personakit', level: 'debug', message: 'personakit: rebuild failed: store gone' },
    { service: 'personakit', level: 'debug', message: 'personakit: plain' },
  ])
})

test('logFailureDropsALogThatFails', async () => {
  const throwing = apiWith(() => {
    throw new Error('no client')
  })
  const rejecting = apiWith(() => Promise.reject(new Error('server gone')))
  expect(() => logFailure(throwing, new Error('x'))).not.toThrow()
  expect(() => logFailure({} as TuiPluginApi, new Error('x'))).not.toThrow()
  expect(() => logFailure(throwing, Object.create(null))).not.toThrow()
  // Called bare: a rejection left unhandled fails the test once it settles.
  logFailure(rejecting, new Error('x'))
  await new Promise((resolve) => setTimeout(resolve, 0))
})
