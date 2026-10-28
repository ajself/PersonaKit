import { expect, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On } from 'claude-code'

import type { SessionState } from '../types'
import { CONTRACT_JSON, EXPORT_MD, LIST_JSON, LIST_MERGED_JSON } from './fixtures/golden'
import { usePrompt } from './lib/prompts'
import { stepSummary, viewLabel } from './views/parts'

const SESSION = 'read-only-auditor_audit-pass'
const RESOLVE = 'mcp__personakit__personakit_resolve_contract'
const SURFACES = ['terminal', 'desktop'] as const
type Surface = (typeof SURFACES)[number]

const PANE = {
  plugin: 'personakit',
  component: 'Pane',
  requestId: 'personakit',
  props: { title: 'PersonaKit', isFocused: false, bodyColumns: 60, placement: 'dock', scroll: { offset: 0, bodyRows: 40 }, view: {} },
} as const

type Ran = { exitCode: number; stdout: string; stderr: string; isStdoutTruncated: boolean; isStderrTruncated: boolean }
const ran = (stdout: string, exitCode = 0, stderr = ''): Ran => ({ exitCode, stdout, stderr, isStdoutTruncated: false, isStderrTruncated: false })

/** The engine beneath the plugin, as pane.test.tsx stands it up: what the detail views need of it. */
function engine(on: On) {
  const world = {
    answers: [] as { result: unknown; text: string }[], fills: [] as { text: string; mode: string }[], logs: [] as string[], sessionWrites: 0,
    runs: [] as (readonly string[])[],
    // `personakit` as the pane runs it: the library, then a contract and an export per session.
    process: ((argv: readonly string[]) => (argv[1] === 'contract' ? ran(CONTRACT_JSON) : argv[1] === 'export' ? ran(EXPORT_MD) : ran(LIST_JSON))) as (
      argv: readonly string[],
    ) => Ran,
  }
  on('state.set', (_, e, next) => {
    if (e.plugin === 'personakit' && e.key === 'session') world.sessionWrites += 1
    return next(e)
  })
  on('process.run', (_, e) => {
    world.runs.push(e.argv)
    return { value: world.process(e.argv) } as never
  })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('tool.call', () => (world.answers.shift() ?? { result: 'ok', text: 'ok' }) as never)
  on('fs.read', (_, e) => ({ deny: `${e.path}: missing` }) as never)
  on('session.root', () => ({ value: '/p' }))
  on('session.messages', () => ({ value: [] }) as never)
  on('command.register', () => ({ value: { command: 'pk' } }))
  on('ui.open', () => ({ value: { isPlaced: true as const } }))
  on('prompt.read', () => ({ value: { text: '', cursor: 0 } }))
  on('prompt.fill', (_, e) => {
    world.fills.push({ text: e.text, mode: e.mode })
    return { isFilled: true }
  })
  on('ui.status', () => ({ value: undefined }))
  on('ui.log', (_, e) => {
    world.logs.push(e.text)
    return { value: undefined }
  })
  on('ui.toast', () => ({ value: undefined }))
  return world
}

type World = ReturnType<typeof engine>
type Ui = Awaited<ReturnType<typeof $mount>>
const $mount = ($: Engine, surface: Surface) => $.ui.mount({ ...PANE, surface })
type Node = string | { type?: string; children?: Node[] }
const shown = (n: Node): string => (typeof n === 'string' ? n : (n.children ?? []).map(shown).join(''))
/** The outermost Texts' text under the element keyed `key`, in order: a Text nested in a Text reads as part of it. */
const texts = async (ui: Ui, key: string) => {
  const out: string[] = []
  const walk = (n: Node) => {
    if (typeof n === 'string') return
    if (n.type === 'Text') out.push(shown(n))
    else n.children?.forEach(walk)
  }
  walk((await ui.find({ key })) as Node)
  return out
}
const text = async (ui: Ui, match: RegExp) => (await ui.find({ type: 'Text', text: match }))?.text
const buttons = async (ui: Ui) => (await ui.findAll({ type: 'Button' })).map((b) => b.key)
const has = async (ui: Ui, key: string) => (await ui.find({ key })) !== undefined

