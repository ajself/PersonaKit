import type { RenderChildren } from 'claude-code'

import type { Library, PaneState, Provenance, SessionState, Step, View } from '../../types'
import { usedBy } from '../lib/libraryIndex'
import { previewKey } from '../lib/runner'
import { parts, viewLabel } from './parts'
import type { El, PaneActions } from './parts'

type Detail = Extract<View, { id: string }>
type Kind = Detail['kind']

const COLLAPSED = 3
const unique = (ids: readonly string[]) => [...new Set(ids)]
const joinPath = (root: string | undefined, path: string) => (root === undefined ? path : `${root.replace(/\/$/, '')}/${path}`)

/** The pieces every detail view draws with: references that open or stay raw, Use controls, collapsible lists. */
function shared(el: El, library: Library, pane: PaneState, session: SessionState, actions: PaneActions) {
  const { Box, Text, Button } = el
  const { section, row, scopeBadge, backButton } = parts(el)
  const inForceSessionId = session.main?.ids.sessionId

  const names: Record<Kind, Map<string, string>> = {
    persona: new Map(library.personas.map((p) => [p.id, p.entity.name])),
    session: new Map(library.sessions.map((s) => [s.id, s.id])),
    directive: new Map(library.directives.map((d) => [d.id, d.entity.title])),
    kit: new Map(library.kits.map((k) => [k.id, k.entity.name])),
    skill: new Map(library.skills.map((s) => [s.id, s.entity.name])),
  }

  /** A name that opens its detail view; an id the library lacks is its raw text, with nothing to open. */
  const ref = (kind: Kind, id: string) => {
    const name = names[kind].get(id)
    return name === undefined ? (
      <Text key={`ref:${kind}:${id}`}>{id}</Text>
    ) : (
      <Button key={`open:${kind}:${id}`} onPress={() => actions.go({ kind, id } as View)}>
        {name}
      </Button>
    )
  }
  const refs = (kind: Kind, ids: readonly string[]) =>
    ids.length === 0 ? (
      <Text dimColor>none</Text>
    ) : (
      <Box flexDirection="row" flexWrap="wrap" columnGap={2}>
        {unique(ids).map((id) => ref(kind, id))}
      </Box>
    )

  /** The Skills row of a Boundaries section: what is allowed, then what is forbidden. */
  const skillsRow = (allowed: readonly string[], forbidden: readonly string[]) =>
    row(
      'Skills',
      <Box flexDirection="column">
        <Box flexDirection="row" flexWrap="wrap" columnGap={1}>
          <Text dimColor>allowed</Text>
          {refs('skill', allowed)}
        </Box>
        <Box flexDirection="row" flexWrap="wrap" columnGap={1}>
          <Text dimColor>forbidden</Text>
          {refs('skill', forbidden)}
        </Box>
      </Box>,
    )

  /** `Use`, or `Switch` while another session is in force; the session in force is marked and has no button. */
  const useControl = (sessionId: string, variant: 'primary' | 'secondary' = 'secondary') =>
    sessionId === inForceSessionId ? (
      <Text key={`in-force:${sessionId}`} color="success">● in force</Text>
    ) : (
      <Button key={`use:${sessionId}`} variant={variant} onPress={() => actions.use(sessionId)}>
        {inForceSessionId === undefined ? 'Use' : 'Switch'}
      </Button>
    )

  /** Three items and `… n more`; the whole list once its toggle is pressed. Nothing at all for an empty list. */
  const bullets = (title: string, items: readonly string[], viewKey: string, name: string) => {
    if (items.length === 0) return null
    const key = `${viewKey}:${name}`
    const isOpen = pane.expanded.includes(key)
    const shown = isOpen ? items : items.slice(0, COLLAPSED)
    return section(
      title,
      shown.map((item, i) => <Text key={`${name}-${i + 1}`}>{`• ${item}`}</Text>),
      items.length > COLLAPSED && (
        <Box key={`${name}-toggle`}>
          <Button key={`toggle:${key}`} onPress={() => actions.toggle(key)}>
            {isOpen ? 'Show fewer' : `… ${items.length - COLLAPSED} more`}
          </Button>
        </Box>
      ),
    )
  }

  /**
   * Back, then one column, so no blank line falls between its rows: the title, `<id> · <kind>` with the scope badge,
   * where the file lives, and, for an override, the shadowed one.
   */
  const header = (kind: Kind, title: string, entity: Provenance) => {
    const shadowedRoot = entity.shadows === null ? undefined : library.scopes[entity.shadows]
    return [
      backButton(viewLabel(pane.back.at(-1) ?? { kind: 'library' }, library), () => actions.back()),
      <Box key="header" flexDirection="column">
        <Text key="title" size="title" weight="semibold">
          {title}
        </Text>
        <Box key="meta" flexDirection="row" flexWrap="wrap" alignItems="center" columnGap={1}>
          <Text dimColor>{`${entity.id} · ${kind}`}</Text>
          {scopeBadge(entity.scope, entity.shadows)}
        </Box>
        <Text key="path" mono dimColor>
          {joinPath(library.scopes[entity.scope], entity.path)}
        </Text>
        {entity.shadows !== null && entity.shadowedPath !== null && row('Shadowed', <Text mono>{joinPath(shadowedRoot, entity.shadowedPath)}</Text>)}
      </Box>,
    ]
  }

  return { ref, refs, skillsRow, useControl, bullets, header, inForceSessionId }
}

