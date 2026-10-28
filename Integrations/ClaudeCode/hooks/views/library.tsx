import type { RenderChildren } from 'claude-code'

import type { Contract, Library, LibraryError, LibraryLoad, PaneState, Scope, SessionState } from '../../types'
import { filterLibrary, people } from '../lib/libraryIndex'
import type { FilterHit, PersonRow } from '../lib/libraryIndex'
import { parts, viewLabel } from './parts'
import type { El, PaneActions } from './parts'

type Kind = 'directives' | 'kits' | 'skills'
const KINDS: { of: Kind; title: string; noun: string }[] = [
  { of: 'directives', title: 'Directives', noun: 'directive' },
  { of: 'kits', title: 'Kits', noun: 'kit' },
  { of: 'skills', title: 'Skills', noun: 'skill' },
]

/** The query's words that match text: all but the scope words, which filter by scope instead. */
const filterWords = (query: string) => query.toLowerCase().split(/\s+/).filter((w) => w !== '' && w !== 'project' && w !== 'global')
const count = (n: number, noun: string) => `${n} ${noun}${n === 1 ? '' : 's'}`
const distinct = (paths: (string | undefined)[]) => [...new Set(paths.filter((p): p is string => p !== undefined && p !== ''))]

/**
 * The warning for a Library loaded from other roots than the contract in force came from, else undefined. The roots
 * compare as sets of paths: the CLI reports an equal project and global root once, as `global`, so keys can differ
 * while the roots are the same.
 */
export function rootsMismatchWarning(scope: Contract['scope'] | undefined, scopes: Library['scopes']): string | undefined {
  const contractRoots = distinct([scope?.projectRoot, scope?.globalRoot])
  const libraryRoots = distinct([scopes.project, scopes.global])
  if (contractRoots.length === 0) return undefined
  const isSame = contractRoots.length === libraryRoots.length && contractRoots.every((root) => libraryRoots.includes(root))
  return isSame
    ? undefined
    : `⚠ Library loaded from ${libraryRoots.join(', ')}; the contract in force came from ${contractRoots.join(', ')}.`
}

/** The Library's errors grouped by scope (project, global, then those with none), and within one by path. */
function errorGroups(errors: LibraryError[]): { label: string; files: { path: string | null; errors: LibraryError[] }[] }[] {
  const order: (Scope | null)[] = ['project', 'global', null]
  return order.flatMap((scope) => {
    const inScope = errors.filter((e) => e.scope === scope)
    const paths = [...new Set(inScope.map((e) => e.path))].sort((a, b) => (a === null ? 1 : b === null ? -1 : a < b ? -1 : a > b ? 1 : 0))
    return inScope.length === 0
      ? []
      : [{ label: scope ?? 'library', files: paths.map((path) => ({ path, errors: inScope.filter((e) => e.path === path) })) }]
  })
}

/** The Library's load states, drawn. Only `loaded` has no state to draw. */
function loadState(el: El, load: Exclude<LibraryLoad, { kind: 'loaded' }>): RenderChildren[] {
  const { Box, Text } = el
  switch (load.kind) {
    case 'idle':
    case 'loading':
      return [<Text key="loading" dimColor>Loading the library…</Text>]
    case 'no-library':
      return [<Text key="no-library">No PersonaKit library here: no .personakit in this project and no ~/.personakit.</Text>]
    case 'unavailable':
      return [
        <Text key="unavailable">
          {`Couldn't run ${load.binary}: ${load.detail}. Set the personakitPath option if PersonaKit is installed elsewhere.`}
        </Text>,
      ]
    case 'no-process':
      return [<Text key="no-process">This host can't run PersonaKit, so the Library isn't available here. The Contract view still works.</Text>]
    case 'errors':
      return [
        <Text key="errors">The library didn't load. Fix these and press Refresh:</Text>,
        ...errorGroups(load.errors).map(({ label, files }) => (
          <Box key={`errors-${label}`} flexDirection="column">
            <Text weight="semibold">{label}</Text>
            {files.map(({ path, errors }) => (
              <Box key={`errors-${label}-${path ?? ''}`} flexDirection="column" marginLeft={2}>
                <Text mono dimColor>{path ?? '(no file)'}</Text>
                {errors.map((e, i) => (
                  <Text key={`error-${i}`} color="error">{`${e.entityType}${e.id === null ? '' : ` ${e.id}`}: ${e.message}`}</Text>
                ))}
              </Box>
            ))}
          </Box>
        )),
      ]
  }
}

