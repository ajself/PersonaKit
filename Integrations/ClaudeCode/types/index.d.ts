export type ContractIds = { sessionId?: string; personaId?: string; directiveId?: string }
export type Contract = ContractIds & {
  personaId: string
  kitIds: string[]; allowedSkillIds: string[]; forbiddenSkillIds: string[]; authorizedSkillIds: string[]
  isAuthorized: boolean; failureReasons: string[]
  unauthorizedRequestedSkillIds: string[]; unauthorizedRequiredSkillIds: string[]; undeclaredRequestedSkillIds: string[]
  scope: { mode: string; projectRoot?: string; globalRoot?: string }
}
export type Step = { text: string; isStop: boolean }
export type ExportDetails = {
  personaName?: string; personaId?: string; directiveTitle?: string; directiveId?: string; goal?: string
  steps: Step[]; deniedActionClasses: string[]   // sorted
}
export type Observation =
  | { kind: 'contract'; source: 'mcp' | 'cli'; ids: ContractIds; contract?: Contract }   // contract absent: truncated output
  | { kind: 'export'; source: 'mcp' | 'cli'; ids: ContractIds; details?: ExportDetails } // details absent: truncated output
  | { kind: 'failed'; source: 'mcp' | 'cli'; ids: ContractIds }
// driftMark: `drift.length` at main's latest successful resolve, a re-ground of the same contract included; the
// status line's warnings count only drift from it on. Absent (state persisted before it existed) reads as 0.
export type Resolution = { ids: ContractIds; contract?: Contract; details?: ExportDetails; source: 'mcp' | 'cli'; turn: number; driftMark?: number }
export type Enforcement =
  | { kind: 'advisory' }
  | { kind: 'enforced' | 'enforcing-other'; manifestPath: string; ids: ContractIds; deniedActionClasses: string[]; matcherTools: string[]; mcpServerName?: string; manifestUnreadable?: true }
export type DriftEvent = { tool: string; actionClass?: string; kind: 'blocked' | 'advisory' | 'reground-blocked'; agentId?: string; turn: number }
export type SessionState = {
  main?: Resolution; subagents: Record<string, Resolution>
  enforcement: Enforcement; compactions: number; drift: DriftEvent[]; turn: number
}
declare module 'claude-code' {
  interface PluginState {
    personakit: { session: SessionState }   // one versioned value: atom({ plugin: 'personakit', key: 'session' })
  }
}