type Tools = ReturnType<typeof shared>
type Context = { el: El; library: Library; pane: PaneState; session: SessionState; actions: PaneActions; tools: Tools; index: ReturnType<typeof usedBy> }

function persona(c: Context, id: string): RenderChildren[] {
  const { Box, Text } = c.el
  const { section, row, scopeBadge } = parts(c.el)
  const { ref, refs, skillsRow, useControl, bullets, header } = c.tools
  const p = c.library.personas.find((x) => x.id === id)!
  const { entity } = p
  const titles = new Map(c.library.directives.map((d) => [d.id, d.entity.title]))
  const sessions = (c.index.sessionsByPersona[id] ?? []).flatMap((sessionId) => c.library.sessions.filter((s) => s.id === sessionId))
  const key = `persona:${id}`
  return [
    ...header('persona', entity.name, p),
    entity.summary !== '' && <Text key="summary">{entity.summary}</Text>,
    section(
      'Talk to them via',
      sessions.length === 0 ? (
        <Text key="no-sessions" dimColor>No session uses this persona yet.</Text>
      ) : (
        sessions.map((s) => (
          <Box key={`session-${s.id}`} flexDirection="row" flexWrap="wrap" alignItems="center" columnGap={1}>
            {ref('session', s.id)}
            <Text dimColor>{`· ${titles.get(s.directiveId) ?? s.directiveId}`}</Text>
            {(s.scope !== p.scope || s.shadows !== null) && scopeBadge(s.scope, s.shadows)}
            {useControl(s.id)}
          </Box>
        ))
      ),
    ),
    bullets('Responsibilities', entity.responsibilities, key, 'responsibilities'),
    bullets('Non-goals', entity.nonGoals, key, 'non-goals'),
    section(
      'Boundaries',
      row('Kits', refs('kit', entity.defaultKitIds)),
      skillsRow(entity.allowedSkillIds, entity.forbiddenSkillIds),
      (entity.forbiddenCapabilities?.length ?? 0) > 0 && row('Never', entity.forbiddenCapabilities!.join(', ')),
    ),
  ]
}

function sessionDetail(c: Context, id: string): RenderChildren[] {
  const { Box, Text } = c.el
  const { section, row, stepsSection } = parts(c.el)
  const { ref, refs, skillsRow, useControl, header, inForceSessionId } = c.tools
  const s = c.library.sessions.find((x) => x.id === id)!
  const preview = c.pane.previews[previewKey({ sessionId: id })]
  const isInForce = inForceSessionId === id

  const body = ((): RenderChildren[] => {
    if (preview === undefined || preview.kind === 'loading') return [<Text key="loading" dimColor>Loading contract…</Text>]
    if (preview.kind === 'failed') return [<Text key="failed" color="error">{`Couldn't load the contract: ${preview.message}`}</Text>]
    const { contract, details } = preview
    return [
      details?.goal !== undefined && section('Goal', <Text key="goal">{details.goal}</Text>),
      details !== undefined && details.steps.length > 0 && stepsSection(details.steps, `session:${id}:steps`, c.pane.expanded, c.actions.toggle),
      contract !== undefined &&
        section(
          'Boundaries',
          row('Kits', refs('kit', contract.kitIds)),
          skillsRow(contract.allowedSkillIds, contract.forbiddenSkillIds),
        ),
    ]
  })()

  return [
    ...header('session', id, s),
    <Text key="state" dimColor>{isInForce ? 'in force' : 'preview, not in force'}</Text>,
    <Box key="primary">{useControl(id, 'primary')}</Box>,
    <Box key="refs" flexDirection="column">
      {row('Persona', ref('persona', s.personaId))}
      {row('Directive', ref('directive', s.directiveId))}
    </Box>,
    ...body,
  ]
}