/** The rows and controls the Library's views share. */
function shared(el: El, session: SessionState, actions: PaneActions, words: readonly string[] = []) {
  const { Box, Text, Button } = el
  const { scopeBadge, highlighted } = parts(el)
  const inForceSessionId = session.main?.ids.sessionId

  /** A name that opens its detail view. */
  const link = (kind: 'persona' | 'session' | 'directive' | 'kit' | 'skill', id: string, label: string) => (
    <Button key={`open:${kind}:${id}`} onPress={() => actions.go({ kind, id })}>
      {highlighted(label, words)}
    </Button>
  )

  /**
   * A persona and the sessions that use it. A persona the library lacks (no scope) is its raw id, with nothing to open.
   * The persona's id is left off its line unless a filter word matches only the id, so the match has something to show.
   * A session's badge is left off when it only repeats its persona's scope; an override or a differing scope keeps it.
   */
  const personRow = (person: PersonRow) => {
    const lower = (text: string) => text.toLowerCase()
    const isIdOnlyMatch = words.some(
      (w) =>
        lower(person.personaId).includes(w) &&
        !lower(person.name).includes(w) &&
        !person.sessions.some((s) => lower(s.directiveTitle).includes(w) || lower(s.id).includes(w)),
    )
    // The connector sits in its own fixed-width box so a wrapped line's later lines align with its text.
    const branch = (key: string, isLast: boolean, ...children: RenderChildren[]) => (
      <Box key={key} marginLeft={2} flexDirection="row" alignItems="flex-start">
        <Box width={2} flexShrink={0}>
          <Text dimColor>{isLast ? '└ ' : '├ '}</Text>
        </Box>
        <Box flexDirection="row" flexWrap="wrap" flexGrow={1} flexShrink={1} alignItems="center" columnGap={1}>
          {children}
        </Box>
      </Box>
    )
    return (
      <Box key={`person-${person.personaId}`} flexDirection="column">
        <Box flexDirection="row" flexWrap="wrap" alignItems="center" columnGap={1}>
          {person.scope === null
            ? [<Text key="name" weight="semibold">{highlighted(person.name, words)}</Text>]
            : [
                link('persona', person.personaId, person.name),
                isIdOnlyMatch && <Text key="id" dimColor>{highlighted(person.personaId, words)}</Text>,
                scopeBadge(person.scope, person.shadows),
              ]}
        </Box>
        {person.sessions.length === 0
          ? branch('no-session', true, <Text key="none" dimColor>No session uses this persona yet.</Text>)
          : person.sessions.map((s, i) =>
              branch(
                `session-${s.id}`,
                i === person.sessions.length - 1,
                link('session', s.id, s.directiveTitle),
                <Text key="id" dimColor>{highlighted(s.id, words)}</Text>,
                (s.scope !== person.scope || s.shadows !== null) && scopeBadge(s.scope, s.shadows),
                s.inForce ? (
                  <Text key="in-force" color="success">● in force</Text>
                ) : (
                  <Button key={`use:${s.id}`} onPress={() => actions.use(s.id)}>
                    {inForceSessionId === undefined ? 'Use' : 'Switch'}
                  </Button>
                ),
              ),
            )}
      </Box>
    )
  }

  const hitRow = (hit: FilterHit) => (
    <Box key={`${hit.kind}-${hit.id}`} flexDirection="row" flexWrap="wrap" alignItems="center" columnGap={1}>
      {link(hit.kind === 'person' ? 'persona' : hit.kind, hit.id, hit.label)}
      {hit.label !== hit.id && <Text dimColor>{highlighted(hit.id, words)}</Text>}
      {scopeBadge(hit.scope, hit.shadows)}
    </Box>
  )

  return { inForceSessionId, personRow, hitRow }
}

