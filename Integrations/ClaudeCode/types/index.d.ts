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
  | { kind: 'enforced' | 'enforcing-other'; manifestPath: string; ids: ContractIds; deniedActionClasses: string[]; matcherTools: string[]; mcpServerName?: string; manifestUnreadable?: true; pluginMissing?: true }
export type DriftEvent = { tool: string; actionClass?: string; kind: 'blocked' | 'advisory' | 'reground-blocked'; agentId?: string; turn: number }
export type SessionState = {
  main?: Resolution; subagents: Record<string, Resolution>
  enforcement: Enforcement; compactions: number; drift: DriftEvent[]; turn: number
}
export type Scope = 'project' | 'global'
// shadowedPath: the shadowed entity's path, relative to the shadowed scope's root; null when nothing is shadowed.
export type Provenance = { id: string; scope: Scope; path: string; shadows: Scope | null; shadowedPath: string | null }
export type PersonaEntity = {
  id: string; name: string; summary: string; responsibilities: string[]; values: string[]; nonGoals: string[]
  defaultKitIds: string[]; allowedSkillIds: string[]; forbiddenSkillIds: string[]; forbiddenCapabilities?: string[]
}
export type DirectiveEntity = {
  id: string; title: string; goal: string; steps: { text: string; requiresReview?: boolean }[]
  acceptanceCriteria: string[]; requiresSkillIds: string[]
}
export type KitEntity = { id: string; name: string; summary: string; skillIds?: string[] }
export type SkillEntity = { id: string; name: string; description: string }
export type LibrarySession = Provenance & { personaId: string; directiveId: string; kitOverrides: string[] }
export type Library = {
  scopes: { project?: string; global?: string }; sessions: LibrarySession[]
  personas: (Provenance & { entity: PersonaEntity })[]; directives: (Provenance & { entity: DirectiveEntity })[]
  kits: (Provenance & { entity: KitEntity })[]; skills: (Provenance & { entity: SkillEntity })[]
}
export type LibraryError = { scope: Scope | null; path: string | null; entityType: string; id: string | null; message: string }
export type LibraryLoad =
  | { kind: 'idle' } | { kind: 'loading'; token: number }
  | { kind: 'loaded'; library: Library } | { kind: 'no-library' }
  | { kind: 'errors'; errors: LibraryError[] }
  | { kind: 'unavailable'; binary: string; detail: string }
  | { kind: 'no-process' }
export type View =
  | { kind: 'contract' } | { kind: 'library' }
  | { kind: 'list'; of: 'directives' | 'kits' | 'skills' }
  | { kind: 'persona' | 'session' | 'directive' | 'kit' | 'skill'; id: string }
// What `personakit contract` and `personakit export` printed for one contract, read by the pane and never
// folded into `SessionState`.
export type Preview =
  | { kind: 'loading'; token: number } | { kind: 'loaded'; contract?: Contract; details?: ExportDetails }
  | { kind: 'failed'; message: string }
export type PaneState = {
  view: View; back: View[]; filter: string; library: LibraryLoad
  previews: Record<string, Preview>   // by `previewKey`
  expanded: string[]; token: number   // token: the latest library load; an older one's result is dropped
}
declare module 'claude-code' {
  interface PluginState {
    personakit: {
      session: SessionState   // one versioned value: atom({ plugin: 'personakit', key: 'session' })
      pane: PaneState         // atom({ plugin: 'personakit', key: 'pane' })
    }
  }
}
