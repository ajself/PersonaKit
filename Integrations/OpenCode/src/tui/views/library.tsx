import type { TuiPluginApi } from '@opencode-ai/plugin/tui'
import type { Renderable, RGBA } from '@opentui/core'
import type { JSX } from '@opentui/solid'
import { children, createContext, createMemo, createSignal, For, Match, onCleanup, Show, Switch, useContext } from 'solid-js'
import type { Accessor } from 'solid-js'
import type { Contract, Library, LibraryError, LibraryLoad, PaneState, Scope, SessionState, Step, View } from '../../../../ClaudeCode/types'
import { canUse } from '../../../../ClaudeCode/hooks/lib/ids.ts'
import { filterLibrary, people } from '../../../../ClaudeCode/hooks/lib/libraryIndex.ts'
import type { FilterHit, PersonRow } from '../../../../ClaudeCode/hooks/lib/libraryIndex.ts'
import { sanitizeLine, sanitizeText } from '../text.ts'

// The pieces every route view draws with (buttons and their keyboard order, sections, rows, scope badges, steps),
// then the Library home and its lists. A port of the Claude Code mod's `views/parts.tsx` and `views/library.tsx`:
// the same rows, badges, states and copy. Library text is drawn through `sanitizeLine`, multi-line text through
// `sanitizeText`; ids are never sanitized for use, only for drawing.

export type Theme = TuiPluginApi['theme']['current']

/** What the route's controls do. Each is fire-and-forget: the route reports its own failures. */
export type PaneActions = {
  go(view: View): void
  back(): void
  setFilter(text: string): void
  refresh(): void
  use(sessionId: string): void
  reground(): void
  toggle(key: string): void
}

/** The label column's width, in cells: the longest label ("Compactions") and a space. */
export const LABEL_WIDTH = 12

export const line = sanitizeLine

type NavEntry = { id: string; press: () => void; isEnabled: () => boolean; node: () => Renderable | undefined }

/** The route's buttons in screen order, the one the keyboard selected, and moving and pressing it. */
export type Nav = {
  nextId(): string
  add(entry: NavEntry): () => void
  selected: Accessor<string | undefined>
  select(id: string | undefined): void
  move(delta: 1 | -1): void
  press(): void
}

/**
 * Keyboard order is screen order: top to bottom, then left to right, read from where each button is drawn, so it
 * follows wrapping and scrolling. A button not laid out yet sorts last. `reveal` scrolls the selection into view.
 */
export function createNav(reveal: (id: string) => void): Nav {
  const entries = new Map<string, NavEntry>()
  const [selected, setSelected] = createSignal<string | undefined>()
  let counter = 0
  const ordered = () =>
    [...entries.values()].sort((a, b) => {
      const na = a.node()
      const nb = b.node()
      if (na === undefined || nb === undefined) return na === undefined ? (nb === undefined ? 0 : 1) : -1
      return na.y - nb.y || na.x - nb.x
    })
  return {
    nextId: () => `personakit-button-${++counter}`,
    add(entry) {
      entries.set(entry.id, entry)
      return () => {
        entries.delete(entry.id)
        if (selected() === entry.id) setSelected(undefined)
      }
    },
    selected,
    select: setSelected,
    move(delta) {
      const list = ordered()
      if (list.length === 0) return
      const at = list.findIndex((entry) => entry.id === selected())
      const next = at === -1 ? (delta > 0 ? 0 : list.length - 1) : Math.min(list.length - 1, Math.max(0, at + delta))
      const id = list[next]!.id
      setSelected(id)
      reveal(id)
    },
    press() {
      const id = selected()
      const entry = id === undefined ? undefined : entries.get(id)
      if (entry !== undefined && entry.isEnabled()) entry.press()
    },
  }
}

export type Ui = { theme: () => Theme; nav: Nav }
export const UiContext = createContext<Ui>()

export function useUi(): Ui {
  const ui = useContext(UiContext)
  if (ui === undefined) throw new Error('PersonaKit views render inside the PersonaKit route')
  return ui
}