/** The scope legend: each root that exists, with how many sessions and personas live under it. */
function legend({ Box, Text }: El, library: Library) {
  return (['project', 'global'] as const).flatMap((scope) => {
    const root = library.scopes[scope]
    if (root === undefined) return []
    const sessions = library.sessions.filter((s) => s.scope === scope).length
    const personas = library.personas.filter((p) => p.scope === scope).length
    return [
      <Box key={`legend-${scope}`}>
        <Text>
          <Text weight="semibold">{scope}</Text>
          {'  '}
          <Text mono>{root}</Text>
          {'  '}
          <Text dimColor>{`${count(sessions, 'session')} · ${count(personas, 'persona')}`}</Text>
        </Text>
      </Box>,
    ]
  })
}

/**
 * The Library home: the load state, or once loaded the roots warning, the scope legend, the filter (where the surface
 * has an `Input`), then People and Components, or the filter's results grouped by kind while text is typed.
 */
export function libraryHome(el: El, session: SessionState, pane: PaneState, actions: PaneActions): RenderChildren[] {
  const { Box, Text, Button, Input, surface } = el
  const { section } = parts(el)
  const { library: load } = pane
  const text = pane.filter.trim()
  const { inForceSessionId, personRow, hitRow } = shared(el, session, actions, filterWords(text))

  // The terminal draws an `Input` as bare text, so a border is what makes it read as a field; other surfaces draw their own.
  const field = (input: RenderChildren) =>
    surface === 'terminal' ? (
      <Box key="filter-field" borderStyle="round" paddingX={1}>
        {input}
      </Box>
    ) : (
      input
    )

  const bar = (
    <Box key="bar" flexDirection="row" alignItems="center" columnGap={2}>
      <Text size="title" weight="semibold">
        Library
      </Text>
      {load.kind !== 'no-process' && (
        <Button key="refresh" onPress={() => actions.refresh()}>
          Refresh
        </Button>
      )}
    </Box>
  )
  if (load.kind !== 'loaded') return [bar, ...loadState(el, load)]

  const { library } = load
  const found = filterLibrary(library, text, inForceSessionId)
  const groups = [
    found.people.length > 0 && section(`People · ${found.people.length}`, ...found.people.map(personRow)),
    ...KINDS.map(({ of, title }) => found[of].length > 0 && section(`${title} · ${found[of].length}`, ...found[of].map(hitRow))),
  ]
  const rows = people(library, inForceSessionId)
  const home = [
    rows.length > 0 &&
      section(
        'People',
        <Text key="people-caption" dimColor>
          Who you can work with, and the jobs you can start with them.
        </Text>,
        ...rows.map(personRow),
      ),
    section(
      'Components',
      ...KINDS.map(({ of, title }) => (
        <Button key={`list:${of}`} onPress={() => actions.go({ kind: 'list', of })}>
          {title} <Text dimColor>{library[of].length}</Text>
        </Button>
      )),
    ),
  ]
  const warning = rootsMismatchWarning(session.main?.contract?.scope, library.scopes)
  return [
    bar,
    warning !== undefined && (
      <Text key="roots-mismatch" color="warning">
        {warning}
      </Text>
    ),
    <Box key="legend" flexDirection="column">
      {legend(el, library)}
    </Box>,
    Input &&
      field(
        <Input
          key="filter"
          label="Filter"
          placeholder="id, name, project or global"
          value={pane.filter}
          onInput={(value) => actions.setFilter(value)}
          onSubmit={(value) => actions.setFilter(value)}
        />,
      ),
    ...(text === '' ? home : groups.some(Boolean) ? groups : [<Text key="no-matches">{`Nothing matches “${text}”.`}</Text>]),
  ]
}

/** The plain list of one kind, sorted by display label and then id, under a Back button to where it was opened from. */
export function libraryList(el: El, of: Kind, session: SessionState, pane: PaneState, actions: PaneActions): RenderChildren[] {
  const { Text } = el
  const { backButton } = parts(el)
  const { library: load } = pane
  const { title, noun } = KINDS.find((k) => k.of === of)!
  const back = backButton(viewLabel(pane.back.at(-1) ?? { kind: 'library' }), () => actions.back())
  if (load.kind !== 'loaded') return [back, ...loadState(el, load)]
  const hits = filterLibrary(load.library, '')[of]
  const { hitRow } = shared(el, session, actions)
  return [
    back,
    <Text key="title" size="title" weight="semibold">
      {title}
    </Text>,
    <Text key="count" dimColor>
      {count(hits.length, noun)}
    </Text>,
    ...hits.map(hitRow),
  ]
}
