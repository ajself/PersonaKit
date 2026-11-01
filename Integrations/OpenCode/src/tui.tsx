import type { TuiPluginApi, TuiPluginMeta, TuiPluginModule } from '@opencode-ai/plugin/tui'
import { realpathSync } from 'node:fs'
import { createEffect, createRoot, createSignal } from 'solid-js'
import type { Accessor, Setter } from 'solid-js'
import type { Enforcement, LibraryLoad, SessionState } from '../../ClaudeCode/types'
import { openCodeHost } from '../../ClaudeCode/hooks/lib/host.ts'
import { canUse, isValidId } from '../../ClaudeCode/hooks/lib/ids.ts'
import { usePrompt } from '../../ClaudeCode/hooks/lib/prompts.ts'
import { loadLibrary, mcpServerName, personakitBinary } from '../../ClaudeCode/hooks/lib/runner.ts'
import { initial } from '../../ClaudeCode/hooks/lib/session.ts'
import { readManifestSnapshot } from './enforce.ts'
import { openCodeEnforcement, pluginListed } from './tui/enforcement.ts'
import { rebuildFrom } from './tui/observer.ts'
import { readRegularFileText } from './regularFile.ts'
import { logFailure } from './tui/log.ts'
import { prefill } from './tui/prefill.ts'
import { registerRoute, ROUTE } from './tui/route.tsx'
import { createSpawnRunner } from './tui/spawnRunner.ts'
import { sanitizeLine } from './tui/text.ts'
import { Chip, chipText } from './tui/views/chip.tsx'
import { Sidebar } from './tui/views/sidebar.tsx'

// How far up `parentID` a subagent's session is followed to the session being tracked.
const MAX_DEPTH = 8
// OpenCode starts enabled plugins, server and TUI, within this many seconds of launch; a later first `tui()` is one
// enabled or installed mid-session, after the server plugin took its snapshot.
const STARTUP_WINDOW_SECONDS = 15

/** The enforcement manifest as found now: what identifies it (`signature`), and what the status may judge. */
type ManifestRead = { signature: string; manifest: { path: string; text: string | undefined } | undefined }

/**
 * The manifest as the server plugin reads it. Several manifests, or one that cannot be listed or read, come back
 * without text, which reads as an unreadable manifest and never as enforced.
 */
function readManifest(directory: string, worktree: string): ManifestRead {
  const { find, bytes, sha256 } = readManifestSnapshot(directory, worktree)
  if (find.kind === 'none') return { signature: 'none', manifest: undefined }
  if (find.kind === 'many') {
    const path = find.paths.join(', ')
    return { signature: `many:${path}`, manifest: { path, text: undefined } }
  }
  if (bytes === undefined) return { signature: `unreadable:${find.path}`, manifest: { path: find.path, text: undefined } }
  return { signature: `one:${find.path}:${sha256}`, manifest: { path: find.path, text: bytes.toString('utf8') } }
}

/**
 * The manifest snapshot per project (`directory` and `worktree`), the one the server plugin enforces: taken on the
 * first `tui()` call in this process, the moment the server plugin takes its own when that call is at startup, and
 * taken again only when the instance is disposed, after which OpenCode starts the server plugin again and it takes a
 * fresh one. Turning the TUI plugin off and on runs `tui()` again without restarting the server plugin, so it reuses
 * the snapshot (as unconfirmed: see `isUnconfirmed`).
 */
const snapshots = new Map<string, ManifestRead>()

const snapshotKey = (directory: string, worktree: string) => `${directory}\u0000${worktree}`

function snapshotFor(directory: string, worktree: string): ManifestRead {
  const key = snapshotKey(directory, worktree)
  const known = snapshots.get(key)
  if (known) return known
  const read = readManifest(directory, worktree)
  snapshots.set(key, read)
  return read
}

/** Whether two directory paths name the same directory, `/tmp` and `/private/tmp` alike. */
function sameDirectory(a: string, b: string): boolean {
  if (a === b) return true
  try {
    return realpathSync(a) === realpathSync(b)
  } catch {
    return false
  }
}

/** Why `/pk-use` has nothing to offer, in one line. */
function libraryProblem(load: Exclude<LibraryLoad, { kind: 'loaded' }>): string {
  switch (load.kind) {
    case 'no-library':
      return 'PersonaKit: no library here (no .personakit in this project and no ~/.personakit)'
    case 'missing':
      return `PersonaKit: couldn't run ${load.binary}: ${load.detail}. Set the personakitPath option if PersonaKit is installed elsewhere.`
    case 'outdated':
      return `PersonaKit: this needs PersonaKit 2.2.0 or later.${load.detail ? ` ${load.detail}` : ''}`
    case 'unavailable':
      return `PersonaKit: couldn't run ${load.binary}: ${load.detail}.`
    case 'errors':
      return 'PersonaKit: the library has errors; open /pk to see them'
    case 'no-process':
      return "PersonaKit: this host can't run PersonaKit"
    case 'idle':
    case 'loading':
      return 'PersonaKit: the library is still loading'
  }
}