/** `text` cut into runs, each case-insensitive occurrence of any of `words` its own run. The runs join back to `text`. */
export function highlightRuns(text: string, words: readonly string[]): { text: string; isMatch: boolean }[] {
  const needles = [...new Set(words.map((w) => w.toLowerCase()).filter((w) => w !== ''))].sort((a, b) => b.length - a.length)
  if (needles.length === 0) return [{ text, isMatch: false }]
  const pattern = new RegExp(needles.map((w) => w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|'), 'gi')
  const runs: { text: string; isMatch: boolean }[] = []
  let at = 0
  for (const m of text.matchAll(pattern)) {
    if (m.index > at) runs.push({ text: text.slice(at, m.index), isMatch: false })
    runs.push({ text: m[0], isMatch: true })
    at = m.index + m[0].length
  }
  return at < text.length || runs.length === 0 ? [...runs, { text: text.slice(at), isMatch: false }] : runs
}

/** A step's first line, cut at the end of its first sentence or at `max` characters, whichever comes first. */
export function stepSummary(text: string, max = 80): string {
  const first = text.trim().split('\n')[0] ?? ''
  const sentence = /^.*?[.!?](?=\s|$)/.exec(first)?.[0] ?? first
  return sentence.length > max ? `${sentence.slice(0, max - 1).trimEnd()}…` : sentence
}

/**
 * What a view is called on a Back button that returns to it. A detail view is its target's display label from the
 * loaded `library`: persona name, directive title, kit name, skill name, session id. Its id stands in when the library
 * isn't loaded or lacks it.
 */
export function viewLabel(view: View, library?: Library): string {
  if (view.kind === 'contract') return 'Contract'
  if (view.kind === 'library') return 'Library'
  if (view.kind === 'list') return view.of === 'directives' ? 'Directives' : view.of === 'kits' ? 'Kits' : 'Skills'
  const label = (() => {
    switch (view.kind) {
      case 'persona':
        return library?.personas.find((p) => p.id === view.id)?.entity.name
      case 'directive':
        return library?.directives.find((d) => d.id === view.id)?.entity.title
      case 'kit':
        return library?.kits.find((k) => k.id === view.id)?.entity.name
      case 'skill':
        return library?.skills.find((x) => x.id === view.id)?.entity.name
      default:
        return undefined // a session is called by its id
    }
  })()
  return label ?? view.id
}

/**
 * Library text, drawn on one line, with each match of `words` bold in the accent color. The words read the same
 * unstyled.
 */
function Runs(props: { text: string; words?: readonly string[] }) {
  const { theme } = useUi()
  return (
    <For each={highlightRuns(line(props.text), props.words ?? [])}>
      {(run) =>
        run.isMatch ? (
          <b>
            <span style={{ fg: theme().accent }}>{run.text}</span>
          </b>
        ) : (
          run.text
        )
      }
    </For>
  )
}

/**
 * A control: an action drawn `[ label ]`, or a link drawn as its text. Mouse-up presses it; so does Enter once the
 * keyboard selected it. A disabled button draws muted and never runs `onPress`, however it is reached.
 */
export function Button(props: {
  label: string
  onPress: () => void
  disabled?: boolean
  link?: boolean
  color?: RGBA
  words?: readonly string[]
}) {
  const ui = useUi()
  const id = ui.nav.nextId()
  let node: Renderable | undefined
  onCleanup(ui.nav.add({ id, press: () => props.onPress(), isEnabled: () => props.disabled !== true, node: () => node }))
  const isSelected = () => ui.nav.selected() === id
  const fg = () =>
    isSelected() ? ui.theme().selectedListItemText : props.disabled ? ui.theme().textMuted : (props.color ?? ui.theme().primary)
  return (
    <box
      id={id}
      ref={(r: Renderable) => (node = r)}
      flexShrink={props.link ? 1 : 0}
      onMouseUp={() => {
        ui.nav.select(id)
        if (props.disabled !== true) props.onPress()
      }}
    >
      <text fg={fg()} bg={isSelected() ? ui.theme().primary : undefined} wrapMode={props.link ? 'word' : 'none'}>
        {props.link ? <Runs text={props.label} words={props.words} /> : `[ ${line(props.label)} ]`}
      </text>
    </box>
  )
}

/** A caption-styled title over its rows. */
export function Section(props: { title: string; children: JSX.Element }) {
  const { theme } = useUi()
  return (
    <box flexDirection="column">
      <text fg={theme().textMuted}>
        <b>{props.title.toUpperCase()}</b>
      </text>
      {props.children}
    </box>
  )
}

/** A muted label in a fixed column; its value, a string or elements, wraps in its own. */
export function Row(props: { label: string; children: JSX.Element | string }) {
  const { theme } = useUi()
  // Resolved once: each read of `props.children` would build its elements again.
  const value = children(() => props.children)
  return (
    <box flexDirection="row" alignItems="flex-start">
      <box width={LABEL_WIDTH} flexShrink={0}>
        <text fg={theme().textMuted}>{props.label}</text>
      </box>
      <box flexDirection="column" flexGrow={1} flexShrink={1}>
        {(() => {
          const resolved = value()
          return typeof resolved === 'string' ? <text fg={theme().text}>{line(resolved)}</text> : resolved
        })()}
      </box>
    </box>
  )
}

/** One line of muted library text. */
export function Muted(props: { text: string }) {
  const { theme } = useUi()
  return <text fg={theme().textMuted}>{line(props.text)}</text>
}

/**
 * The scope in words: `project`, `global`, or `project · overrides global`. The styling only reinforces the words:
 * project bold, global muted, an override in the warning color.
 */
export function ScopeBadge(props: { scope: Scope; shadows?: Scope | null }) {
  const { theme } = useUi()
  const words = () => (props.shadows == null ? props.scope : `${props.scope} · overrides ${props.shadows}`)
  return (
    <Switch fallback={<text fg={theme().textMuted}>{words()}</text>}>
      <Match when={props.shadows != null}>
        <text fg={theme().warning}>{words()}</text>
      </Match>
      <Match when={props.scope === 'project'}>
        <text fg={theme().text}>
          <b>{words()}</b>
        </text>
      </Match>
    </Switch>
  )
}

/**
 * `Use`, or `Switch` while another session is in force; the session in force is marked and has no button. A session
 * id the CLI could read as a flag, or that carries control characters, is shown but cannot be used.
 */
export function UseControl(props: { sessionId: string; inForceSessionId: string | undefined; use: (id: string) => void }) {
  const { theme } = useUi()
  const isUsable = () => canUse({ sessionId: props.sessionId })
  return (
    <Show when={props.sessionId !== props.inForceSessionId} fallback={<text fg={theme().success}>● in force</text>}>
      <box flexDirection="row" columnGap={1}>
        <Button
          label={props.inForceSessionId === undefined ? 'Use' : 'Switch'}
          disabled={!isUsable()}
          onPress={() => {
            if (isUsable()) props.use(props.sessionId)
          }}
        />
        <Show when={!isUsable()}>
          <Muted text="unsupported id" />
        </Show>
      </box>
    </Show>
  )
}

/**
 * A STEPS section: each step cut to its first line (all of it once `expanded` holds `toggleKey`), stop points marked
 * `◆ stop`, and a button that flips between the two.
 */
export function StepsSection(props: { steps: readonly Step[]; toggleKey: string; expanded: readonly string[]; toggle: (key: string) => void }) {
  const { theme } = useUi()
  const isOpen = () => props.expanded.includes(props.toggleKey)
  // The number sits in its own fixed-width box so a wrapped step's later lines align with its text.
  const numberWidth = () => `${props.steps.length}`.length + 2
  return (
    <Section title="Steps">
      <For each={props.steps}>
        {(step, i) => (
          <box flexDirection="row" alignItems="flex-start">
            <box width={numberWidth()} flexShrink={0}>
              <text fg={theme().textMuted}>{`${i() + 1}`}</text>
            </box>
            <box flexDirection="row" flexWrap="wrap" flexGrow={1} flexShrink={1} columnGap={1}>
              <text fg={theme().text}>{isOpen() ? sanitizeText(step.text) : line(stepSummary(step.text))}</text>
              <Show when={step.isStop}>
                <text fg={theme().warning}>◆ stop</text>
              </Show>
            </box>
          </box>
        )}
      </For>
      <box flexDirection="row">
        <Button label={isOpen() ? 'Show first lines' : 'Show full steps'} onPress={() => props.toggle(props.toggleKey)} />
      </box>
    </Section>
  )
}

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
export function LoadState(props: { load: Exclude<LibraryLoad, { kind: 'loaded' }> }) {
  const { theme } = useUi()
  return (
    <Switch>
      <Match when={props.load.kind === 'idle' || props.load.kind === 'loading'}>
        <text fg={theme().textMuted}>Loading the library…</text>
      </Match>
      <Match when={props.load.kind === 'no-library'}>
        <text fg={theme().text}>No PersonaKit library here: no .personakit in this project and no ~/.personakit.</text>
      </Match>
      <Match when={props.load.kind === 'unavailable' && props.load}>
        {(load) => (
          <text fg={theme().text}>
            {line(`Couldn't run ${load().binary}: ${load().detail}. Set the personakitPath option if PersonaKit is installed elsewhere.`)}
          </text>
        )}
      </Match>
      <Match when={props.load.kind === 'no-process'}>
        <text fg={theme().text}>This host can't run PersonaKit, so the Library isn't available here. The Contract view still works.</text>
      </Match>
      <Match when={props.load.kind === 'errors' && props.load}>
        {(load) => (
          <box flexDirection="column">
            <text fg={theme().text}>The library didn't load. Fix these and press Refresh:</text>
            <For each={errorGroups(load().errors)}>
              {({ label, files }) => (
                <box flexDirection="column">
                  <text fg={theme().text}>
                    <b>{label}</b>
                  </text>
                  <For each={files}>
                    {({ path, errors }) => (
                      <box flexDirection="column" marginLeft={2}>
                        <Muted text={path ?? '(no file)'} />
                        <For each={errors}>
                          {(e) => <text fg={theme().error}>{line(`${e.entityType}${e.id === null ? '' : ` ${e.id}`}: ${e.message}`)}</text>}
                        </For>
                      </box>
                    )}
                  </For>
                </box>
              )}
            </For>
          </box>
        )}
      </Match>
    </Switch>
  )
}

/**
 * A persona and the sessions that use it. A persona the library lacks (no scope) is its raw id, with nothing to open.
 * The persona's id is left off its line unless a filter word matches only the id, so the match has something to show.
 * A session's badge is left off when it only repeats its persona's scope; an override or a differing scope keeps it.
 */
function PersonRowView(props: { person: PersonRow; words: readonly string[]; inForceSessionId: string | undefined; actions: PaneActions }) {
  const { theme } = useUi()
  const lower = (text: string) => text.toLowerCase()
  const person = () => props.person
  const isIdOnlyMatch = () =>
    props.words.some(
      (w) =>
        lower(person().personaId).includes(w) &&
        !lower(person().name).includes(w) &&
        !person().sessions.some((s) => lower(s.directiveTitle).includes(w) || lower(s.id).includes(w)),
    )
  return (
    <box flexDirection="column">
      <box flexDirection="row" flexWrap="wrap" columnGap={1}>
        <Show
          when={person().scope}
          fallback={
            <text fg={theme().text}>
              <b>
                <Runs text={person().name} words={props.words} />
              </b>
            </text>
          }
        >
          {(scope) => (
            <>
              <Button link label={person().name} words={props.words} onPress={() => props.actions.go({ kind: 'persona', id: person().personaId })} />
              <Show when={isIdOnlyMatch()}>
                <text fg={theme().textMuted}>
                  <Runs text={person().personaId} words={props.words} />
                </text>
              </Show>
              <ScopeBadge scope={scope()} shadows={person().shadows} />
            </>
          )}
        </Show>
      </box>
      <Show
        when={person().sessions.length > 0}
        fallback={
          <Branch isLast={true}>
            <Muted text="No session uses this persona yet." />
          </Branch>
        }
      >
        <For each={person().sessions}>
          {(s, i) => (
            <Branch isLast={i() === person().sessions.length - 1}>
              <Button link label={s.directiveTitle} words={props.words} onPress={() => props.actions.go({ kind: 'session', id: s.id })} />
              <text fg={theme().textMuted}>
                <Runs text={s.id} words={props.words} />
              </text>
              <Show when={s.scope !== person().scope || s.shadows !== null}>
                <ScopeBadge scope={s.scope} shadows={s.shadows} />
              </Show>
              <UseControl sessionId={s.id} inForceSessionId={props.inForceSessionId} use={props.actions.use} />
            </Branch>
          )}
        </For>
      </Show>
    </box>
  )
}

/** A tree branch under a persona. The connector sits in its own fixed-width box so wrapped lines align with its text. */
function Branch(props: { isLast: boolean; children: JSX.Element }) {
  const { theme } = useUi()
  return (
    <box marginLeft={2} flexDirection="row" alignItems="flex-start">
      <box width={2} flexShrink={0}>
        <text fg={theme().textMuted}>{props.isLast ? '└ ' : '├ '}</text>
      </box>
      <box flexDirection="row" flexWrap="wrap" flexGrow={1} flexShrink={1} columnGap={1}>
        {props.children}
      </box>
    </box>
  )
}

/** A directive, kit, skill or person found by the filter, or listed: its name opens it. */
function HitRow(props: { hit: FilterHit; words: readonly string[]; actions: PaneActions }) {
  const { theme } = useUi()
  const hit = () => props.hit
  return (
    <box flexDirection="row" flexWrap="wrap" columnGap={1}>
      <Button
        link
        label={hit().label}
        words={props.words}
        onPress={() => props.actions.go({ kind: hit().kind === 'person' ? 'persona' : (hit().kind as 'directive' | 'kit' | 'skill'), id: hit().id })}
      />
      <Show when={hit().label !== hit().id}>
        <text fg={theme().textMuted}>
          <Runs text={hit().id} words={props.words} />
        </text>
      </Show>
      <ScopeBadge scope={hit().scope} shadows={hit().shadows} />
    </box>
  )
}

/** The scope legend: each root that exists, with how many sessions and personas live under it. */
function Legend(props: { library: Library }) {
  const { theme } = useUi()
  const roots = () =>
    (['project', 'global'] as const).flatMap((scope) => {
      const root = props.library.scopes[scope]
      if (root === undefined) return []
      const sessions = props.library.sessions.filter((s) => s.scope === scope).length
      const personas = props.library.personas.filter((p) => p.scope === scope).length
      return [{ scope, root, counts: `${count(sessions, 'session')} · ${count(personas, 'persona')}` }]
    })
  return (
    <box flexDirection="column">
      <For each={roots()}>
        {(r) => (
          <text fg={theme().text}>
            <b>{r.scope}</b>
            {`  ${line(r.root)}  `}
            <span style={{ fg: theme().textMuted }}>{r.counts}</span>
          </text>
        )}
      </For>
    </box>
  )
}

/** The Library's title bar: the title, and Refresh wherever the host can run PersonaKit. */
function Bar(props: { load: LibraryLoad; actions: PaneActions }) {
  const { theme } = useUi()
  return (
    <box flexDirection="row" columnGap={2}>
      <text fg={theme().text}>
        <b>Library</b>
      </text>
      <Show when={props.load.kind !== 'no-process'}>
        <Button label="Refresh" onPress={() => props.actions.refresh()} />
      </Show>
    </box>
  )
}

/**
 * The Library home: the load state, or once loaded the roots warning, the scope legend, the filter, then People and
 * Components, or the filter's results grouped by kind while text is typed.
 */
export function LibraryHome(props: { session: SessionState; pane: PaneState; actions: PaneActions }) {
  const { theme } = useUi()
  const load = createMemo(() => props.pane.library)
  const text = createMemo(() => props.pane.filter.trim())
  const words = createMemo(() => filterWords(text()))
  const inForceSessionId = createMemo(() => props.session.main?.ids.sessionId)
  const loaded = createMemo(() => {
    const current = load()
    return current.kind === 'loaded' ? current.library : undefined
  })
  const found = createMemo(() => {
    const library = loaded()
    return library === undefined ? undefined : filterLibrary(library, text(), inForceSessionId())
  })
  const rows = createMemo(() => {
    const library = loaded()
    return library === undefined ? [] : people(library, inForceSessionId())
  })
  const hasMatches = () => {
    const f = found()
    return f !== undefined && (f.people.length > 0 || KINDS.some(({ of }) => f[of].length > 0))
  }
  const warning = () => {
    const library = loaded()
    return library === undefined ? undefined : rootsMismatchWarning(props.session.main?.contract?.scope, library.scopes)
  }
  return (
    <box flexDirection="column" gap={1}>
      <Bar load={load()} actions={props.actions} />
      <Show when={loaded()} fallback={<LoadState load={load() as Exclude<LibraryLoad, { kind: 'loaded' }>} />}>
        {(library) => (
          <>
            <Show when={warning()}>{(text) => <text fg={theme().warning}>{line(text())}</text>}</Show>
            <Legend library={library()} />
            <box border borderStyle="rounded" borderColor={theme().border} paddingLeft={1} paddingRight={1} title="Filter">
              <input
                value={props.pane.filter}
                placeholder="id, name, project or global"
                focused
                onInput={(value: string) => props.actions.setFilter(value)}
              />
            </box>
            <Show
              when={text() === ''}
              fallback={
                <Show when={hasMatches()} fallback={<text fg={theme().text}>{line(`Nothing matches “${text()}”.`)}</text>}>
                  <Show when={found()!.people.length > 0}>
                    <Section title={`People · ${found()!.people.length}`}>
                      <For each={found()!.people}>
                        {(person) => <PersonRowView person={person} words={words()} inForceSessionId={inForceSessionId()} actions={props.actions} />}
                      </For>
                    </Section>
                  </Show>
                  <For each={KINDS}>
                    {({ of, title }) => (
                      <Show when={found()![of].length > 0}>
                        <Section title={`${title} · ${found()![of].length}`}>
                          <For each={found()![of]}>{(hit) => <HitRow hit={hit} words={words()} actions={props.actions} />}</For>
                        </Section>
                      </Show>
                    )}
                  </For>
                </Show>
              }
            >
              <Show when={rows().length > 0}>
                <Section title="People">
                  <text fg={theme().textMuted}>Who you can work with, and the jobs you can start with them.</text>
                  <For each={rows()}>
                    {(person) => <PersonRowView person={person} words={[]} inForceSessionId={inForceSessionId()} actions={props.actions} />}
                  </For>
                </Section>
              </Show>
              <Section title="Components">
                <For each={KINDS}>
                  {({ of, title }) => (
                    <box flexDirection="row" columnGap={1}>
                      <Button link label={title} onPress={() => props.actions.go({ kind: 'list', of })} />
                      <text fg={theme().textMuted}>{`${library()[of].length}`}</text>
                    </box>
                  )}
                </For>
              </Section>
            </Show>
          </>
        )}
      </Show>
    </box>
  )
}

/** The plain list of one kind, sorted by display label and then id. */
export function LibraryList(props: { of: Kind; pane: PaneState; actions: PaneActions }) {
  const { theme } = useUi()
  const kind = () => KINDS.find((k) => k.of === props.of)!
  const load = createMemo(() => props.pane.library)
  const hits = createMemo(() => {
    const current = load()
    return current.kind === 'loaded' ? filterLibrary(current.library, '')[props.of] : undefined
  })
  return (
    <box flexDirection="column">
      <Show when={hits()} fallback={<LoadState load={load() as Exclude<LibraryLoad, { kind: 'loaded' }>} />}>
        {(list) => (
          <>
            <text fg={theme().text}>
              <b>{kind().title}</b>
            </text>
            <text fg={theme().textMuted}>{count(list().length, kind().noun)}</text>
            <For each={list()}>{(hit) => <HitRow hit={hit} words={[]} actions={props.actions} />}</For>
          </>
        )}
      </Show>
    </box>
  )
}
