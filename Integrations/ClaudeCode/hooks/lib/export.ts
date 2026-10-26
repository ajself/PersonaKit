import type { ExportDetails, Step } from '../../types'

const STOP_MARKER = / \(requires review\)$/
const DENY_LINE = /^- capability-deny\.\S+ — deny (.+?) — /

function field(lines: string[], name: string): string | undefined {
  const prefix = `${name}: `
  const line = lines.find(l => l.startsWith(prefix))
  return line === undefined ? undefined : line.slice(prefix.length).trim()
}

function parseSteps(lines: string[]): Step[] {
  const start = lines.indexOf('Steps:')
  if (start < 0) return []
  const steps: Step[] = []
  for (const line of lines.slice(start + 1)) {
    const m = /^\d+\. (.*)$/.exec(line)
    if (m === null) break
    const isStop = STOP_MARKER.test(m[1])
    steps.push({ text: isStop ? m[1].replace(STOP_MARKER, '') : m[1], isStop })
  }
  return steps
}

/**
 * Parses `personakit export` Markdown. Persona comes from the first `# ` section, Directive and
 * Boundaries from the last, so a skill body embedded under `# Expanded Skills` cannot shadow them.
 */
export function parseExport(markdown: string): ExportDetails | undefined {
  const all = markdown.split('\n')
  const header = all.findIndex(l => l.startsWith('PersonaKit-Output-Version:'))
  if (header < 0) return undefined

  const sections: { name: string; lines: string[] }[] = []
  for (const line of all.slice(header + 1)) {
    if (/^# /.test(line)) sections.push({ name: line.slice(2).trim(), lines: [] })
    else sections[sections.length - 1]?.lines.push(line)
  }
  const first = (name: string) => sections.find(s => s.name === name)?.lines ?? []
  const last = (name: string) => [...sections].reverse().find(s => s.name === name)?.lines ?? []

  const persona = first('Persona')
  const directive = last('Directive')
  const denied = new Set<string>()
  for (const line of last('Boundaries')) {
    const m = DENY_LINE.exec(line)
    if (m !== null) for (const c of m[1].split(', ')) denied.add(c)
  }

  return {
    personaName: field(persona, 'Name'),
    personaId: field(persona, 'Id'),
    directiveTitle: field(directive, 'Title'),
    directiveId: field(directive, 'Id'),
    goal: field(directive, 'Goal'),
    steps: parseSteps(directive),
    deniedActionClasses: [...denied].sort(),
  }
}
