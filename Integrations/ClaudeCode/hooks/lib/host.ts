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
}

/** Mirror of `ClaudeCodeEnforcement.toolActionClasses`, flattened; a golden test keeps it equal to the Swift map. */
export const TOOL_ACTION_CLASSES: Record<string, string> = {
  Edit: 'file-mutation',
  Write: 'file-mutation',
  NotebookEdit: 'file-mutation',
  Bash: 'command-execution',
  WebFetch: 'network-egress',
  WebSearch: 'network-egress',
}

export const CLAUDE_HOST: Host = {
  shellTool: 'Bash',
  mcpToolName: (server, tool) => `mcp__${server}__${tool}`,
  isMCPTool: (tool) => tool.startsWith('mcp__'),
  trustsMCPKey: () => true,
  toolActionClasses: TOOL_ACTION_CLASSES,
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
  }
}