const each = (name: string, body: ($: Engine, w: World, surface: Surface) => Promise<void>) => {
  for (const surface of SURFACES) {
    test(`${name} (${surface})`, async ($, on) => {
      const w = engine(on)
      await $.session.start({ cwd: '/p', surface, isInteractive: true })
      await body($, w, surface)
      expect(w.logs).toEqual([])
    })
  }
}

/** `/pk` on the Library with `list`, the pane mounted. */
const library = async ($: Engine, w: World, surface: Surface, list = LIST_JSON) => {
  const process = w.process
  w.process = (argv) => (argv[1] === 'list' ? ran(list) : process(argv))
  await $.command.run({ command: 'pk', args: '', origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 160 } } as never)
  return $mount($, surface)
}
const listing = (change: (library: Record<string, any[]> & { scopes: Record<string, string> }) => void) => {
  const parsed = JSON.parse(LIST_JSON)
  change(parsed)
  return JSON.stringify(parsed)
}
const session = (id: string, personaId: string, directiveId = 'audit-pass') => ({
  id, personaId, directiveId, kitOverrides: [], path: `Sessions/${id}.session.json`, scope: 'project', shadows: null, shadowedPath: null,
})

each('a persona detail lists the sessions that use it, each with Use', async ($, w, surface) => {
  const ui = await library($, w, surface)
  await ui.press({ key: 'open:persona:read-only-auditor' })
  expect(await text(ui, /^Read-Only Auditor$/)).toBe('Read-Only Auditor')
  expect(await texts(ui, 'meta')).toEqual(['read-only-auditor · persona', 'project'])
  expect(await text(ui, /Packs\/personas\/read-only-auditor/)).toBe('<ROOT>/Packs/personas/read-only-auditor.persona.json')
  expect(await text(ui, /^TALK TO THEM VIA$/)).toBe('TALK TO THEM VIA')
  expect(await text(ui, /^Inspects and reports/)).toBeDefined()
  expect(await texts(ui, `session-${SESSION}`)).toEqual(['· Read-only audit pass'])
  expect((await ui.find({ key: `use:${SESSION}` }))?.text).toBe('Use')
  expect(await buttons(ui)).toContain(`open:session:${SESSION}`)
  expect(await text(ui, /^BOUNDARIES$/)).toBe('BOUNDARIES')
  expect(await texts(ui, 'row-Never')).toEqual(['Never', 'edit-files, run-commands, network-access'])
  expect(await texts(ui, 'row-Kits')).toEqual(['Kits', 'none'])
  await ui.unmount()
})

each('a persona detail badges a session only when its scope differs or it overrides', async ($, w, surface) => {
  const rows = async (ui: Awaited<ReturnType<typeof library>>, id: string) => {
    await ui.press({ key: `open:persona:${id}` })
    return Promise.all([SESSION, 'g-session'].map(async (s) => texts(ui, `session-${s}`)))
  }
  const same = await library($, w, surface, listing((l) => l.sessions!.push({ ...session('g-session', 'read-only-auditor') })))
  expect(await rows(same, 'read-only-auditor')).toEqual([['· Read-only audit pass'], ['· Read-only audit pass']])
  await same.unmount()

  const differs = await library($, w, surface, listing((l) => l.sessions!.push({ ...session('g-session', 'read-only-auditor'), scope: 'global' })))
  expect(await rows(differs, 'read-only-auditor')).toEqual([['· Read-only audit pass'], ['· Read-only audit pass', 'global']])
  await differs.unmount()

  const overrides = await library($, w, surface, listing((l) => (l.sessions![0]!.shadows = 'global')))
  await overrides.press({ key: 'open:persona:read-only-auditor' })
  expect(await texts(overrides, `session-${SESSION}`)).toEqual(['· Read-only audit pass', 'project · overrides global'])
  await overrides.unmount()

  // The persona's own header keeps its badge.
  const header = await library($, w, surface)
  await header.press({ key: 'open:persona:read-only-auditor' })
  expect(await texts(header, 'meta')).toEqual(['read-only-auditor · persona', 'project'])
  await header.unmount()
})

