import { expect, test } from 'claude-code/testing'

import { parseContract } from './lib/contract'
import { CONTRACT_JSON } from './fixtures/golden'

test('parses the golden contract', () => {
  const contract = parseContract(CONTRACT_JSON)
  expect(contract?.personaId).toBe('read-only-auditor')
  expect(contract?.directiveId).toBe('audit-pass')
  expect(contract?.sessionId).toBe('read-only-auditor_audit-pass')
  expect(contract?.isAuthorized).toBe(true)
  expect(contract?.scope.mode).toBe('project-only')
})

test('rejects non-JSON and JSON without personaId', () => {
  expect(parseContract('not json')).toBe(undefined)
  expect(parseContract('{"directiveId":"x"}')).toBe(undefined)
})
