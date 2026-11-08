import { expect, test } from 'claude-code/testing'

import {
  CLAUDE_LOCAL_SUBAGENT_TYPES_JSON,
  CLAUDE_MCP_RESOURCE_TOOLS_JSON,
  CLAUDE_READ_ONLY_TOOLS_JSON,
  CLAUDE_SUBAGENT_TOOLS_JSON,
  CONTRACT_JSON,
  OPENCODE_READ_ONLY_TOOLS_JSON,
  OPENCODE_TOOL_ACTION_CLASSES_JSON,
  PERSONAKIT_MCP_TOOL_NAMES_JSON,
} from './fixtures/golden'
import {
  CLAUDE_HOST,
  CLAUDE_LOCAL_SUBAGENT_TYPES,
  CLAUDE_MCP_RESOURCE_TOOLS,
  CLAUDE_READ_ONLY_TOOLS,
  CLAUDE_SUBAGENT_TOOLS,
  OPENCODE_READ_ONLY_TOOLS,
  OPENCODE_TOOL_ACTION_CLASSES,
  PERSONAKIT_MCP_TOOL_NAMES,
  openCodeHost,
  sanitizeMCPName,
} from './lib/host'
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

test('claudeListsMatchSwift', () => {
  expect([...CLAUDE_READ_ONLY_TOOLS]).toEqual(JSON.parse(CLAUDE_READ_ONLY_TOOLS_JSON))
  expect([...CLAUDE_MCP_RESOURCE_TOOLS]).toEqual(JSON.parse(CLAUDE_MCP_RESOURCE_TOOLS_JSON))
  expect([...CLAUDE_SUBAGENT_TOOLS]).toEqual(JSON.parse(CLAUDE_SUBAGENT_TOOLS_JSON))
  expect([...CLAUDE_LOCAL_SUBAGENT_TYPES]).toEqual(JSON.parse(CLAUDE_LOCAL_SUBAGENT_TYPES_JSON))
  expect([...PERSONAKIT_MCP_TOOL_NAMES]).toEqual(JSON.parse(PERSONAKIT_MCP_TOOL_NAMES_JSON))
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

const resolveKey = (host: ReturnType<typeof openCodeHost>) => host.mcpToolName('personakit', 'personakit_resolve_contract')

test('openCodeTrustsAKeyOnlyWhenNoOtherServerCouldProduceIt', () => {
  const key = 'personakit_personakit_resolve_contract'
  expect(resolveKey(openCodeHost(['personakit', 'cupertino']))).toBe(key)
  expect(openCodeHost(['personakit', 'cupertino']).trustsMCPKey(key, 'personakit')).toBe(true)
  expect(openCodeHost(['personakit', 'personakit_personakit']).trustsMCPKey(key, 'personakit')).toBe(false)
  // sanitizing makes `personakit.personakit` produce the same prefix
  expect(openCodeHost(['personakit', 'personakit.personakit']).trustsMCPKey(key, 'personakit')).toBe(false)
  // a server that is not configured is not trusted
  expect(openCodeHost(['cupertino']).trustsMCPKey(key, 'personakit')).toBe(false)
  expect(openCodeHost([]).trustsMCPKey(key, 'personakit')).toBe(false)
})

test('claudeHostTrustsEveryKey', () => {
  expect(CLAUDE_HOST.trustsMCPKey('mcp__personakit__personakit_export', 'personakit')).toBe(true)
})

test('observeIgnoresAPersonaKitKeyAnotherServerCouldProduce', async () => {
  const key = 'personakit_personakit_resolve_contract'
  const call = { tool: key, input: {}, result: { text: CONTRACT_JSON } }
  const colliding = await observe(call, ['personakit'], none, openCodeHost(['personakit', 'personakit_personakit']))
  expect(colliding).toEqual([])
  const clean = await observe(call, ['personakit'], none, openCodeHost(['personakit', 'cupertino']))
  expect(clean.map((o) => o.kind)).toEqual(['contract'])
})