/** One session's state and what rebuilding it needs: subagent sessions, the rebuild in flight. */
type Tracked = {
  state: Accessor<SessionState>
  setState: Setter<SessionState>
  children: Set<string>
  dirty: boolean
  running: Promise<void> | undefined
  dispose: () => void
}

/**
 * The PersonaKit TUI: the status chip beside the prompt, the sidebar panel, `/pk` (the Library route) and `/pk-use`.
 * It observes the transcript and never writes a file or submits a prompt; it runs `personakit list all --json`,
 * `contract` and `export` only on the person's action (`/pk-use`, the route opening, Refresh, a preview). Options:
 * `personakitPath` (the executable, `personakit` on PATH by default) and `mcpServerName` (the trusted PersonaKit MCP
 * server, `personakit` by default). OpenCode passes three arguments; `uptime`, the process age in seconds, is for
 * tests.
 */
const tui = async (
  api: TuiPluginApi,
  options: Parameters<TuiPluginModule['tui']>[1],
  _meta?: TuiPluginMeta,
  uptime: () => number = () => process.uptime(),
): Promise<void> => {
  const binary = personakitBinary(options ?? {})
  const configured = mcpServerName(options ?? {})
  const { directory, worktree } = api.state.path
  const runner = createSpawnRunner({ cwd: directory })

  // The server enforces its snapshot, so the status does too: a manifest that later appears, changes or goes away is
  // only a warning until the server plugin starts again. Whether the plugin is listed is read from the config each
  // time: OpenCode refreshes it only when it reloads the instance, which also starts the server plugin again.
  // Now, at startup, not at first use: a manifest written before anything is drawn is still a change.
  // A later `tui()` call (the plugin turned off and on) reuses the snapshot, but the instance may have reloaded while
  // the plugin was off, unseen, and the server taken a fresh one. A first call after startup (the plugin enabled or
  // installed mid-session) takes its snapshot later than the server took its own. Until the next instance dispose
  // retakes it, either way any manifest present is shown as changed, never as enforced.
  let isUnconfirmed = snapshots.has(snapshotKey(directory, worktree)) || uptime() >= STARTUP_WINDOW_SECONDS
  snapshotFor(directory, worktree)
  const enforcementNow = (): Enforcement =>
    openCodeEnforcement(undefined, snapshotFor(directory, worktree).manifest, pluginListed(api.state.config.plugin))
  // Set on dispose: work still in flight then draws, toasts and pre-fills nothing.
  let disposed = false
  /** Async work for a handler; observe-only, so a failure is logged and never reaches OpenCode. */
  const safely = (work: () => Promise<void>): Promise<void> => work().catch((error) => logFailure(api, error))
  const [manifestChanged, setManifestChanged] = createSignal(false)

  const tracked = new Map<string, Tracked>()

  const viewed = (): string | undefined => {
    const current = api.route.current
    const id = current.name === 'session' ? current.params?.sessionID : undefined
    return typeof id === 'string' ? id : undefined
  }

  const servers = () =>
    [...new Set([...Object.keys(api.state.config.mcp ?? {}), ...api.state.mcp().map((server) => server.name)])].sort()

  /** Main's messages, with its subagents' non-user messages merged in by creation time, oldest first. */
  const messagesOf = (sessionID: string, children: ReadonlySet<string>) => {
    const own = api.state.session.messages(sessionID)
    if (children.size === 0) return own
    const keyed = [
      ...own.map((message, order) => ({ message, rank: 0, order })),
      ...[...children].sort().flatMap((child, rank) =>
        api.state.session
          .messages(child)
          .filter((m) => m.role !== 'user')
          .map((message, order) => ({ message, rank: rank + 1, order })),
      ),
    ]
    keyed.sort((a, b) => a.message.time.created - b.message.time.created || a.rank - b.rank || a.order - b.order)
    return keyed.map((entry) => entry.message)
  }

  const rebuildOne = async (sessionID: string, entry: Tracked): Promise<SessionState> => {
    const now = readManifest(directory, worktree).signature
    setManifestChanged(now !== snapshotFor(directory, worktree).signature || (isUnconfirmed && now !== 'none'))
    const state = await rebuildFrom(
      messagesOf(sessionID, entry.children),
      (messageID) => api.state.part(messageID),
      openCodeHost(servers()),
      configured,
      enforcementNow(),
      sessionID,
      readRegularFileText,
    )
    // Each compaction is a user message with a compaction part, so the history alone counts them (a restart keeps
    // them, and an automatic compaction's extra "continue" message is not one). A main resolution at a later user turn
    // answers it.
    const users = api.state.session.messages(sessionID).filter((m) => m.role === 'user')
    const compactions = users.filter(
      (m, i) => api.state.part(m.id).some((p) => p.type === 'compaction') && (state.main === undefined || i + 1 > state.main.turn),
    ).length
    return { ...state, compactions }
  }

  /** Rebuilds `sessionID` once whatever is in flight settles; requests made meanwhile fold into one more run. */
  const schedule = (sessionID: string): Promise<void> => {
    const entry = tracked.get(sessionID)
    if (entry === undefined) return Promise.resolve()
    entry.dirty = true
    entry.running ??= (async () => {
      while (entry.dirty) {
        entry.dirty = false
        // After OpenCode's own store has taken the event that asked for this.
        await new Promise((resolve) => setTimeout(resolve, 0))
        try {
          const next = await rebuildOne(sessionID, entry)
          if (!disposed) entry.setState(next)
        } catch (error) {
          // Observe-only: a failed rebuild leaves the last state in place.
          logFailure(api, error, 'rebuild failed')
        }
      }
      entry.running = undefined
    })()
    return entry.running
  }

  /** The tracked entry for `sessionID`, started on first use; its history rebuilds as OpenCode loads it. */
  const track = (sessionID: string): Tracked => {
    const existing = tracked.get(sessionID)
    if (existing) return existing
    const [state, setState] = createSignal<SessionState>({ ...initial, enforcement: enforcementNow() })
    const entry: Tracked = { state, setState, children: new Set(), dirty: false, running: undefined, dispose: () => {} }
    tracked.set(sessionID, entry)
    // OpenCode loads a session's history into its store without an event; a change in its length asks for a rebuild.
    entry.dispose = createRoot((dispose) => {
      createEffect(() => {
        void api.state.session.messages(sessionID).length
        void schedule(sessionID)
      })
      return dispose
    })
    return entry
  }

  /**
   * Rebuilds every tracked session `sessionID` belongs to: itself, and each tracked ancestor up its `parentID` chain,
   * which takes it as a subagent's session.
   */
  const touched = (sessionID: string) => {
    let id: string | undefined = sessionID
    for (let depth = 0; id !== undefined && depth <= MAX_DEPTH; depth += 1) {
      const entry = tracked.get(id)
      if (entry !== undefined) {
        if (id !== sessionID) entry.children.add(sessionID)
        void schedule(id)
      }
      id = api.state.session.get(id)?.parentID
    }
  }

  /** A compaction rebuilds the session it belongs to, and the viewed one, with a contract in force, is told. */
  const compacted = async (sessionID: string) => {
    // A subagent's compaction is its own: an untracked session is neither rebuilt nor told.
    const isViewed = sessionID === viewed()
    if (!isViewed && !tracked.has(sessionID)) return
    const entry = track(sessionID)
    await schedule(sessionID)
    const { main } = entry.state()
    if (disposed || !isViewed || main === undefined) return
    const id = main.ids.sessionId ?? main.ids.personaId ?? 'the contract'
    api.ui.toast({
      variant: 'warning',
      title: 'PersonaKit',
      message: sanitizeLine(`Context compacted: re-ground ${id}? Re-ground is in the sidebar.`),
    })
  }

  /**
   * `/connect`, an OAuth callback or an org switch disposes the instance, and OpenCode starts the server plugin again,
   * which takes a fresh snapshot: so does the status. Every tracked session rebuilds; the config OpenCode reloads with
   * the instance is read at each rebuild, and its arrival triggers one too (below).
   */
  const instanceDisposed = () => {
    snapshots.set(snapshotKey(directory, worktree), readManifest(directory, worktree))
    isUnconfirmed = false
    rebuildAll()
  }

  const rebuildAll = () => {
    for (const sessionID of tracked.keys()) void schedule(sessionID)
  }

  // The config arrives after an instance reload without an event of its own; a new plugin list asks for a rebuild.
  const disposeConfigWatch = createRoot((dispose) => {
    let seen: string | undefined
    createEffect(() => {
      const plugins = JSON.stringify(api.state.config.plugin ?? [])
      if (seen !== undefined && plugins !== seen) rebuildAll()
      seen = plugins
    })
    return dispose
  })

  const unsubscribe = [
    api.event.on('message.updated', (event) => touched(event.properties.sessionID)),
    api.event.on('message.part.updated', (event) => {
      const { part } = event.properties
      const finished = part.type === 'tool' && (part.state.status === 'completed' || part.state.status === 'error')
      if (finished || part.type === 'compaction') touched(part.sessionID)
    }),
    api.event.on('session.compacted', (event) => void safely(() => compacted(event.properties.sessionID))),
    api.event.on('server.instance.disposed', (event) => {
      if (sameDirectory(event.properties.directory, directory)) instanceDisposed()
    }),
    api.event.on('global.disposed', () => instanceDisposed()),
  ]

  const reground = (sessionID: string) => {
    const { main } = track(sessionID).state()
    if (!disposed && main && canUse(main.ids)) void safely(async () => void (await prefill(api, usePrompt(main.ids))))
  }

  const useSession = async () => {
    const load = await loadLibrary(runner, binary)
    if (disposed) return
    if (load.kind !== 'loaded') {
      api.ui.toast({ variant: 'warning', message: sanitizeLine(libraryProblem(load)) })
      return
    }
    const titles = new Map(load.library.directives.map((directive) => [directive.id, directive.entity.title]))
    const sessions = [...load.library.sessions].sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))
    if (sessions.length === 0) {
      api.ui.toast({ variant: 'warning', message: 'PersonaKit: the library has no sessions' })
      return
    }
    const options = sessions.map((session) => {
      const isUsable = isValidId(session.id)
      return {
        title: sanitizeLine(titles.get(session.directiveId) ?? session.directiveId),
        value: session.id,
        description: sanitizeLine(session.id),
        disabled: !isUsable,
      }
    })
    // OpenCode's own filter reads only the title and category; this one also matches the id in the description.
    const [query, setQuery] = createSignal('')
    const shown = () => {
      const words = query().toLowerCase().split(/\s+/).filter(Boolean)
      return options.filter((option) => {
        const haystack = `${option.title} ${option.description}`.toLowerCase()
        return words.every((word) => haystack.includes(word))
      })
    }
    api.ui.dialog.replace(() => (
      <api.ui.DialogSelect
        title="Ground this session in a PersonaKit session"
        options={shown()}
        skipFilter={true}
        onFilter={setQuery}
        onSelect={(option) => {
          // A disabled row can still reach here; its id never becomes a prompt.
          if (disposed || !canUse({ sessionId: option.value })) return
          api.ui.dialog.clear()
          void safely(async () => void (await prefill(api, usePrompt({ sessionId: option.value }))))
        }}
      />
    ))
  }

  const removeLayer = api.keymap.registerLayer({
    commands: [
      {
        name: 'personakit.open',
        title: 'PersonaKit',
        desc: 'Show the PersonaKit contract in force and browse the library',
        category: 'PersonaKit',
        namespace: 'palette',
        slashName: 'pk',
        run() {
          // Run on the route itself, it keeps the session the route was opened from.
          const current = api.route.current
          const kept = current.name === ROUTE ? current.params?.sessionID : undefined
          const sessionID = current.name === ROUTE ? (typeof kept === 'string' ? kept : undefined) : viewed()
          api.route.navigate(ROUTE, sessionID === undefined ? {} : { sessionID })
          api.ui.dialog.clear()
        },
      },
      {
        name: 'personakit.use',
        title: 'PersonaKit: use a session',
        desc: 'Pre-fill a prompt that grounds this session in a PersonaKit session',
        category: 'PersonaKit',
        namespace: 'palette',
        slashName: 'pk-use',
        run: () => safely(useSession),
      },
    ],
  })

  api.slots.register({
    order: 100,
    slots: {
      session_prompt_right(_ctx, props) {
        return <Chip api={api} text={chipText(track(props.session_id).state(), manifestChanged())} />
      },
      sidebar_content(_ctx, props) {
        const state = () => track(props.session_id).state()
        return (
          <Sidebar
            api={api}
            state={state()}
            manifestChanged={manifestChanged()}
            reground={state().main && canUse(state().main!.ids) ? () => reground(props.session_id) : undefined}
          />
        )
      },
    },
  })

  const disposeRoute = registerRoute(api, {
    runner,
    binary,
    session: (sessionID) => (sessionID === undefined ? { ...initial, enforcement: enforcementNow() } : track(sessionID).state()),
    manifestChanged,
  })

  api.lifecycle.onDispose(() => {
    disposed = true
    disposeRoute()
    disposeConfigWatch()
    for (const off of unsubscribe) off()
    removeLayer()
    for (const entry of tracked.values()) entry.dispose()
    tracked.clear()
  })
}

const plugin = { id: 'opencode-personakit', tui } satisfies TuiPluginModule & { id: string }
export default plugin