each('a persona that no session uses says so and has no Use', async ($, w, surface) => {
  const ui = await library($, w, surface, listing((l) => (l.sessions = [])))
  await ui.press({ key: 'open:persona:read-only-auditor' })
  expect(await text(ui, /^No session uses this persona yet\.$/)).toBeDefined()
  expect((await buttons(ui)).filter((k) => String(k).startsWith('use:'))).toEqual([])
  await ui.unmount()
})

each('a persona detail collapses long lists to three and expands them', async ($, w, surface) => {
  const items = ['one', 'two', 'three', 'four', 'five', 'six']
  const ui = await library($, w, surface, listing((l) => (l.personas![0].entity.responsibilities = items)))
  await ui.press({ key: 'open:persona:read-only-auditor' })
  const bullets = async () => (await ui.findAll({ type: 'Text', text: /^• / })).map((t) => t.text)
  const key = 'toggle:persona:read-only-auditor:responsibilities'
  expect(await bullets()).toEqual(['• one', '• two', '• three', '• code editing', '• running build or test commands'])
  expect((await ui.find({ key }))?.text).toBe('… 3 more')
  // The two non-goals fit in three: no toggle for them.
  expect(await has(ui, 'toggle:persona:read-only-auditor:non-goals')).toBe(false)
  await ui.press({ key })
  expect(await bullets()).toEqual(['• one', '• two', '• three', '• four', '• five', '• six', '• code editing', '• running build or test commands'])
  expect((await ui.find({ key }))?.text).toBe('Show fewer')
  await ui.press({ key })
  expect((await ui.find({ key }))?.text).toBe('… 3 more')
  await ui.unmount()
})

each('a session detail reads its preview once and draws the steps, a stop marked', async ($, w, surface) => {
  const ui = await library($, w, surface)
  await ui.press({ key: `open:session:${SESSION}` })
  expect(w.runs).toContainEqual(['personakit', 'contract', '--session', SESSION])
  expect(w.runs).toContainEqual(['personakit', 'export', '--session', SESSION])
  expect(await text(ui, /^Loading contract…$/)).toBe(undefined)
  expect(await text(ui, /^preview, not in force$/)).toBeDefined()
  expect(await text(ui, /^session · /)).toBe(undefined)
  expect((await ui.find({ key: `use:${SESSION}` }))?.text).toBe('Use')
  expect(await texts(ui, 'row-Persona')).toEqual(['Persona'])
  expect(await buttons(ui)).toEqual(expect.arrayContaining(['open:persona:read-only-auditor', 'open:directive:audit-pass']))
  expect(await text(ui, /^GOAL$/)).toBe('GOAL')
  expect(await texts(ui, 'step-1')).toEqual(['1', 'Inspect the diff and the surrounding code.'])
  expect(await texts(ui, 'step-2')).toEqual(['2', 'Report confirmed issues before suggestions.', '◆ stop'])
  expect((await ui.find({ key: `toggle:session:${SESSION}:steps` }))?.text).toBe('Show full steps')
  expect(await text(ui, /^BOUNDARIES$/)).toBe('BOUNDARIES')
  // Back and forth does not read it again.
  await ui.press({ key: 'back' })
  await ui.press({ key: `open:session:${SESSION}` })
  expect(w.runs.filter((argv) => argv[1] === 'contract')).toHaveLength(1)
  await ui.unmount()
})

each('a session detail never touches the session in force', async ($, w, surface) => {
  const ui = await library($, w, surface)
  const writes = w.sessionWrites
  await ui.press({ key: `open:session:${SESSION}` })
  await ui.press({ key: `toggle:session:${SESSION}:steps` })
  expect(w.sessionWrites).toBe(writes)
  await ui.unmount()
})

