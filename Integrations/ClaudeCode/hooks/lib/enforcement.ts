import type { ContractIds, Enforcement } from '../../types'

type InstalledHook = { manifestPath: string; matcherTools: string[] }

const MARKER = 'hook-check --manifest'

export function sameContract(a: ContractIds, b: ContractIds): boolean {
  if (a.sessionId && b.sessionId) return a.sessionId === b.sessionId
  return a.personaId !== undefined && a.personaId === b.personaId && a.directiveId === b.directiveId
}

// Reads one POSIX shell word from the start of `text`; returns the word and the unread rest.
function readWord(text: string): { word: string; rest: string } {
  let word = ''
  let i = 0
  while (i < text.length && !/\s/.test(text[i])) {
    const c = text[i]
    if (c === "'") {
      const end = text.indexOf("'", i + 1)
      if (end < 0) return { word: word + text.slice(i + 1), rest: '' }
      word += text.slice(i + 1, end)
      i = end + 1
    } else if (c === '"') {
      i++
      while (i < text.length && text[i] !== '"') {
        if (text[i] === '\\' && i + 1 < text.length && '"\\$`'.includes(text[i + 1])) i++
        word += text[i++]
      }
      i++
    } else if (c === '\\' && i + 1 < text.length) {
      word += text[i + 1]
      i += 2
    } else {
      word += c
      i++
    }
  }
  return { word, rest: text.slice(i) }
}

export function unquotePOSIX(value: string): string {
  return readWord(value.trim()).word
}

function parse(json: string | undefined): unknown {
  if (!json) return undefined
  try {
    return JSON.parse(json)
  } catch {
    return undefined
  }
}

const isRecord = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v)

export function installedHook(settingsJSON: string | undefined): InstalledHook | undefined {
  const settings = parse(settingsJSON)
  if (!isRecord(settings) || !isRecord(settings.hooks)) return undefined
  const groups = settings.hooks.PreToolUse
  if (!Array.isArray(groups)) return undefined
  for (const group of groups) {
    if (!isRecord(group) || !Array.isArray(group.hooks)) continue
    for (const h of group.hooks) {
      if (!isRecord(h) || typeof h.command !== 'string') continue
      const at = h.command.indexOf(MARKER)
      if (at < 0) continue
      const manifestPath = readWord(h.command.slice(at + MARKER.length).trimStart()).word
      if (!manifestPath) continue
      const matcher = typeof group.matcher === 'string' ? group.matcher : ''
      return { manifestPath, matcherTools: matcher.split('|').filter(Boolean) }
    }
  }
  return undefined
}

const str = (v: unknown): string | undefined => (typeof v === 'string' ? v : undefined)

export function enforcementFor(
  resolved: ContractIds | undefined,
  hook: InstalledHook | undefined,
  manifestJSON: string | undefined,
): Enforcement {
  const advisory: Enforcement = { kind: 'advisory' }
  if (!hook) return advisory
  const manifest = parse(manifestJSON)
  if (!isRecord(manifest)) {
    return {
      kind: 'enforcing-other',
      manifestPath: hook.manifestPath,
      ids: {},
      deniedActionClasses: [],
      matcherTools: hook.matcherTools,
      manifestUnreadable: true,
    }
  }

  const ids: ContractIds = {}
  const sessionId = str(manifest.sessionId)
  const personaId = str(manifest.personaId)
  const directiveId = str(manifest.directiveId)
  if (sessionId !== undefined) ids.sessionId = sessionId
  if (personaId !== undefined) ids.personaId = personaId
  if (directiveId !== undefined) ids.directiveId = directiveId

  const classes = new Set<string>()
  if (Array.isArray(manifest.checks)) {
    for (const check of manifest.checks) {
      if (!isRecord(check) || check.maxClass !== 'hook' || !isRecord(check.rule)) continue
      const denied = check.rule.deniedActionClasses
      if (!Array.isArray(denied)) continue
      for (const c of denied) if (typeof c === 'string') classes.add(c)
    }
  }

  const result: Enforcement = {
    kind: resolved && sameContract(resolved, ids) ? 'enforced' : 'enforcing-other',
    manifestPath: hook.manifestPath,
    ids,
    deniedActionClasses: [...classes].sort(),
    matcherTools: hook.matcherTools,
  }
  const mcpServerName = str(manifest.mcpServerName)
  if (mcpServerName !== undefined) result.mcpServerName = mcpServerName
  return result
}
