import { expect, test } from 'claude-code/testing'

import { CONTRACT_JSON, OPENCODE_READ_ONLY_TOOLS_JSON, OPENCODE_TOOL_ACTION_CLASSES_JSON } from './fixtures/golden'
import { CLAUDE_HOST, OPENCODE_READ_ONLY_TOOLS, OPENCODE_TOOL_ACTION_CLASSES, openCodeHost, sanitizeMCPName } from './lib/host'
import { observe } from './lib/observe'

const none = async () => undefined

test('openCodeKeysMatchSanitizedJoin', () => {
  const host = openCodeHost(['personakit'])
  expect(host.mcpToolName('personakit', 'personakit_resolve_contract')).toBe('personakit_personakit_resolve_contract')
  expect(openCodeHost([]).mcpToolName('my server', 'a.b')).toBe('my_server_a_b')
})

test('sanitizeMCPNameReplacesEachUTF16Unit', () => {
  expect(sanitizeMCPName('a-b_C9')).toBe('a-b_C9')
  expect(sanitizeMCPName('a b.é')).toBe('a_b__')
  expect(sanitizeMCPName('😀')).toBe('__')
})

test('openCodeListsMatchSwift', () => {
  expect(OPENCODE_TOOL_ACTION_CLASSES).toEqual(JSON.parse(OPENCODE_TOOL_ACTION_CLASSES_JSON))
  expect([...OPENCODE_READ_ONLY_TOOLS]).toEqual(JSON.parse(OPENCODE_READ_ONLY_TOOLS_JSON))
})

test('isMCPToolIsAConfiguredServerPrefix', () => {
  const host = openCodeHost(['personakit', 'plan'])
  expect(host.isMCPTool('personakit_personakit_export')).toBe(true)
  expect(host.isMCPTool('plan_exit')).toBe(true) // an MCP key shadows a built-in of the same name
  expect(host.isMCPTool('bash')).toBe(false)
  expect(host.isMCPTool('personakit')).toBe(false)
  expect(openCodeHost([]).isMCPTool('personakit_x')).toBe(false)
})

test('claudeHostKeepsClaudeNames', () => {
  expect(CLAUDE_HOST.shellTool).toBe('Bash')
  expect(CLAUDE_HOST.mcpToolName('s', 't')).toBe('mcp__s__t')
  expect(CLAUDE_HOST.isMCPTool('mcp__s__t')).toBe(true)
  expect(CLAUDE_HOST.isMCPTool('Bash')).toBe(false)
  expect(CLAUDE_HOST.toolActionClasses.Edit).toBe('file-mutation')
})

test('observeReadsOpenCodeBashAndMCP', async () => {
  const host = openCodeHost(['personakit'])
  const bash = await observe(
    { tool: 'bash', input: { command: 'personakit contract --session solo-dev' }, result: { result: { stdout: CONTRACT_JSON }, text: CONTRACT_JSON } },
    ['personakit'],
    none,
    host,
  )
  expect(bash[0]?.kind).toBe('contract')
  expect(bash[0]?.source).toBe('cli')
  const mcp = await observe(
    { tool: 'personakit_personakit_resolve_contract', input: {}, result: { result: CONTRACT_JSON, text: CONTRACT_JSON } },
    ['personakit'],
    none,
    host,
  )
  expect(mcp[0]?.kind).toBe('contract')
  expect(mcp[0]?.source).toBe('mcp')
  // Claude's names mean nothing to the OpenCode host.
  expect(await observe({ tool: 'Bash', input: { command: 'personakit contract' }, result: { result: { stdout: CONTRACT_JSON } } }, ['personakit'], none, host)).toEqual([])
})
