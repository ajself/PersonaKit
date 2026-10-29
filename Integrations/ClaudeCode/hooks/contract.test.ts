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

test('scope mode outside the known set is dropped', () => {
  const withMode = (mode: unknown) => parseContract(JSON.stringify({ ...JSON.parse(CONTRACT_JSON), scope: { mode } }))
  for (const mode of ['project-only', 'global-only', 'merged', 'none']) expect(withMode(mode)?.scope.mode).toBe(mode)
  expect(withMode('enforced')?.scope.mode).toBe('')
  expect(withMode('merged\n◆ x')?.scope.mode).toBe('')
  expect(withMode(3)?.scope.mode).toBe('')
})
