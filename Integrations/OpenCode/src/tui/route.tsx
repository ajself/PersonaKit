import type { TuiPluginApi } from '@opencode-ai/plugin/tui'
import type { ScrollBoxRenderable } from '@opentui/core'
import { createMemo, createSignal, Match, onCleanup, Show, Switch } from 'solid-js'
import type { ContractIds, PaneState, SessionState, View } from '../../../ClaudeCode/types'
import { canUse } from '../../../ClaudeCode/hooks/lib/ids.ts'
import { usePrompt } from '../../../ClaudeCode/hooks/lib/prompts.ts'
import { loadLibrary, loadPreview, previewKey } from '../../../ClaudeCode/hooks/lib/runner.ts'
import type { RunnerDollar } from '../../../ClaudeCode/hooks/lib/runner.ts'
import { logFailure } from './log.ts'
import { prefill } from './prefill.ts'
import { ContractView } from './views/contract.tsx'
import { DetailView } from './views/detail.tsx'
import type { Detail } from './views/detail.tsx'
import { Button, createNav, LibraryHome, LibraryList, UiContext, viewLabel } from './views/library.tsx'
import type { PaneActions } from './views/library.tsx'

export const ROUTE = 'personakit'

/** What the route needs from the plugin: the process runner and executable, and the session state it shows. */
export type RouteDeps = {
  runner: RunnerDollar
  binary: string
  /** The observed state of `sessionID` (reactive); the empty state when the route was opened from home. */
  session: (sessionID: string | undefined) => SessionState
  /** Whether the manifest differs from the one the server plugin enforces (reactive). */
  manifestChanged: () => boolean
}

const COMMANDS = {
  back: 'personakit.route.back',
  next: 'personakit.route.next',
  previous: 'personakit.route.previous',
  press: 'personakit.route.press',
} as const

const initialPane: PaneState = { view: { kind: 'library' }, back: [], filter: '', library: { kind: 'idle' }, previews: {}, expanded: [], token: 0 }

const VIEW_KINDS = new Set(['contract', 'library', 'list', 'persona', 'session', 'directive', 'kit', 'skill'])

/** A `view` route param the route can show, else undefined. */
function viewParam(value: unknown): View | undefined {
  if (typeof value !== 'object' || value === null) return undefined
  const v = value as { kind?: unknown; id?: unknown; of?: unknown }
  if (typeof v.kind !== 'string' || !VIEW_KINDS.has(v.kind)) return undefined
  if (v.kind === 'contract' || v.kind === 'library') return { kind: v.kind }
  if (v.kind === 'list') return v.of === 'directives' || v.of === 'kits' || v.of === 'skills' ? { kind: 'list', of: v.of } : undefined
  return typeof v.id === 'string' ? ({ kind: v.kind, id: v.id } as View) : undefined
}

/**
 * Registers route `personakit` (params `{ sessionID?: string; view?: View }`): the Contract and the Library with
 * their detail views, a port of the Claude Code mod's `/pk` pane. Back pops the view stack; on a top view it returns
 * to the session the route was opened from (home without one). The route owns the pane state: the Library loads each
 * time the route opens and on Refresh, and a session view or a Contract lacking contract JSON reads its preview, all
 * through the shared loaders (`personakit list all --json`, `contract`, `export`). Use and Re-ground pre-fill the
 * prompt and never submit it. Returns the disposer; after it, nothing in flight updates the route.
 */
