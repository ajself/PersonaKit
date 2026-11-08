/**
 * What differs between hosts in the shared core: how tools are named and which action class each one performs.
 * Claude Code's names are the default everywhere; the OpenCode plugin passes `openCodeHost(...)`.
 */
export type Host = {
  shellTool: string
  mcpToolName: (server: string, tool: string) => string
  isMCPTool: (tool: string) => boolean
  /** Whether a PersonaKit tool key from `server` can be trusted: no other configured server could have produced it. */
  trustsMCPKey: (key: string, server: string) => boolean
  toolActionClasses: Readonly<Record<string, string>>
  /** Unclassified built-ins the checker allows; any other built-in it cannot classify is asked about or denied. */
  readOnlyTools: readonly string[]
  /** Built-ins allowed only against a trusted PersonaKit server named in their `server` input. */
  mcpResourceTools: readonly string[]
  /** Read-only built-ins that start a subagent, allowed only for a `localSubagentTypes` type with no `isolation`. */
  subagentTools: readonly string[]
  localSubagentTypes: readonly string[]
}

/** Mirror of `ClaudeCodeEnforcement.toolActionClasses`, flattened; a golden test keeps it equal to the Swift map. */
export const TOOL_ACTION_CLASSES: Record<string, string> = {
  Edit: 'file-mutation',
  Write: 'file-mutation',
  NotebookEdit: 'file-mutation',
  Bash: 'command-execution',
  Monitor: 'command-execution',
  PowerShell: 'command-execution',
  WebFetch: 'network-egress',
  WebSearch: 'network-egress',
}

/** Mirror of `ClaudeCodeEnforcement.readOnlyTools`, sorted; a golden test keeps it equal to the Swift list. */
export const CLAUDE_READ_ONLY_TOOLS: readonly string[] = [
  'Agent', 'AskUserQuestion', 'EnterPlanMode', 'ExitPlanMode', 'Glob', 'Grep', 'ListAgents', 'Read', 'Task',
  'TaskCreate', 'TaskGet', 'TaskList', 'TaskOutput', 'TaskUpdate', 'TodoWrite', 'ToolSearch',
]

/** Mirror of `ClaudeCodeEnforcement.mcpResourceTools`, sorted; a golden test keeps it equal to the Swift set. */
export const CLAUDE_MCP_RESOURCE_TOOLS: readonly string[] = ['ListMcpResourcesTool', 'ReadMcpResourceDirTool', 'ReadMcpResourceTool']

/** Mirror of `ClaudeCodeEnforcement.subagentTools`, sorted; a golden test keeps it equal to the Swift set. */
export const CLAUDE_SUBAGENT_TOOLS: readonly string[] = ['Agent', 'Task']

/** Mirror of `ClaudeCodeEnforcement.localSubagentTypes`, sorted; a golden test keeps it equal to the Swift set. */
export const CLAUDE_LOCAL_SUBAGENT_TYPES: readonly string[] = [
  'Explore', 'Plan', 'claude-code-guide', 'fork', 'general-purpose', 'statusline-setup',
]

/** Mirror of `ClaudeCodeEnforcement.personaKitMCPToolNames`: PersonaKit's own read-only MCP tools, on both hosts. */
export const PERSONAKIT_MCP_TOOL_NAMES: readonly string[] = [
  'personakit_best_guidance', 'personakit_compare_entities', 'personakit_explain_entity', 'personakit_export',
  'personakit_graph', 'personakit_recommend_session', 'personakit_resolve_contract',
  'personakit_resolve_grounding_skills', 'personakit_resolve_session_ref', 'personakit_trace_session',
  'personakit_validate',
]

export const CLAUDE_HOST: Host = {
  shellTool: 'Bash',
  mcpToolName: (server, tool) => `mcp__${server}__${tool}`,
  isMCPTool: (tool) => tool.startsWith('mcp__'),
  trustsMCPKey: () => true,
  toolActionClasses: TOOL_ACTION_CLASSES,
  readOnlyTools: CLAUDE_READ_ONLY_TOOLS,
  mcpResourceTools: CLAUDE_MCP_RESOURCE_TOOLS,
  subagentTools: CLAUDE_SUBAGENT_TOOLS,
  localSubagentTypes: CLAUDE_LOCAL_SUBAGENT_TYPES,
}

/** Mirror of `OpenCodeEnforcement.toolActionClasses`, flattened; a golden test keeps it equal to the Swift map. */
export const OPENCODE_TOOL_ACTION_CLASSES: Readonly<Record<string, string>> = {
  apply_patch: 'file-mutation',
  edit: 'file-mutation',
  write: 'file-mutation',
  bash: 'command-execution',
  webfetch: 'network-egress',
  websearch: 'network-egress',
}

/** Mirror of `OpenCodeEnforcement.readOnlyTools`, sorted; a golden test keeps it equal to the Swift list. */
export const OPENCODE_READ_ONLY_TOOLS: readonly string[] = [
  'glob', 'grep', 'invalid', 'lsp', 'plan_exit', 'question', 'read', 'skill', 'task', 'todowrite',
]

/** OpenCode's MCP key segment: each UTF-16 code unit outside `[A-Za-z0-9_-]` becomes `_` (its regex has no `u` flag). */
export const sanitizeMCPName = (name: string): string => name.replace(/[^A-Za-z0-9_-]/g, '_')

/**
 * OpenCode's tool names. An MCP tool is registered as `<server>_<tool>`, so a name is an MCP tool when some
 * configured server's prefix matches it, even when a built-in has the same id: the MCP key wins. Two servers can
 * produce the same key (`a_b` with tool `c`, `a` with tool `b_c`); such a key is trusted for neither.
 */
export function openCodeHost(mcpServers: readonly string[]): Host {
  const prefixes = mcpServers.map((server) => `${sanitizeMCPName(server)}_`)
  return {
    shellTool: 'bash',
    mcpToolName: (server, tool) => `${sanitizeMCPName(server)}_${sanitizeMCPName(tool)}`,
    isMCPTool: (tool) => prefixes.some((prefix) => tool.startsWith(prefix)),
    // Mirrors `OpenCodeEnforcement.isTrustedPersonaKitMCPTool`: the server is configured and no other one collides.
    trustsMCPKey: (key, server) =>
      mcpServers.includes(server) &&
      !mcpServers.some((other) => other !== server && key.startsWith(`${sanitizeMCPName(other)}_`)),
    toolActionClasses: OPENCODE_TOOL_ACTION_CLASSES,
    readOnlyTools: OPENCODE_READ_ONLY_TOOLS,
    mcpResourceTools: [],
    subagentTools: [],
    localSubagentTypes: [],
  }
}