each('a long step shows its first sentence until the steps are shown in full', async ($, w, surface) => {
  const long = 'Read the diff. Then read every file it touches, top to bottom, before writing anything down at all, ever.'
  w.process = (argv) =>
    argv[1] === 'export' ? ran(EXPORT_MD.replace('1. Inspect the diff and the surrounding code.', `1. ${long}`)) : argv[1] === 'contract' ? ran(CONTRACT_JSON) : ran(LIST_JSON)
  const ui = await library($, w, surface)
  await ui.press({ key: `open:session:${SESSION}` })
  expect(await texts(ui, 'step-1')).toEqual(['1', 'Read the diff.'])
  await ui.press({ key: `toggle:session:${SESSION}:steps` })
  expect(await texts(ui, 'step-1')).toEqual(['1', long])
  expect((await ui.find({ key: `toggle:session:${SESSION}:steps` }))?.text).toBe('Show first lines')
  await ui.unmount()
})

test('a step is cut at its first sentence or at 80 characters', () => {
  expect(stepSummary('Inspect the diff. Then more.')).toBe('Inspect the diff.')
  expect(stepSummary('No end to this one')).toBe('No end to this one')
  expect(stepSummary('v1.2 is fine')).toBe('v1.2 is fine')
  expect(stepSummary('x'.repeat(100))).toBe(`${'x'.repeat(79)}…`)
  expect(stepSummary('First line\nsecond line')).toBe('First line')
})