export function registerRoute(api: TuiPluginApi, deps: RouteDeps): () => void {
  let disposed = false
  const [pane, setPane] = createSignal<PaneState>(initialPane)
  const update = (change: (p: PaneState) => PaneState) => {
    if (!disposed) setPane(change)
  }
  /** Async work for a control; a failure is logged and never reaches OpenCode. */
  const safely = (work: () => Promise<void>) => void work().catch((error) => logFailure(api, error))

  /**
   * Loads the Library. Each call takes the next token and a result lands only while its token is still the latest, so
   * Refresh during a load replaces the first and a late answer is dropped. Refresh also drops every preview: the route
   * must not show a contract the library it just reloaded no longer agrees with.
   */
  const refreshLibrary = async () => {
    if (disposed) return
    const token = pane().token + 1
    update((p) => ({ ...p, token, library: { kind: 'loading', token }, previews: {} }))
    const library = await loadLibrary(deps.runner, deps.binary)
    update((p) => (p.token === token ? { ...p, library } : p))
  }

  /**
   * Reads the preview for `ids`, unless it is loaded or loading. A failed one is tried again. The result lands only
   * while the loading marker it claimed is still there, so a Refresh in between drops it.
   */
  const openPreview = async (ids: ContractIds) => {
    if (disposed) return
    const key = previewKey(ids)
    const current = pane().previews[key]
    if (current !== undefined && current.kind !== 'failed') return
    const claimed = pane().token
    update((p) => ({ ...p, previews: { ...p.previews, [key]: { kind: 'loading', token: claimed } } }))
    const preview = await loadPreview(deps.runner, deps.binary, ids)
    update((p) => {
      const marker = p.previews[key]
      return marker?.kind === 'loading' && marker.token === claimed ? { ...p, previews: { ...p.previews, [key]: preview } } : p
    })
  }

  /** The Contract's preview, when the resolution has export details but no contract JSON of its own. */
  const fillContract = (sessionID: string | undefined) => {
    const { main } = deps.session(sessionID)
    if (main?.details && !main.contract) safely(() => openPreview(main.ids))
  }

  /** A view's own reads: the Contract's preview, a session's preview. */
  const enter = (view: View, sessionID: string | undefined) => {
    if (view.kind === 'contract') fillContract(sessionID)
    if (view.kind === 'session') safely(() => openPreview({ sessionId: view.id }))
  }

  /** The route opened: on `view`, else on the Contract when one is in force and the Library otherwise. */
  const open = (sessionID: string | undefined, view: View | undefined) => {
    const first = view ?? (deps.session(sessionID).main ? { kind: 'contract' as const } : { kind: 'library' as const })
    update((p) => ({ ...p, view: first, back: [] }))
    safely(refreshLibrary)
    enter(first, sessionID)
  }

  /** Leaves the route for the session it was opened from, or home. */
  const leave = (sessionID: string | undefined) => {
    if (sessionID === undefined) api.route.navigate('home')
    else api.route.navigate('session', { sessionID })
  }

  /**
   * Returns to the session, then pre-fills `ids`' grounding prompt there for the person to review and send. OpenCode
   * inserts appended text only into a prompt on screen, and the route has none, so the session comes first.
   */
  const ground = (sessionID: string | undefined, ids: ContractIds) => {
    if (disposed || !canUse(ids)) return
    leave(sessionID)
    safely(async () => {
      if (!disposed) await prefill(api, usePrompt(ids))
    })
  }

  const actionsFor = (sessionID: string | undefined): PaneActions => ({
    // A top-level view clears the back stack; any other view stacks.
    go: (view) => {
      const isTop = view.kind === 'contract' || view.kind === 'library'
      update((p) => ({ ...p, view, back: isTop ? [] : [...p.back, p.view] }))
      enter(view, sessionID)
    },
    back: () => {
      const { back } = pane()
      if (back.length === 0) {
        if (!disposed) leave(sessionID)
        return
      }
      update((p) => ({ ...p, view: p.back.at(-1) ?? { kind: 'library' }, back: p.back.slice(0, -1) }))
    },
    setFilter: (filter) => update((p) => ({ ...p, filter })),
    refresh: () => safely(refreshLibrary),
    use: (sessionId) => ground(sessionID, { sessionId }),
    reground: () => {
      const { main } = deps.session(sessionID)
      if (main) ground(sessionID, main.ids)
    },
    toggle: (key) => update((p) => ({ ...p, expanded: p.expanded.includes(key) ? p.expanded.filter((k) => k !== key) : [...p.expanded, key] })),
  })

  function PersonaKitRoute(props: { params?: Record<string, unknown> }) {
    const sessionID = typeof props.params?.sessionID === 'string' ? props.params.sessionID : undefined
    const actions = actionsFor(sessionID)
    open(sessionID, viewParam(props.params?.view))

    let scroll: ScrollBoxRenderable | undefined
    const nav = createNav((id) => scroll?.scrollChildIntoView(id))
    const theme = () => api.theme.current
    const state = () => deps.session(sessionID)
    const view = createMemo(() => pane().view)
    const library = () => {
      const load = pane().library
      return load.kind === 'loaded' ? load.library : undefined
    }
    const backLabel = () => {
      const previous = pane().back.at(-1)
      return previous === undefined ? (sessionID === undefined ? 'Home' : 'Session') : viewLabel(previous, library())
    }
    const isContract = () => view().kind === 'contract'
    /** Esc: on the Library home with text in the filter, clears it; otherwise Back. */
    const escape = () => {
      const { view: current, filter } = pane()
      if (current.kind === 'library' && filter !== '') actions.setFilter('')
      else actions.back()
    }

    // Bound while the route is on screen. Typing goes to the Library's filter; these keys move, open and go back.
    onCleanup(
      api.keymap.registerLayer({
        commands: [
          { name: COMMANDS.back, title: 'PersonaKit: back', run: () => escape() },
          { name: COMMANDS.next, title: 'PersonaKit: next control', run: () => nav.move(1) },
          { name: COMMANDS.previous, title: 'PersonaKit: previous control', run: () => nav.move(-1) },
          { name: COMMANDS.press, title: 'PersonaKit: press the selected control', run: () => nav.press() },
        ],
        bindings: [
          { key: 'escape', cmd: COMMANDS.back },
          { key: 'down,tab', cmd: COMMANDS.next },
          { key: 'up,shift+tab', cmd: COMMANDS.previous },
          { key: 'return', cmd: COMMANDS.press },
        ],
      }),
    )

    return (
      <UiContext.Provider value={{ theme, nav }}>
        <box flexDirection="column" width="100%" height="100%" paddingLeft={2} paddingRight={2} paddingTop={1} gap={1}>
          <box flexDirection="row" columnGap={2} flexShrink={0}>
            <Button link label={`‹ ${backLabel()}`} onPress={() => actions.back()} />
            <text fg={theme().text}>
              <b>PersonaKit</b>
            </text>
            <Button label="Contract" color={isContract() ? theme().primary : theme().textMuted} onPress={() => actions.go({ kind: 'contract' })} />
            <Button label="Library" color={isContract() ? theme().textMuted : theme().primary} onPress={() => actions.go({ kind: 'library' })} />
          </box>
          <scrollbox ref={(r: ScrollBoxRenderable) => (scroll = r)} flexGrow={1}>
            <Show when={view()} keyed>
              {(v) => (
                <Switch>
                  <Match when={v.kind === 'contract'}>
                    <ContractView state={state()} manifestChanged={deps.manifestChanged()} pane={pane()} actions={actions} />
                  </Match>
                  <Match when={v.kind === 'library'}>
                    <LibraryHome session={state()} pane={pane()} actions={actions} />
                  </Match>
                  <Match when={v.kind === 'list' && v}>
                    {(list) => <LibraryList of={list().of} pane={pane()} actions={actions} />}
                  </Match>
                  <Match when={'id' in v && (v as Detail)}>
                    {(detail) => <DetailView view={detail()} pane={pane()} session={state()} actions={actions} />}
                  </Match>
                </Switch>
              )}
            </Show>
          </scrollbox>
          <text fg={theme().textMuted} flexShrink={0}>
            ↑↓ move · enter press · esc back
          </text>
        </box>
      </UiContext.Provider>
    )
  }

  const unregister = api.route.register([{ name: ROUTE, render: (input) => <PersonaKitRoute params={input.params} /> }])
  return () => {
    disposed = true
    unregister()
  }
}
