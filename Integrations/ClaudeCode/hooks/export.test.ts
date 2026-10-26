import { expect, test } from 'claude-code/testing'

import { parseExport } from './lib/export'
import { EXPORT_MD } from './fixtures/golden'

test('parses the golden export', () => {
  const details = parseExport(EXPORT_MD)
  expect(details?.personaName).toBe('Read-Only Auditor')
  expect(details?.personaId).toBe('read-only-auditor')
  expect(details?.directiveTitle).toBe('Read-only audit pass')
  expect(details?.directiveId).toBe('audit-pass')
  expect(details?.steps.length).toBe(2)
  expect(details?.steps[1]).toEqual({ text: 'Report confirmed issues before suggestions.', isStop: true })
  expect(details?.steps[0]?.isStop).toBe(false)
  expect(details?.deniedActionClasses).toEqual(['command-execution', 'file-mutation', 'network-egress'])
})

test('ignores a skill body that embeds a Directive section', () => {
  const decoy = '# Expanded Skills\n## decoy\n# Directive\nTitle: Decoy\nId: decoy\nSteps:\n1. decoy step\n'
  const marker = '# Directive\nTitle: Read-only audit pass'
  expect(EXPORT_MD.includes(marker)).toBe(true)
  const poisoned = EXPORT_MD.replace(marker, decoy + marker)
  expect(parseExport(poisoned)).toEqual(parseExport(EXPORT_MD))
})

test('finds the version header after leading lines', () => {
  expect(parseExport('Building...\n' + EXPORT_MD)?.personaId).toBe('read-only-auditor')
  expect(parseExport('# Persona\nId: x\n')).toBe(undefined)
})