function directive(c: Context, id: string): RenderChildren[] {
  const { Text } = c.el
  const { section, row, stepsSection } = parts(c.el)
  const { refs, bullets, header } = c.tools
  const d = c.library.directives.find((x) => x.id === id)!
  const { entity } = d
  const steps: Step[] = entity.steps.map((step) => ({ text: step.text, isStop: step.requiresReview === true }))
  const key = `directive:${id}`
  const sessions = c.index.sessionsByDirective[id] ?? []
  return [
    ...header('directive', entity.title, d),
    entity.goal !== '' && section('Goal', <Text key="goal">{entity.goal}</Text>),
    steps.length > 0 && stepsSection(steps, `${key}:steps`, c.pane.expanded, c.actions.toggle),
    bullets('Acceptance', entity.acceptanceCriteria, key, 'acceptance'),
    entity.requiresSkillIds.length > 0 && section('Requires', row('Skills', refs('skill', entity.requiresSkillIds))),
    section('Used by', row('Sessions', refs('session', sessions))),
  ]
}

function kit(c: Context, id: string): RenderChildren[] {
  const { Text } = c.el
  const { section, row } = parts(c.el)
  const { refs, header } = c.tools
  const k = c.library.kits.find((x) => x.id === id)!
  const { entity } = k
  return [
    ...header('kit', entity.name, k),
    entity.summary !== '' && <Text key="summary">{entity.summary}</Text>,
    section('Skills', refs('skill', entity.skillIds ?? [])),
    section('Used by', row('Personas', refs('persona', c.index.personasByKit[id] ?? [])), row('Sessions', refs('session', c.index.sessionsByKit[id] ?? []))),
  ]
}

function skill(c: Context, id: string): RenderChildren[] {
  const { Text } = c.el
  const { section, row } = parts(c.el)
  const { refs, header } = c.tools
  const s = c.library.skills.find((x) => x.id === id)!
  const { entity } = s
  return [
    ...header('skill', entity.name, s),
    entity.description !== '' && <Text key="description">{entity.description}</Text>,
    section('Used by', row('Kits', refs('kit', c.index.kitsBySkill[id] ?? [])), row('Personas', refs('persona', c.index.personasBySkill[id] ?? []))),
  ]
}

/**
 * A persona, session, directive, kit or skill from the loaded library, under a Back button to the view that opened
 * it. A session's contract is the preview the pane read for it, never the session in force. A reference the library
 * lacks is drawn as its raw id, with nothing to open.
 */
export function detailTree(el: El, view: Detail, pane: PaneState, session: SessionState, actions: PaneActions): RenderChildren[] {
  const { Text } = el
  const { backButton } = parts(el)
  const loaded = pane.library.kind === 'loaded' ? pane.library.library : undefined
  const back = backButton(viewLabel(pane.back.at(-1) ?? { kind: 'library' }, loaded), () => actions.back())
  if (pane.library.kind !== 'loaded') return [back, <Text key="not-loaded" dimColor>The library isn't loaded.</Text>]
  const { library } = pane.library
  const collections: Record<Kind, readonly { id: string }[]> = {
    persona: library.personas,
    session: library.sessions,
    directive: library.directives,
    kit: library.kits,
    skill: library.skills,
  }
  if (!collections[view.kind].some((x) => x.id === view.id)) {
    return [back, <Text key="missing">{`${view.kind} ${view.id} isn't in the library.`}</Text>]
  }
  const c: Context = { el, library, pane, session, actions, tools: shared(el, library, pane, session, actions), index: usedBy(library) }
  switch (view.kind) {
    case 'persona':
      return persona(c, view.id)
    case 'session':
      return sessionDetail(c, view.id)
    case 'directive':
      return directive(c, view.id)
    case 'kit':
      return kit(c, view.id)
    case 'skill':
      return skill(c, view.id)
  }
}
