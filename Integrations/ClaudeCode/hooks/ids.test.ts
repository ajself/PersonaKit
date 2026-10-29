import { expect, test } from 'claude-code/testing'

import { CONTRACT_JSON, EXPORT_MD } from './fixtures/golden'
import { canUse, isValidId, presentIds } from './lib/ids'
import { loadPreview } from './lib/runner'

test('invalidIdsNeverReachArgv', async () => {
  expect(isValidId('-x')).toBe(false)
  expect(isValidId('a b')).toBe(false)
  expect(isValidId('a\u001b')).toBe(false)
  expect(isValidId('')).toBe(false)
  expect(isValidId('solo-dev_1.x')).toBe(true)
  let calls = 0
  const $ = {
    process: {
      run: async () => {
        calls++
        return { exitCode: 0, stdout: CONTRACT_JSON + EXPORT_MD, stderr: '' }
      },
    },
  }
  for (const ids of [{ sessionId: '-x' }, { personaId: 'p', directiveId: 'a b' }, { personaId: 'a\u001b' }]) {
    expect(await loadPreview($, 'personakit', ids)).toEqual({ kind: 'failed', message: 'unsupported id' })
  }
  expect(calls).toBe(0)
})

test('canUseNeedsOnePresentAndAllValid', () => {
  expect(canUse({})).toBe(false)
  expect(canUse({ sessionId: 's' })).toBe(true)
  expect(canUse({ personaId: 'p', directiveId: 'd' })).toBe(true)
  expect(canUse({ personaId: 'p', directiveId: '-d' })).toBe(false)
  expect(canUse({ sessionId: 'bad id' })).toBe(false)
})

test('presentIdsListsEveryDefinedId', () => {
  expect(presentIds({})).toEqual([])
  expect(presentIds({ sessionId: 's', directiveId: 'd' })).toEqual(['s', 'd'])
  expect(presentIds({ personaId: '' })).toEqual([''])
})