each('a session detail whose preview fails keeps the persona and directive and says why', async ($, w, surface) => {
  const process = w.process
  w.process = (argv) => (argv[1] === 'contract' ? ran('', 1, 'No such session: x\n') : process(argv))
  const ui = await library($, w, surface)
  await ui.press({ key: `open:session:${SESSION}` })
  expect(await text(ui, /^Couldn't load the contract:/)).toBe("Couldn't load the contract: No such session: x")
  expect(await buttons(ui)).toEqual(expect.arrayContaining(['open:persona:read-only-auditor', 'open:directive:audit-pass']))
  expect(await text(ui, /^GOAL$/)).toBe(undefined)
  // Opening it again tries again.
  w.process = process
  await ui.press({ key: 'back' })
  await ui.press({ key: `open:session:${SESSION}` })
  expect(await text(ui, /^GOAL$/)).toBe('GOAL')
  await ui.unmount()
})

each('a session whose persona and directive are missing shows the raw ids without links', async ($, w, surface) => {
  const ui = await library($, w, surface, listing((l) => l.sessions!.push(session('ghost-session', 'ghost', 'phantom'))))
  await ui.press({ key: 'open:session:ghost-session' })
  expect(await text(ui, /^ghost$/)).toBe('ghost')
  expect(await text(ui, /^phantom$/)).toBe('phantom')
  expect(await has(ui, 'open:persona:ghost')).toBe(false)
  expect(await has(ui, 'open:directive:phantom')).toBe(false)
  expect((await ui.find({ key: 'use:ghost-session' }))?.text).toBe('Use')
  await ui.unmount()
})

each('a persona whose kit or skill is missing shows the raw id without a link', async ($, w, surface) => {
  const ui = await library($, w, surface, listing((l) => {
    l.personas![0].entity.defaultKitIds = ['ghost-kit']
    l.personas![0].entity.forbiddenSkillIds = ['ghost-skill']
  }))
  await ui.press({ key: 'open:persona:read-only-auditor' })
  expect(await text(ui, /^ghost-kit$/)).toBe('ghost-kit')
  expect(await text(ui, /^ghost-skill$/)).toBe('ghost-skill')
  expect(await has(ui, 'open:kit:ghost-kit')).toBe(false)
  expect(await has(ui, 'open:skill:ghost-skill')).toBe(false)
  await ui.unmount()
})

each('an override shows where it lives and the file it shadows', async ($, w, surface) => {
  const ui = await library($, w, surface, LIST_MERGED_JSON)
  await ui.press({ key: 'list:kits' })
  await ui.press({ key: 'open:kit:repo-constraints' })
  expect(await text(ui, /^Repository Constraints Kit$/)).toBeDefined()
  expect(await texts(ui, 'meta')).toEqual(['repo-constraints · kit', 'project · overrides global'])
  expect(await text(ui, /^<PROJECT>\//)).toBe('<PROJECT>/Packs/kits/repo-constraints.kit.json')
  expect(await texts(ui, 'row-Shadowed')).toEqual(['Shadowed', '<GLOBAL>/Packs/kits/repo-constraints.kit.json'])
  await ui.unmount()
})

each('an item that overrides nothing has no Shadowed row, nor one without a shadowed path', async ($, w, surface) => {
  const ui = await library($, w, surface, LIST_MERGED_JSON)
  await ui.press({ key: 'list:kits' })
  await ui.press({ key: 'open:kit:architectural-editor-core' })
  expect(await has(ui, 'row-Shadowed')).toBe(false)
  await ui.unmount()
  const unknown = await library($, w, surface, listing((l) => {
    l.personas![0].shadows = 'global'
    l.personas![0].shadowedPath = null
    l.scopes.global = '/g'
  }))
  await unknown.press({ key: 'open:persona:read-only-auditor' })
  expect(await texts(unknown, 'meta')).toEqual(['read-only-auditor · persona', 'project · overrides global'])
  expect(await has(unknown, 'row-Shadowed')).toBe(false)
  await unknown.unmount()
})

each('Back returns through the views that opened each one', async ($, w, surface) => {
  const ui = await library($, w, surface)
  await ui.press({ key: 'open:persona:read-only-auditor' })
  expect((await ui.find({ key: 'back' }))?.text).toBe('‹ Library')
  await ui.press({ key: `open:session:${SESSION}` })
  expect((await ui.find({ key: 'back' }))?.text).toBe('‹ Read-Only Auditor')
  await ui.press({ key: 'back' })
  expect(await text(ui, /^Read-Only Auditor$/)).toBe('Read-Only Auditor')
  expect(await text(ui, /^TALK TO THEM VIA$/)).toBeDefined()
  await ui.press({ key: 'back' })
  expect(await text(ui, /^PEOPLE$/)).toBe('PEOPLE')
  await ui.unmount()
})

each('Back names the view it returns to by its display label, not its id', async ($, w, surface) => {
  const ui = await library($, w, surface, LIST_MERGED_JSON)
  await ui.press({ key: 'open:persona:architectural-editor' })
  await ui.press({ key: 'open:kit:architectural-editor-core' })
  expect((await ui.find({ key: 'back' }))?.text).toBe('‹ Architectural Editor')
  await ui.press({ key: 'open:skill:architecture-defaults' })
  expect((await ui.find({ key: 'back' }))?.text).toBe('‹ Architectural Editor Core Kit')
  await ui.unmount()

  const sessions = await library($, w, surface)
  await sessions.press({ key: `open:session:${SESSION}` })
  await sessions.press({ key: 'open:directive:audit-pass' })
  expect((await sessions.find({ key: 'back' }))?.text).toBe(`‹ ${SESSION}`)
  await sessions.unmount()
})

test('viewLabel falls back to the id when the library is not loaded or lacks the view', () => {
  const loaded = JSON.parse(LIST_JSON)
  expect(viewLabel({ kind: 'persona', id: 'read-only-auditor' }, loaded)).toBe('Read-Only Auditor')
  expect(viewLabel({ kind: 'directive', id: 'audit-pass' }, loaded)).toBe(loaded.directives[0].entity.title)
  expect(viewLabel({ kind: 'persona', id: 'read-only-auditor' })).toBe('read-only-auditor')
  expect(viewLabel({ kind: 'kit', id: 'ghost' }, loaded)).toBe('ghost')
  expect(viewLabel({ kind: 'session', id: SESSION }, loaded)).toBe(SESSION)
})

each('the header sits in one column: title, id and scope, then path, with no blank line between', async ($, w, surface) => {
  const ui = await library($, w, surface, LIST_MERGED_JSON)
  await ui.press({ key: 'list:kits' })
  await ui.press({ key: 'open:kit:repo-constraints' })
  expect(await texts(ui, 'header')).toEqual([
    'Repository Constraints Kit', 'repo-constraints · kit', 'project · overrides global', '<PROJECT>/Packs/kits/repo-constraints.kit.json', 'Shadowed', '<GLOBAL>/Packs/kits/repo-constraints.kit.json',
  ])
  // A badge is inline words in the terminal, so the meta line stays one row; elsewhere it is outlined.
  const outlines = (await ui.findAll({ type: 'Box' })).filter((b) => b.props.borderStyle !== undefined)
  if (surface === 'terminal') expect(outlines).toEqual([])
  else expect(outlines.length).toBeGreaterThan(0)
  await ui.unmount()
})

each('links open the detail of what they name', async ($, w, surface) => {
  const ui = await library($, w, surface, LIST_MERGED_JSON)
  await ui.press({ key: 'open:persona:architectural-editor' })
  expect(await buttons(ui)).toEqual(expect.arrayContaining(['open:kit:architectural-editor-core', 'open:skill:codex-cli', 'open:skill:autonomous-agent-loop']))
  await ui.press({ key: 'open:kit:architectural-editor-core' })
  expect(await text(ui, /^Architectural Editor Core Kit$/)).toBeDefined()
  expect(await text(ui, /^SKILLS$/)).toBe('SKILLS')
  expect(await texts(ui, 'row-Personas')).toEqual(['Personas'])
  expect(await buttons(ui)).toEqual(expect.arrayContaining(['open:skill:architecture-defaults', 'open:persona:architectural-editor']))
  await ui.press({ key: 'open:skill:architecture-defaults' })
  expect(await text(ui, /^Repository Architecture Defaults$/)).toBeDefined()
  expect(await texts(ui, 'meta')).toEqual(['architecture-defaults · skill', 'project'])
  expect(await buttons(ui)).toEqual(expect.arrayContaining(['open:kit:architectural-editor-core', 'open:kit:repo-constraints']))
  await ui.unmount()
})

each('a directive detail shows its goal, steps, criteria, required skills and sessions', async ($, w, surface) => {
  const ui = await library($, w, surface, LIST_MERGED_JSON)
  await ui.press({ key: 'list:directives' })
  await ui.press({ key: 'open:directive:review-architecture-invariants' })
  expect(await text(ui, /^Review architecture invariants before implementation$/)).toBeDefined()
  expect(await text(ui, /^GOAL$/)).toBeDefined()
  expect(await texts(ui, 'step-3')).toEqual(['3', 'Classify findings by severity and flaw type, then pause for human review before…', '◆ stop'])
  expect(await text(ui, /^ACCEPTANCE$/)).toBeDefined()
  expect(await text(ui, /^• Architecture and concurrency/)).toBeDefined()
  expect((await ui.find({ key: 'toggle:directive:review-architecture-invariants:acceptance' }))?.text).toBe('… 1 more')
  expect(await buttons(ui)).toEqual(expect.arrayContaining(['open:skill:codex-cli', 'open:session:architectural-editor-review']))
  expect(await text(ui, /^USED BY$/)).toBe('USED BY')
  await ui.unmount()
})

each('a session detail follows the Use / Switch / in force rule', async ($, w, surface) => {
  const ui = await library($, w, surface, listing((l) => l.sessions!.push(session('other', 'read-only-auditor'))))
  await ui.press({ key: 'open:session:other' })
  expect((await ui.find({ key: 'use:other' }))?.text).toBe('Use')
  await ui.press({ key: 'use:other' })
  expect(w.fills).toEqual([{ text: usePrompt({ sessionId: 'other' }), mode: 'replace' }])
  await ui.unmount()

  w.answers.push({ result: CONTRACT_JSON, text: CONTRACT_JSON })
  await $.tool.call({ tool: RESOLVE } as never)
  const forced = await library($, w, surface, listing((l) => l.sessions!.push(session('other', 'read-only-auditor'))))
  await forced.press({ key: 'switch-library' })
  await forced.press({ key: 'open:session:other' })
  expect((await forced.find({ key: 'use:other' }))?.text).toBe('Switch')
  await forced.press({ key: 'back' })
  await forced.press({ key: `open:session:${SESSION}` })
  expect(await has(forced, `use:${SESSION}`)).toBe(false)
  expect(await text(forced, /^● in force$/)).toBe('● in force')
  expect(await text(forced, /^in force$/)).toBeDefined()
  await forced.unmount()
})
